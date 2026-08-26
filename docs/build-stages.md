# Build stages

`Containerfile` runs `build/build.sh`. It first mirrors the `system/` tree into
the image with two `cp -rT` calls (`build/build.sh:7-8`), then calls each
build stage **by name**. It does not glob. A new stage that is not added to
`build.sh` silently never runs.

## Ordering

- Third-party repository installs must land **before `96-overrides.sh`**,
  which disables those repositories by filename (`build/96-overrides.sh:24-29`).
- Reordering `dnf5` installs can change dependency resolution, so when
  splitting a stage out, keep its original position.

## Stage boilerplate

A new stage should use `#!/usr/bin/bash`, `set -eoux pipefail`, wrap its
body in `echo "::group:: ===$(basename "$0")==="` / `echo "::endgroup::"`,
and be mode `0755`. The `::group::` markers fold the stage's output in
GitHub Actions logs.

That is the prescription, not a description — the existing stages have
drifted from it and no check enforces it:

- `97-validate-repos.sh` uses `set -eou pipefail` and `30-initramfs.sh`
  uses `set -oue pipefail`; both omit `-x`, so their commands are not
  echoed into the build log.
- `00-image-info.sh` and `05-kernel-akmods.sh` write `set -euox pipefail`
  — the same flags in a different order.
- `25-sysconfig.sh` marks its group with `==` rather than `===`.

None of that is worth a churn commit on its own, but do not copy an
arbitrary existing stage and assume it is the house style.

## The stages

Stages are documented in the order `build.sh` calls them.

### `00-image-info.sh`

Writes `/usr/share/sivablue/image-info.json` and rewrites
`/usr/lib/os-release` branding fields. `VERSION` defaults to the UTC build
date, so image version *is* the build date. Derives `IMAGE_NAME`/`IMAGE_REPO`
from `VARIANT`; `IMAGE_REPO` is lowercase because OCI/GHCR repository names
must be. Sets `IMAGE_REF` to `ostree-image-signed:` — this is what makes
signature verification mandatory on clients. Runs first so everything later
sees correct branding.

### `05-kernel-akmods.sh`

Nvidia variant only. Pulls prebuilt akmods from
`ghcr.io/ublue-os/akmods-nvidia-open` with `skopeo`, runs upstream's
`nvidia-install.sh`, blacklists nouveau via
`/usr/lib/bootc/kargs.d/00-nvidia.toml`, installs
`nvidia-container-toolkit-base` for CDI-based GPU passthrough (the `-base`
variant deliberately excludes `libnvidia-container` and the legacy OCI hook,
because CDI is the correct path for bootc/rootless containers), then removes
the toolkit repo file. Early because the kernel must be settled before
packages layer on it.

### `06-docker.sh`

Runs `sysctl -p` **before** installing Docker to apply IP forwarding first
and avoid breaking LXC networking. Writes `/etc/modules-load.d/ip_tables.conf`
loading `iptable_nat` for docker-in-docker. Adds `docker-ce.repo`, immediately
disables it with `sed`, installs with `--enablerepo=docker-ce-stable`.

### `07-tailscale.sh`

Adds the Tailscale repo, disables it via
`dnf5 config-manager setopt tailscale-stable.enabled=0`, installs with
`--enablerepo`. Note it uses `setopt` where `06`/`08` use `sed` — same
outcome, different idiom.

### `08-vscode.sh`

Writes the Microsoft `vscode.repo` inline via a `tee` heredoc rather than
fetching it, disables it, installs `code` with `--enablerepo=code`.

### `10-packages.sh`

Sources `copr-helpers.sh`. Bulk-installs `FEDORA_PACKAGES` in one `dnf5`
call — the comment "safe from COPR injection" is the reason it is a single
bulk install from Fedora repos only. Then three isolated COPR installs
(`che/nerd-fonts`, `ublue-os/packages` for `uupd`). Then
removes `EXCLUDED_PACKAGES` — note it first queries which are actually
installed with `rpm -qa`, because `dnf5 remove` on an absent package would
abort under `set -e`. Nvidia variant additionally removes ROCm packages,
which conflict with the Nvidia stack. **This is the file to edit when adding
a Fedora package.**

### `11-ghostty.sh`

Builds Ghostty from upstream source. This replaced an install from the
unofficial `scottames/ghostty` COPR; see "Why Ghostty is built from source"
below for the reasoning.

The stage resolves the newest stable version, verifies the source, fetches a
matching Zig toolchain, builds, and then removes everything it installed to do
so. Four details are load-bearing:

- **Version resolution uses the tags API, not `releases/latest`.** Ghostty
  publishes a rolling `tip` prerelease, so no release is ever marked latest and
  `releases/latest` returns 404 for this repository. The stage lists tags,
  keeps those matching `^v[0-9]+\.[0-9]+\.[0-9]+$`, and takes the highest by
  `sort -V`. As with `13-eddie.sh`, a malformed result fails the build rather
  than silently shipping something stale.
- **The tarball is verified with minisign.** Upstream signs every release with
  a fixed key, so this is a real signature check rather than the "is it
  plausibly the right file type" fallback `13-eddie.sh` has to settle for.
  Note the source tarball at `release.files.ghostty.org` is *not* GitHub's
  autogenerated "Source code" archive — it carries preprocessed files that a
  git checkout lacks, which is why no `blueprint-compiler` is needed here.
- **Zig comes from ziglang.org, at the version the source asks for.** Each
  Ghostty release builds with exactly one Zig version, and Fedora tracks a
  different one — Fedora 44 ships 0.16.0 while Ghostty 1.3.x requires 0.15.2 —
  so `dnf5 install zig` cannot work. Hardcoding a version would instead break
  on the day Ghostty moves. The stage reads `minimum_zig_version` out of the
  unpacked `build.zig.zon` and resolves that against
  `ziglang.org/download/index.json`, checksum included, so both halves stay
  rolling without a mapping to maintain.
- **Scratch space is `/var/tmp`, never `/tmp`.** The build `RUN` in the
  `Containerfile` mounts `/tmp` as tmpfs, which is RAM, and Ghostty's Zig cache
  runs to several GB. `ZIG_GLOBAL_CACHE_DIR` and `ZIG_LOCAL_CACHE_DIR` are
  pointed there too — their default is under `/root/.cache`, which would be
  committed to the image.

Install is `zig build -p /usr -Doptimize=ReleaseFast -Dversion-string=<version>`.
Both flags carry meaning beyond the obvious:

- `ReleaseFast` is not only about speed — the build uses the optimize mode to
  decide the application ID, so a `Debug`/`ReleaseSafe` build would install as
  `com.mitchellh.ghostty-debug` instead.
- `-Dversion-string` is required, not cosmetic. Ghostty derives its version by
  running `git describe`, and a release tarball is not a repository, so the
  detection fails and falls back to a `-dev` prerelease version. Because the
  release channel is computed from whether that version has a prerelease
  component, the result is a terminal that reports itself as `1.3.1-dev+0000000`
  on the `tip` channel rather than the stable release it actually is. Passing
  the resolved version explicitly is what makes it build as stable, and
  `99-tests.sh` asserts `channel: stable` so this cannot regress unnoticed.

Cleanup removes the headers and toolchain before the layer closes, but only
the packages this stage actually added — it snapshots the build deps with
`rpm -qa` first, the same guard `10-packages.sh` uses on `EXCLUDED_PACKAGES`.
This is also why `gtk4-layer-shell` (the runtime library, not `-devel`) is
listed in `FEDORA_PACKAGES`: it used to arrive as a dependency of the COPR
RPM, and installing it explicitly in `10-packages.sh` both replaces that and
marks it user-installed, so `dnf5 remove gtk4-layer-shell-devel` cannot take
it out as an unused dependency.

#### Why Ghostty is built from source

The `scottames/ghostty` COPR is unofficial, and the image should not depend on
one person's build for its terminal. Building from a signed upstream tarball
removes that trust dependency and picks up new releases as they land.

The cost is real and worth stating: the compile sits inside the same `RUN`
layer as every other install, so any rebuild of that layer pays it — roughly
5–15 minutes on a four-core runner. Rolling behaviour is therefore identical
to `13-eddie.sh`: the version refreshes whenever that layer rebuilds, which a
base-image change, any edit under `build/` or `system/`, or a `no_cache`
dispatch will all do. A Ghostty release landing on a day when nothing else
changes will not be picked up until something busts the cache; the `no_cache`
workflow input is the escape hatch.

Because Ghostty is built rather than packaged, `rpm -q` can vouch for none of
it, so `99-tests.sh` checks the binary runs and that the FHS install actually
landed — see [`filesystem-layout.md`](filesystem-layout.md) for why the
install target is `/usr` rather than `/usr/lib/ghostty`.

### `12-waterfox.sh`

Third-party repo install, following the same pattern as `07-tailscale.sh`:
add BrowserWorks' openSUSE Build Service repo, disable it immediately with
`config-manager setopt isv_BrowserWorks.enabled=0`, then install with
`--enablerepo=isv_BrowserWorks`. The repo URL is built with
`Fedora_$(rpm -E %fedora)` rather than a pinned release, so a rebase onto a
Fedora that BrowserWorks has not published for fails here instead of
silently resolving against the wrong release.

Waterfox was a tarball install until 6.7.0, the first release BrowserWorks
ship as an RPM. The package lands on exactly the same paths the
tarball did — `/usr/lib/waterfox` with `/usr/bin/waterfox` symlinked to the
binary — and ships the same upstream build, so `~/.waterfox` profiles carry
over untouched (`application.ini` keeps `Vendor=BrowserWorks`,
`Profile=Waterfox` and the same application ID). It also owns
`/usr/share/applications/waterfox.desktop` and the hicolor icons, which is
why neither is staged from `system/` any more.

Two things the package does not do, so the stage still does them:

- `distribution/policies.json` with `DontCheckDefaultBrowser`. The bundled
  updater no longer needs disabling by hand — the package sets
  `app.update.enabled=false` in `defaults/pref/package-prefs.js` and ships
  an `is-packaged-app` marker — but nothing suppresses the default-browser
  prompt.
- `gtk-update-icon-cache -f` and `update-desktop-database`. The package
  carries no scriptlets, and GTK trusts the base image's icon cache and will
  not rescan for icons it predates.

The stage then installs H.264 codec support. This lives here, rather than in
`10-packages.sh`, because Waterfox is the reason the image needs it.

Waterfox ships `libmozavcodec.so`, a stripped ffmpeg covering VP8, VP9, AV1,
Opus, Vorbis and FLAC. H.264 (`avc1`) and AAC are deliberately absent from it
and are loaded from the system ffmpeg instead, which Waterfox finds by
`dlopen`ing `libavcodec.so.<53–62>`. Stock Fedora cannot satisfy that:
`libavcodec-free` is built without the patented native H.264 decoder and
exposes only a `libopenh264` wrapper, and the soname that wrapper needs is
provided by `noopenh264` — an 11 KB stub whose `WelsCreateDecoder()` always
returns error 3. Every layer resolves cleanly and no error is printed, so the
symptom is that `av01` YouTube plays while `avc1` does not, and DRM sites such
as Pluralsight fail *after* Widevine has successfully decrypted the stream.
This is invisible under a Flatpak build of the browser, which gets a complete
ffmpeg from the `org.freedesktop.Platform.ffmpeg-full` runtime extension.

Two packages are needed because they fix different halves:

- `openh264` (and `mozilla-openh264` for WebRTC) from `fedora-cisco-openh264`,
  a repo already present in the base image but disabled. It `Obsoletes:
  noopenh264 < 1:0`, so it displaces the stub cleanly. This also repairs
  `libheif` and `freerdp-libs`, which link the same stub.
- `libavcodec-freeworld` from RPM Fusion free. `openh264` alone would give
  software-only decoding, because the `libopenh264` wrapper exposes no
  hwaccel. `libavcodec-freeworld` installs a full libavcodec to
  `/usr/lib64/ffmpeg` with an `/etc/ld.so.conf.d` drop-in that shadows
  `libavcodec-free` at `dlopen` time, restoring the native H.264 decoder —
  the only one carrying VA-API/VDPAU/CUDA hwaccel — plus HEVC. `ldconfig` is
  run explicitly afterwards because that cache is what decides which of the
  two libraries wins.

The RPM Fusion release package is installed with `--nogpgcheck` because it is
the package that *ships* the key everything after it is verified against;
`libavcodec-freeworld` itself is then signature-checked normally. Its repos
are disabled immediately after being added, per the usual pattern, and
`96-overrides.sh` already globs `rpmfusion-*.repo` as a second line of
defence. Note the codec install must stay ahead of `96-overrides.sh` for that
reason.

### `13-eddie.sh`

Same `ghcurl` + version-validation pattern, but installs a standalone RPM
fetched from `eddie.website`. Verifies it really is an RPM with `rpm -qp`
before `dnf5 -y install`, so a truncated download fails here rather than
inside dnf.

### `15-extensions.sh`

Installs build tooling (`glib2-devel meson sassc cmake dbus-devel`), builds
each vendored extension, compiles every schema with
`glib-compile-schemas --strict`, then **removes the tooling again** to keep
it out of the final image. Recompiles `/usr/share/glib-2.0/schemas` wholesale
at the end. Must run after `system/` is mirrored, since the extensions are
staged from there.

### `20-content-cleanup.sh`

Removes `/usr/src` and `/usr/share/doc`. Erases `kernel-devel` from the
rpmdb because its files under `/usr/src` are gone — guarded by `rpm -q`
because it only exists on the nvidia variant and an unconditional erase would
abort under `set -e`. Recompiles gschemas after wallpaper config changes.

### `25-sysconfig.sh`

Service state. Masks cups/avahi/ModemManager/sssd/geoclue. Disables
`rpm-ostreed-automatic.timer` (superseded by `uupd`). **Disables but does not
mask `tailscaled.service`** — Tailscale is opt-in, so it must remain
startable on demand. Enables system units and, via `systemctl --global`, the
per-user `sivablue-user-setup.service`. Installs swtpm SELinux policy modules
so `restorecon` can label `/usr/bin/swtpm` at boot. Seven of the units it
enables ship from `system/usr/lib/systemd/system/` rather than from a
package — `filesystem-layout.md` has a line on what each of them, and each
helper binary in `system/usr/bin/`, actually does.

### `30-initramfs.sh`

Regenerates the initramfs with
`dracut --no-hostonly --reproducible --add ostree`. Sets `DRACUT_NO_XATTR=1`
and `chmod 0600` the result. Must run after all kernel-affecting stages.

### `96-overrides.sh`

Patches `uupd.service` to add `--disable-module-distrobox` so background
updates leave Distrobox containers alone. Hides `fish`/`htop`/`nvtop` desktop
entries (`Hidden=true` also removes MIME associations). Adds the Flathub
remote and disables `flatpak-add-fedora-repos.service`. **Disables
third-party, COPR and RPM Fusion repos by filename** — this is why
third-party installs must come earlier.

### `97-validate-repos.sh`

Fails the build if any repo file still contains `enabled=1`. Security gate:
an enabled COPR could inject malicious versions of Fedora packages at
runtime. Allows `fedora-updates-testing` only when `UBLUE_IMAGE_TAG=beta`.

### `98-clean-stage.sh`

Resets `keepcache=0`, clears versionlocks, masks and deletes
`flatpak-add-fedora-repos.service`, then empties `/var` (keeping
`cache/libdnf5` and `cache/rpm-ostree`), `/tmp` and `/boot`.

### `99-tests.sh`

The build's own gate. Verifies the ublue-os signing key hashes (without them
a published image cannot pull `ghcr.io/ublue-os/*` and therefore cannot
update), stats the `ujust` binary and each `.just` file, checks the parts of the
Waterfox install the build still does by hand, the Ghostty source build
(binary, desktop file, shell integration, terminfo — plus that the Zig
toolchain and `-devel` headers did *not* survive into the image), the
fastfetch config and logo, and `default.preinstall`.
Asserts required packages are present, unwanted ones absent, and required
timers enabled. It also asserts a decoder named exactly `h264` appears in
`ffmpeg -decoders`: `rpm -q` cannot distinguish a working codec from the
`noopenh264` stub, since both satisfy the same soname (see `12-waterfox.sh`). **Add a check here for anything `rpm -q` cannot verify** —
source builds, tarball installs, and files staged from `system/`.

## COPR installs

`copr_install_isolated "owner/project" pkg…` from `build/copr-helpers.sh`
enables the COPR, immediately disables it, then installs with
`--enablerepo=<generated id>`. The repo is therefore never globally enabled,
which is what `97-validate-repos.sh` enforces.

## Adding a stage

Create `build/NN-name.sh` with the boilerplate, `chmod 0755`, and **add an
explicit call in `build/build.sh`**. Place it before `96-overrides.sh` if it
adds a third-party repo. Update this page.

## `ghcurl` token permissions

`ghcurl` requires no token scopes. Its callers, `11-ghostty.sh` and
`13-eddie.sh`, read tag and release metadata from public repositories, so a
token only lifts the GitHub
API rate limit from 60 requests per hour per IP to 5,000. CI's automatic
`secrets.GITHUB_TOKEN` (`contents: read`, `.github/workflows/build.yml:21`)
is sufficient; locally, any scopeless classic PAT exported as `GITHUB_TOKEN` is
forwarded as a podman secret by `Justfile:143-145`. Without a token the build
still works but can fail on HTTP 403, and both stages deliberately hard-fail
rather than ship a stale version.

## dnf5, always

DNF 4 is gone; on Fedora 41+ `dnf` is only a symlink to `dnf5`. Writing `dnf`
reads as if DNF 4 semantics were intended when they are not, and these
scripts already use DNF 5-only syntax (`config-manager addrepo`,
`config-manager setopt`) that DNF 4 cannot parse. Being explicit also keeps
the scripts honest if the image is ever rebased onto a base where `dnf`
really is DNF 4.
