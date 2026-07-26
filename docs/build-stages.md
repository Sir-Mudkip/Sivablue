# Build stages

`Containerfile` runs `build/build.sh`. It first mirrors the `system/` tree into
the image with two `cp -rT` calls (`build/build.sh:7-8`), then calls each
build stage **by name**. It does not glob. A new stage that is not added to
`build.sh` silently never runs.

## Ordering

- Third-party repository installs must land **before `96-overrides.sh`**,
  which disables those repositories by filename (`build/96-overrides.sh:26-31`).
- Reordering `dnf5` installs can change dependency resolution, so when
  splitting a stage out, keep its original position.

## Stage boilerplate

Every stage is `#!/usr/bin/bash`, `set -eoux pipefail`, wrapped in
`echo "::group:: ===$(basename "$0")==="` / `echo "::endgroup::"`, mode
`0755`. The `::group::` markers fold the stage's output in GitHub Actions
logs.

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
(`che/nerd-fonts`, `ublue-os/packages` for `uupd`, `scottames/ghostty`). Then
removes `EXCLUDED_PACKAGES` — note it first queries which are actually
installed with `rpm -qa`, because `dnf5 remove` on an absent package would
abort under `set -e`. Nvidia variant additionally removes ROCm packages,
which conflict with the Nvidia stack. **This is the file to edit when adding
a Fedora package.**

### `12-waterfox.sh`

Tarball install. Queries GitHub's `releases/latest` via `ghcurl` (latest
excludes prereleases, so betas are skipped), validates the tag against
`^[0-9]+\.[0-9]+\.[0-9]+$` and hard-fails otherwise rather than shipping a
stale browser. Installs to `/usr/lib/waterfox`, symlinks to `/usr/bin`.
Installs `bzip2` only if missing and removes it again afterwards. Upstream
publishes no checksums, so it sanity-checks the archive with `tar -tjf` — a
truncated download or HTML error page fails here. Writes
`distribution/policies.json` with `DisableAppUpdate` because `/usr` is
read-only at runtime. Promotes bundled icons into hicolor and runs
`gtk-update-icon-cache -f`, because GTK trusts the base image's icon cache
and will not rescan for icons it predates — rpm does this for packaged
installs, a tarball must do it by hand.

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
so `restorecon` can label `/usr/bin/swtpm` at boot.

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
update), stats the `ujust` binary and each `.just` file, checks the Waterfox
tarball install, the fastfetch config and logo, and `default.preinstall`.
Asserts required packages are present, unwanted ones absent, and required
timers enabled. **Add a check here for anything `rpm -q` cannot verify** —
tarball installs and files staged from `system/`.

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

`ghcurl` requires no token scopes. Its two callers, `12-waterfox.sh` and
`13-eddie.sh`, read release metadata from public repositories, so a token only
lifts the GitHub API rate limit from 60 requests per hour per IP to 5,000. CI's
automatic `secrets.GITHUB_TOKEN` (`contents: read`, `.github/workflows/build.yml:21`)
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
