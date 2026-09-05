# Sivablue vs. Bluefin

A functional comparison against upstream Bluefin, the image Sivablue was
modelled on. Written to answer one question: *what has Bluefin changed since
this repo forked its ideas, and does any of it matter here?*

This is an analysis snapshot, not a rule page. Nothing here is a commitment to
adopt anything — the "Worth considering" section is a menu, not a backlog.

| | |
|---|---|
| Bluefin revision compared | `stable-20260720-81-gc442e5c` (`../bluefin`) |
| `common` revision compared | `e802c81` (`../common`) |
| Sivablue revision | `83f9ab2` |
| Shared base | `quay.io/fedora-ostree-desktops/silverblue`, Fedora 44 |
| Date of comparison | 2026-09-04 |

**Read this first.** Bluefin is now two repositories. The `bluefin` repo holds
the build machinery and about twenty system files; everything a *user* sees —
`ujust`, the GNOME defaults, the shell bling, the setup-hook framework, the
hardware quirk database — was extracted into
[`projectbluefin/common`](https://github.com/projectbluefin/common), built as
`ghcr.io/projectbluefin/common` and consumed by digest. Comparing Sivablue to
the `bluefin` repo alone badly understates what upstream ships. Both are
compared here.

---

## 1. Shape of the two projects

Bluefin composes three images:

```
ghcr.io/projectbluefin/common@sha256:…     202 files: desktop config, ujust, hooks, hardware quirks
ghcr.io/ublue-os/brew@sha256:…             Homebrew integration
quay.io/fedora-ostree-desktops/silverblue  base (digest resolved after cosign verify in CI)
```

`common` itself has a build stage: it compiles two Go binaries (`umotd`,
`uwelcome`) from pinned commits, generates `ujust` shell completions by
rewriting `just --completions` output, converts JXL wallpapers and Bazaar
banners to PNG, and fetches 28 game-controller udev rule files from Codeberg
each with an individual `sha256sum` pin. It then emits three overlays —
`shared/` (Bluefin + Aurora), `bluefin/` (GNOME-specific), `nvidia/`.

Sivablue is one repository, ~47 files in `system/`.

Note **which** references Bluefin pins by digest, because the distinction is
easy to get backwards. The two first-party ublue images are pinned in
`image-versions.yml` and Renovate-bumped. The **base image is not**: the
Containerfile defaults `BASE_IMAGE_REF` to tag-only and CI resolves it to a
digest at build time, after a cosign verification (`Justfile:208` passes the
resolved ref as a build arg). Hardcoding a Fedora base digest in-repo would mean
a near-daily commit — `silverblue:44` is rebuilt constantly — while the `:44`
tag already anchors the thing worth anchoring, the Fedora major release.

Sivablue now follows the same split: `ghcr.io/ublue-os/brew:latest` is
digest-pinned in the Containerfile, since `:latest` carries no version anchor at
all, while the base image stays on the `:44` tag. Adopting Bluefin's
resolve-and-verify CI step would add per-build provenance without repo churn,
and is the natural follow-up if that becomes worth having.

The split exists because Bluefin and Aurora need to share a desktop layer.
Sivablue has no sibling image, so the split itself buys nothing here. What it
does mean is that **`common` is where the interesting upstream work has been
happening**, and most of §4 below comes from it.

---

## 2. Build architecture

| | Bluefin | Sivablue |
|---|---|---|
| Stage orchestration | Containerfile runs scripts inline in two `RUN` blocks | `build/build.sh` calls each stage by name in one `RUN` |
| Build contexts | Four `FROM scratch` contexts (`ctx-build`, `ctx-iso`, `ctx`, stage mounts) | One `ctx` containing `build/` + `system/` |
| System files applied | `rsync -rvK` in Stage 2, *after* package installs | `cp -rT` at the top of `build.sh`, *before* package installs |
| Extensions | Built in a dedicated `extension-builder` stage, result `COPY`'d in | Built inline in `build/15-extensions.sh` |
| Package list | TOML manifest read by a Python helper | Bash array in `build/10-packages.sh` |
| `/opt` | `rm -rf /opt && ln -s /var/opt /opt` — writable | `rm /opt && mkdir /opt` — empty and immutable |
| Final lint | `bootc container lint --fatal-warnings --skip nonempty-boot` | `bootc container lint` |

### 2.1 Cache boundaries — the change with the biggest practical payoff

Bluefin deliberately split its build so that **editing `system_files/` cannot
invalidate the package-install layer.** The mechanism is subtle and documented
in the Containerfile itself: buildah folds the mounted stage's image ID into a
`RUN` cache key, so a *single* combined context makes every file edit bust every
layer. Hence four separate scratch contexts, each carrying the minimum its
consumer reads.

They claim 20–80 minutes saved on a config-only change. A matching optimisation
lives in `19-initramfs.sh`: Stage 1 writes a `.bluefin-initramfs-done` marker and
Stage 2 skips `dracut` if it is present, saving another 2–6 minutes.

Sivablue's single `RUN` calling `build.sh` means *any* change to *any* file
rebuilds *everything*, including Ghostty from source. Its cold-build cost is
comparable to Bluefin's; the difference is that it pays that cost on every
wallpaper tweak.

### 2.2 Ordering: system files before vs. after packages

Bluefin overlays `system_files/` *after* packages install; Sivablue mirrors
`system/` *before*. Bluefin's ordering means an RPM can never overwrite a file
the image intends to ship. Sivablue's means the reverse.

In practice `99-tests.sh` catches this class of bug for the files it checks, and
`20-content-cleanup.sh` recompiles the schemas afterwards, covering the most
likely victim. But it is a latent hazard, and Bluefin moved a block out of
`05-override-install.sh` into `00-image-info.sh` precisely because it hit this.

### 2.3 Package manifest as data

Bluefin's list moved into `build_files/packages/base.toml` with sections
`[multimedia_overrides]`, `[fedora]`, `[fedora_v42]`, `[fedora_v43]`,
`[fedora_v44]`, `[excluded]`, read by a Python `tomllib` helper. This buys
per-Fedora-version package sets without `if` blocks, and a machine-readable list.
Sivablue's bash array is simpler and, targeting one Fedora version, currently
loses nothing. Worth revisiting at the next Fedora rebase, not before.

---

## 3. The setup-hook framework — where Sivablue has drifted

Sivablue's `libsetup.sh` and `sivablue-user-setup` are renamed copies of
upstream's. Upstream has since fixed them; Sivablue has the pre-fix versions.
This is the most actionable finding in the comparison.

### 3.1 `libsetup.sh` — three upstream fixes Sivablue is missing

Compare `system/usr/lib/sivablue/setup-services/libsetup.sh` against
`../common/system_files/shared/usr/lib/ublue/setup-services/libsetup.sh`:

**1. No locking.** Upstream wraps the entire read-modify-write in
`flock -x 200` against a `.lock` file, with a comment naming the bug: concurrent
first-boot setup scripts could both read the JSON before either wrote back,
running the same hook twice. Sivablue has no lock. Today Sivablue runs only one
hook tier so the race window is small — but it is the same window, and it opens
wider the moment a second tier or a parallel invocation exists.

**2. No JSON validation.** Upstream validates with `jq '.'` and resets a
malformed file to `{}` rather than silently misbehaving.

**3. The write is unchecked — this one can lose data.** Sivablue does:

```bash
ANNOYING_JQ_WORKAROUND=$(mktemp)
jq ".version.…" "${SETUP_CHECKER_FILE}" >"${ANNOYING_JQ_WORKAROUND}"
mv "${ANNOYING_JQ_WORKAROUND}" "${SETUP_CHECKER_FILE}"
```

If `jq` fails — malformed versioning file, a name with a character that breaks
the filter, a full disk — the `mv` still runs and moves an **empty or partial
file over the versioning database**, wiping every recorded hook version. Every
hook then re-runs on next login. Upstream guards it:

```bash
if jq "…" "${SETUP_CHECKER_FILE}" > "${tmp}"; then
    mv "${tmp}" "${SETUP_CHECKER_FILE}"
else
    echo "Error: failed to write version update…"
    exit 1
fi
```

Upstream also `trap`s the temp file for cleanup on any exit. Sivablue leaks it
on the failure path.

Given `CLAUDE.md`'s rule that hooks must be *"defensive and never destructive"*,
the unguarded `mv` is squarely against the repo's own stated intent. Porting all
three fixes is a contained change to one file.

### 3.2 `sivablue-user-setup` — unquoted expansions

Upstream quotes the loop and the invocation:

```bash
for script in "${USER_HOOKS_DIRECTORY}"/* ; do
    bash "$script"
done
```

Sivablue does not:

```bash
for script in $USER_HOOKS_DIRECTORY/* ; do
    bash $script
done
```

Low impact — hook filenames are controlled by this repo — but note that
`just lint` runs shellcheck across `*.sh`, and `sivablue-user-setup` has no
extension, so **it is not linted at all.** The same is true of `ujust`,
`sivablue-motd`, `auto-groups` and `tailscale-operator-setup`. Worth widening
the lint glob to catch extensionless scripts by shebang.

### 3.3 Three hook tiers vs. one

Upstream runs three, all sharing `libsetup.sh` and the
`version-script <name> <tier> <n>` convention:

| Tier | Runner | Context | Directory |
|---|---|---|---|
| `user` | `ublue-user-setup.service` (user unit) | as the user, at login | `/usr/share/ublue-os/user-setup.hooks.d/` |
| `system` | `ublue-system-setup.service` (system unit) | root, at boot | `/usr/share/ublue-os/system-setup.hooks.d/` |
| `privileged` | `ublue-privileged-setup` via polkit/pkexec | root, on behalf of a user session (`$PKEXEC_UID`) | `/usr/share/ublue-os/privileged-setup.hooks.d/` |

Sivablue implements only the `user` tier — though its `libsetup.sh` still
documents all three in its comment, inherited verbatim. Its equivalents of the
other two are one-off systemd units: `tailscale-operator.service`,
`auto-groups.service`, `set-hostname.service`.

The one-off-unit approach is fine for three cases. What the tiered framework
adds is *versioning* — a hook that changed gets re-run for existing users by
bumping an integer, which a plain `systemd` unit with `ConditionPathExists`
cannot express. If Sivablue ever needs a root-side action to be re-applied after
an image update, this is the pattern to reach for, and half of it is already
present.

---

## 4. What `common` ships that Sivablue does not

The substance of what was hidden behind `ghcr.io/projectbluefin/common`.

### 4.1 A hardware quirk database

`common` ships **28 game-controller udev rule files** (8BitDo, Sony, Nintendo,
Valve, Razer, Hori, Logitech, Thrustmaster, PowerA, Nacon, Wooting, VKB…) fetched
at a pinned commit with per-file SHA256 verification, plus rules for Yubico U2F,
Google Titan keys, ZSA keyboards, Arduino/mbed, Framework 16, Apple SuperDrive,
Realtek USB NICs, a Neutron HiFi DAC, and AMD s2idle fixes. Also ICC colour
profiles for Framework 13 and 16 panels, a PipeWire Bluetooth auto-switch config,
and an `amd-legacy` modprobe conf.

**Sivablue ships no udev rules at all** beyond what Fedora provides. This is the
largest silent gap in the comparison — not a subsystem, just a long tail of
"peripheral X works out of the box on Bluefin and doesn't here." Nothing about it
is Bluefin-specific; the rules are vendored upstream content and could be
adopted wholesale or à la carte.

### 4.2 Update policy: uupd only on AC power

Three pieces working together:

- `uupd.service.d/10-bluefin.conf` adds `ConditionACPower=true` — the scheduled
  update simply does not run on battery.
- `99-uupd-on-ac.rules` triggers `uupd-on-ac.service` when a `Mains` power supply
  comes online, so plugging in catches up the missed run.
- `uupd-on-ac.service` sleeps 60s for the network to settle and is rate-limited
  to once per six hours (`StartLimitIntervalSec=21600`, `StartLimitBurst=1`).

The timer itself is `00,06,12,18:00:00` with `RandomizedDelaySec=10m` —
Sivablue's `01-uupd.preset` enables `uupd.timer` with whatever the package
ships and no AC condition, so a laptop on battery will pull and stage an image
update. Three small files; the most clearly worth-stealing item on this list.

Both images disable uupd's distrobox module, but differently: Bluefin uses
`/etc/uupd/config.json`, Sivablue `sed`s the unit file in `96-overrides.sh`.
The config file is the supported route and survives package updates.

### 4.3 `rechunker-group-fix`

A boot-time service that repairs `/etc/gshadow`, which `systemd-sysusers` does
not manage on bootc images ([systemd#30852](https://github.com/systemd/systemd/issues/30852)).

**Sivablue does not need this.** The unit's own comment names the cause: the
prune step in [`ublue-os/legacy-rechunk`](https://github.com/ublue-os/legacy-rechunk),
which strips `/etc/gshadow` entries, breaking a later rebase to an image without
`nss-altfiles`. Sivablue's CI uses the same `chunka` action, but that action runs
**chunkah** ("OCI-native, no rpm-ostree"), a different tool without that prune.

The symptom looks superficially present — on a running Sivablue install, all 16
entries in `/etc/group` lack a `/etc/gshadow` counterpart — but group membership
resolves correctly (`id -nG` returns `wheel libvirt docker`), because
`nsswitch.conf` merges `/usr/lib/group` through `altfiles` and `gshadow` is not
consulted for membership. Adding the service would be importing a fix for
somebody else's pipeline, and its own comment warns that a malfunction causes
systems not to boot. Not worth the risk absent an observed failure.

### 4.4 dconf locks

`/etc/dconf/db/distro.d/locks/01-bluefin-locked-settings` prevents users from
re-enabling GNOME Software's updater. Sivablue has a `distro.d/` tree but no
`locks/` directory. Mostly moot here — Sivablue removes `gnome-software`
outright — but the mechanism is the only way to make a distro default *stick*
against user dconf writes, and is not currently documented in
[`docs/settings.md`](./settings.md).

### 4.5 OEM auto-detection

`user-setup.hooks.d/20-oem-brew.sh` reads DMI (`chassis_vendor`, `sys_vendor`,
`product_name`), maps it to `/usr/share/ublue-os/oem/<Vendor>/`, and installs a
vendor Brewfile, sets the Logo Menu icon, and drops a WirePlumber config for the
Framework Desktop specifically. `system-setup.hooks.d/10-framework.sh` is a
detailed per-model quirk script (obsolete karg cleanup, 3.5mm jack fix
conditional on kernel vendor, a suspend workaround gated on BIOS version
comparison).

Both are written with `SYSROOT` / `LIBSETUP` env overrides purely so tests can
run them against a fake filesystem — see §6.

Irrelevant to Sivablue unless it targets Framework or ASUS hardware, but the
*shape* (`oem/<Vendor>/` + DMI match + version-scripted hook) is a clean pattern.

### 4.6 ChairLift and staged bootc updates

Upstream now ships a GUI updater (ChairLift, delivered as a brew cask via
`preinstall.d/chairlift.Brewfile`), with a polkit action pinned to
`/usr/libexec/bootc-update-stage`. That helper is a good example of upstream's
current care: it is a fixed `exec /usr/bin/bootc upgrade` with a long comment
explaining why every flag was rejected, and it ignores forwarded arguments so the
polkit action cannot be turned into arbitrary privileged `bootc` invocation.

Sivablue's update story is `uupd.timer` plus `ujust update` / `update-and-reboot`.

### 4.7 TPM2 / LUKS / passkeys

`luks-tpm2-autounlock` (driven by `ujust toggle-tpm2`) parses `rd.luks.uuid` /
`rd.luks.name` off the kernel command line and enrols or wipes a TPM2 slot with
optional PIN, and `90-passkeys-tpm.conf` adds the dracut bits. Sivablue's only
dracut config is `80-vfio.conf`. No equivalent.

### 4.8 Everything else, briefly

- **`umotd` / `uwelcome`** — two Go binaries for the login banner, with a JSON
  config (`/etc/uwelcome/config.json`), a `uwelcome toggle`, and sixel/symbol
  logo variants. Sivablue's `sivablue-motd` renders a markdown file through
  `glow` — simpler and, for one user, fine.
- **`bling`** (`bling.sh` / `bling.fish`) — opt-in shell extras enabled by
  `ujust bluefin-cli`. Sivablue uses `bash-color-prompt` + `welcome.sh`.
- **Bazaar configuration** — `/etc/bazaar/{bazaar,blocklist,curated}.yaml` plus a
  `hooks.py`, giving upstream a curated storefront. Sivablue ships only
  `default.preinstall`.
- **`flatpak-appstream-refresh.service`** with a system preset. Sivablue has none.
- **zsh configuration tree** (`/etc/zsh/z*`), `etc/environment`,
  `etc/xdg/mimeapps.list`, a `gnome-initial-setup/vendor.conf` that skips setup
  pages, and 15 user avatar images.
- **geoclue with a BeaconDB provider** — needed for the dynamic wallpaper's
  sunrise/sunset. Sivablue **masks geoclue entirely** in `25-sysconfig.sh`, which
  is a deliberate opposite choice.
- **`bluefin-dynamic-wallpaper`** — a user timer that switches the wallpaper by
  time of day.
- **`ublue-nvidia-flatpak-runtime-sync`** in the `nvidia/` overlay, keeping the
  Flatpak NVIDIA runtime matched to the driver. Relevant to Sivablue's nvidia
  variant, which has no equivalent.

---

## 5. Functional differences in the `bluefin` repo itself

### 5.1 Container-native ISO (`21-container-native-iso.sh`)
Bluefin embeds an installable-ISO contract in the image: an Anaconda profile
(BTRFS+zstd default layout, slimmed webui), a `bootc-image-builder` `iso.yaml`,
the secure-boot key, and the EFI payload committed to `/boot` for Titanoboa. It
is backed by packages Sivablue does not install (`anaconda-live`, `dracut-live`,
`livesys-scripts`, `isomd5sum`, `squashfs-tools`, `xorriso`,
`grub2-efi-x64-cdboot`, `slitherer`) and by `19-initramfs.sh` adding
`dmsquash-live dmsquash-live-autooverlay` to dracut, which Sivablue's
`30-initramfs.sh` does not.

**Sivablue is also installed from an ISO** — that is its primary install path,
with live images published at `download.sivablue.uk` for both the standard and
nvidia flavours. The difference is where the ISO is built: Bluefin embeds the
contract in the image itself, whereas Sivablue builds ISOs in a separate
repository, [`Sir-Mudkip/Sivablue-iso`](https://github.com/Sir-Mudkip/Sivablue-iso),
which carries `iso_files/` and `hack/{local,non-live}-iso-build.sh`.

So this is a difference of packaging, not of capability. Bluefin's approach
means the running image can regenerate its own installer; Sivablue's keeps the
ISO concern out of the image entirely, which is why none of the live-media
packages in §10.1 appear here and why `30-initramfs.sh` needs no
`dmsquash-live`. Both are coherent; Bluefin's costs image size, Sivablue's
costs a second repository to keep in step with this one.

Locally, `iso/disk.toml` exists and is tracked, so the `build-qcow2` /
`build-raw` / `run-vm-qcow2` recipes resolve. `iso/iso.toml` does not, so
`build-iso` and `rebuild-iso` still fail — the real ISO build lives in the
other repository.

### 5.2 negativo17 multimedia stack
Bluefin `distro-sync`s twelve packages — mesa, libva, Intel media drivers,
libheif — from `negativo17/fedora-multimedia` at repo priority 90, `versionlock`s
them, and asserts each one's RPM vendor is `negativo17.org` in `20-tests.sh`.

Sivablue does **not** use negativo17 at all. `96-overrides.sh:25` and
`97-validate-repos.sh:68` still reference disabling
`negativo17-fedora-multimedia`, inherited from Bluefin, but no stage ever adds
the repo — dead code. Sivablue gets codecs from RPM Fusion in `12-waterfox.sh`
(`libavcodec-freeworld` shadowing `libavcodec-free`, plus Cisco `openh264`) and
keeps Fedora's mesa.

This is a genuine difference in hardware media support, not just packaging
taste: Sivablue runs stock Fedora mesa and `libva`, so Intel VA-API decode and
`libheif` coverage are whatever Fedora ships.

### 5.3 Rechunker layer tagging
Bluefin tags content with `setfattr -n user.component` so the rechunker gives it
its own OCI layer (`gnome-extensions` on the extensions tree, `bluefin-docs` on
the PDF). Sivablue rechunks but tags nothing, so grouping is entirely heuristic.
Cheap to adopt; modest payoff in `bootc upgrade` delta size.

### 5.4 Smaller items
- **`bootc-unified-storage.service`** — opts into unified storage on first boot
  for `zstd:chunked` partial pulls.
- **Offline documentation** — a PDF in `/usr/share/doc/bluefin/`. Sivablue
  deletes `/usr/share/doc` wholesale.
- **A `FedoraWorkstation` firewalld zone** fetched from Fedora dist-git and set
  as default, with `IPv6_rpfilter=loose`. Sivablue leaves firewalld at defaults.
- **Removal of `/usr/bin/chsh` and `/usr/bin/lchsh`** as atomic-system footguns,
  and **linuxbrew added to `sudoers` `secure_path`**.
- **CoreOS `sulogin` generator** for emergency/rescue boot.
- **`/run` cleared in `clean-stage.sh`** for `bootc container lint`'s
  `nonempty-run-tmp` check. Sivablue's `98-clean-stage.sh` clears `/tmp` and
  `/boot` but not `/run`; it passes lint today only because it does not run with
  `--fatal-warnings`.
- **Orphan `/usr/lib/modules/` pruning** for kernel-tools bumps arriving without
  a matching `kernel-core`, which otherwise breaks `akmods-ostree-post`.
  Relevant to Sivablue's nvidia variant.

---

## 6. Things Sivablue does that Bluefin does not

Not gaps — the reasons this repo exists.

- **Virtualisation as a first-class feature.** libvirt, virt-manager, virt-v2v,
  the full qemu set, swtpm, `swtpm-workaround.service`,
  `libvirt-workaround.service`, VFIO dracut config, `libvirt-nss`. Bluefin ships
  none of it in the image — it has a `ujust setup-vms` recipe that layers it on
  demand instead. Baking it in is the right call for a workstation that always
  needs it.
- **Docker CE alongside Podman** (`06-docker.sh`, `docker.socket` enabled).
  Bluefin ships `containerd` but not Docker — see below, this is less of a
  difference than it looks.
- **Ghostty built from source** with a pinned CPU baseline and an AVX-512
  assertion in tests. Bluefin ships Ptyxis only.
- **Waterfox instead of Firefox**, from the BrowserWorks repo, with
  `DisableAppUpdate` and a verified native h264 decode path.
- **AirVPN Eddie**, **VS Code from the Microsoft repo** plus a seeded
  `/etc/skel` settings file, **Nerd Fonts** from COPR.
- **A deliberately quieter system**: `25-sysconfig.sh` masks cups, avahi,
  ModemManager, sssd and geoclue outright, and disables `tailscaled` at boot
  (opt-in). Bluefin *enables* `tailscaled` and asserts it enabled in tests, and
  actively configures geoclue. A direct philosophical inversion.
- **`auto-groups.service`, `set-hostname.service`** — per-machine conveniences
  with no upstream equivalent.
- **A more sysadmin-shaped toolkit** baked in rather than brewed per-user:
  `gocryptfs`, `iwd`, `nvme-cli`, `lm_sensors`, `pipx`, `podman-compose`,
  `ripgrep`, `tmux`, `htop`, `glow`.

---

### 6.1 Docker, containerd, and the `docker` group

Worth setting down, because "should Sivablue use containerd like Bluefin?" is a
question the package lists invite and the answer is not what it looks like.

**Sivablue already runs containerd.** `06-docker.sh` installs `containerd.io`,
which *is* containerd — Docker's packaging of the same daemon. Docker Engine is
a management layer on top of it, not an alternative to it. Bluefin's
`containerd` is Fedora's build of that same daemon, and the two cannot coexist:
both own `/usr/bin/containerd`, `/usr/bin/ctr` and
`/usr/bin/containerd-shim-runc-v2`.

So the real choice is posture, not runtime. Bluefin keeps the Engine out of the
image and offers Docker per-user through `ujust devmode` as a Homebrew install;
Sivablue bakes the Engine in with `docker.socket` enabled. Sivablue's choice is
deliberate and stays: this image is used for work that needs real Docker
Compose, `podman-docker` is in `EXCLUDED_PACKAGES` precisely so the `docker`
command is Docker rather than a Podman shim, and Podman remains available
alongside for rootless work.

`docker-model-plugin` was dropped from that install — it is Docker Model
Runner, a local model manager, unrelated to running a model server such as
Ollama in an ordinary container.

**The `docker` group is root-equivalent and that is an accepted risk.** Anyone
in it can `docker run -v /:/host` and own the machine, and `auto-groups` grants
it to every wheel member automatically rather than making it opt-in as Bluefin
does. This was raised and decided on 2026-09-05: the maintainer works in
offensive security, treats the workstation as a machine whose compromise is an
organisational event rather than a personal one, and applies operational care
accordingly. Do not "fix" this by making the group opt-in without asking.

## 7. Settings, extensions and `ujust`

### 7.1 GNOME extensions

| Extension | Bluefin | Sivablue |
|---|---|---|
| dash-to-dock | ✅ (pinned `extensions.gnome.org-v106`) | ✅ (`master`) |
| gradia-integration | ✅ | ✅ |
| appindicatorsupport | ✅ (`v65`) | ❌ |
| blur-my-shell | ✅ | ❌ |
| caffeine | ✅ (`v60`) | ❌ |
| gsconnect | ✅ (`v72`, meson install) | ❌ |
| search-light | ✅ | ❌ |
| custom-command-list | ✅ + dconf profile | ❌ |
| bazaar-integration | ✅ | ❌ |
| logomenu | ❌ | ✅ (+ dconf config) |
| clipboard-indicator | ❌ | ✅ |

Both vendor as git submodules and compile schemas at build time. Two real
differences:

1. **Bluefin pins submodules to release branches** (`v65`, `v60`, `v72`,
   `extensions.gnome.org-v106`); Sivablue tracks `master`/`main` on all four. On
   a GNOME major bump, Bluefin's build breaks loudly at a known-good version
   while Sivablue silently picks up whatever upstream `master` is that day. The
   most portable single lesson in this comparison.
2. Bluefin builds extensions in a separate image stage and tags the result for
   the rechunker.

### 7.2 A settings inconsistency in Sivablue

`common` has a whole documentation skill (`docs/skills/dconf-consistency.md`)
devoted to keeping the gschema override and the dconf database from disagreeing.
Sivablue has an instance of exactly that bug: **the Logo Menu settings are
defined twice**, in
`system/usr/share/glib-2.0/schemas/zz0-sivablue-mods.gschema.override` and in
`system/etc/dconf/db/distro.d/03-sivablue-logomenu-extension`, and the two copies
have diverged:

| Key | gschema override | dconf |
|---|---|---|
| `menu-button-extensions-app` | `flatpak run com.mattjakeman.ExtensionManager` | `com.mattjakeman.ExtensionManager.desktop` |
| `show-boxbuddy` | `true` | *absent* |
| `show-distroshelf` | *absent* | `true` |

Per [`docs/settings.md`](./settings.md)'s own rule, Logo Menu ships its schema
inside its extension directory, so **the gschema override block is the one that
does nothing** and dconf wins. The override copy is dead config that reads as
live. Worth deleting the duplicate and leaving a one-line pointer.

### 7.3 `ujust`

Same mechanism on both sides — a `ujust` shim invoking `just --justfile` against
an entry file that `import`s the rest. Sivablue's `entry.just` is a direct
descendant of upstream's `00-entry.just`, still printing upstream's
`docs.projectbluefin.io` URL as its default output.

Upstream has ~40 recipes to Sivablue's ~15. Notable upstream-only ones that map
onto things Sivablue cares about: `toggle-tpm2`, `check-sb-key` /
`enroll-secure-boot-key`, `check-local-overrides`, `logs-this-boot` /
`logs-last-boot`, `device-info`, `check-idle-power-draw`, `powerwash`,
`toggle-updates`, `changelogs`. Sivablue-only: `get-dotfiles`, `pull-hashcat`,
`install-vscodium`, `setup-gnome`, `toggle-passwordless`, `clean-containers`.

Two small upstream niceties: `import?` (optional import) for a
`60-custom.just` drop-in, and a `ujust` shim that bootstraps `fzf` via brew if
`--choose` is used without it — the latter irrelevant here since Sivablue bakes
`fzf` in.

---

## 8. Testing and CI

### 8.1 In-build tests
Sivablue's `99-tests.sh` is a direct descendant of Bluefin's `20-tests.sh` and
still shares the ublue signing-key SHA256 checks verbatim. Both have since grown
in their own directions — Sivablue toward Ghostty's stable channel and AVX-512
freedom, Waterfox's h264 decoder and build-tool leakage; Bluefin toward RPM
*vendor* assertions for negativo17 packages and the brew-preinstall chain.

### 8.2 Out-of-build tests — the real gap

| | Count |
|---|---|
| `bluefin/tests/` | 28 files (bats + pytest, kcov coverage merging) |
| `common/tests/` | 33 files (bats + pytest) |
| Sivablue | 0 |

61 test files upstream against none here. More instructive than the count is
*how* they got there: upstream writes scripts to be testable by convention, with
env-var overrides that exist for no other reason —

| Override | Script |
|---|---|
| `CLEAN_ROOT` | `clean-stage.sh` |
| `FAKE_ROOT` | `21-container-native-iso.sh` |
| `SYSROOT`, `LIBSETUP` | `10-framework.sh` |
| `GSHADOW_FILE`, `GROUP_FILE` | `rechunker-group-fix` |
| `CMDLINE_FILE`, `DISK_BY_UUID_DIR`, `DEV_DIR` | `luks-tpm2-autounlock` |

`common` documents this as a skill (`docs/skills/shell-scripts/references/testability-patterns.md`).
Sivablue already uses the idiom once — `SIVABLUE_MOTD_TEMPLATE` in
`sivablue-motd` — without the tests that would justify it.

Sivablue's validation is `shellcheck`, `shfmt`, Justfile syntax, and a full
`just build`. Per `CLAUDE.md`: *"Only a full `just build` proves a build stage
works."* True, and also a 30-plus-minute feedback loop for a one-line change to a
shell script.

### 8.3 Workflows

| | Bluefin | Sivablue |
|---|---|---|
| Workflow count | 23 | 7 |
| Release model | `testing` → e2e gate → promote to `main`/`stable`, with cherry-pick tooling | single `stable` tag + dated immutable tag |
| E2E testing | `run-testsuite.yml` with `smoke`, `common`, `vanilla-gnome` suites; nightly | none |
| Supply chain | sigstore attestations, `scorecard.yml`, `vulnerability-scan.yml` | cosign key signing |
| Dependency health | `copr-health-monitor.yml`, `pkg-cadence.yml`, `track-common.yml` | Renovate |
| Shared actions | `projectbluefin/actions` reusable *workflows* | `projectbluefin/actions` build *actions* |

Sivablue already consumes the same upstream action set — preflight, runner setup,
DNF cache, change detection, `chunka` rechunking, push. That part is current.
What Bluefin has on top is a *release process*: a testing stream, an e2e suite
running the built image in a VM, and a promotion gate.

The `vanilla-gnome` baseline suite is worth recording as an idea: they run the
same tests against stock GNOME so a failure triages as "our regression" vs.
"upstream GNOME broke it" without investigation.

### 8.4 Agent-facing documentation

Upstream restructured into progressive-disclosure skills — `bluefin/docs/skills/`
(12 skills) plus `common/docs/skills/` (~50 files, with an `index.json` and a
JSON schema for it), and `specs/epics/` YAML task manifests in both. Their
`docs/ci.md` and `docs/build.md` are now two-line pointers.

Sivablue's `CLAUDE.md` + `docs/` split (rules here, reasoning there) is a
different solution to the same problem and, at this size, a better one. The one
idea worth stealing is `architecture.md`'s **source-of-truth rule** — *"When this
document disagrees with the source, the source wins"* — which Sivablue's docs
imply but never state.

---

## 9. Worth considering

An ordered menu, not a backlog. Items 1-6 have since been done (commit history
has the detail); they are kept here so the reasoning stays with the list.

| # | Change | Effort | Payoff |
|---|---|---|---|
| 1 ✅ | **Port the three `libsetup.sh` fixes** — flock, JSON validation, guarded write (§3.1) | Trivial | Removes a data-loss path that wipes hook versioning and re-runs every hook |
| 2 ✅ | **Enable Renovate's `git-submodules` manager** | Trivial | Submodules were frozen, not drifting: gitlinks pin them and nothing was bumping them. Most have no release tags to pin to. |
| 3 ✅ | **Delete the duplicated Logo Menu block** from the gschema override (§7.2) | Trivial | Removes dead config that reads as live |
| 4 ✅ | **Delete the dead negativo17 references**, or actually adopt the repo | Trivial / Medium | Removes misleading code; adopting improves Intel VA-API and HEIF support |
| 5 ✅ | **`ConditionACPower=true` on uupd** plus the AC-connect udev trigger (§4.2) | Trivial | Laptops stop pulling image updates on battery |
| 6 ✅ | **Widen `just lint` to extensionless scripts** (`ujust`, `sivablue-motd`, `auto-groups`, `sivablue-user-setup`, `tailscale-operator-setup`) | Trivial | Five scripts are currently unlinted |
| 7 ✅ | **`--fatal-warnings` lint** plus a tolerant `/run` clear in `98-clean-stage.sh` | Trivial | Caught three real warnings on the first run: a stray `dnf5.log` and an undeclared `docker` group |
| 8 ✅ | **Move uupd's distrobox opt-out to `/etc/uupd/config.json`** instead of `sed`ing the unit | Trivial | Supported route; survives package updates |
| 9 ✅ | **udev rules** — resolved as two Fedora packages (`steam-devices`, `openrgb-udev-rules`); the rest investigated and not vendored (§4.1) | Small | Controller and RGB support; hardware-specific rules deliberately skipped |
| 10 ✅ | **Pin `ublue-os/brew` by digest**, Renovate-bumped. Base image deliberately *not* pinned — §1 | Small | `:latest` has no version anchor and changed silently; `:44` already anchors the Fedora release |
| 11 ✅ | **Orphan `/usr/lib/modules/` pruning** before initramfs | Small | Prevents a known akmods failure on the nvidia variant |
| 12 ❌ | **`rechunker-group-fix`** — investigated and rejected (§4.3): the bug is specific to `legacy-rechunk`, and Sivablue's CI runs chunkah | — | — |
| 13 ✅ | **Rechunker `setfattr` tags** on the extensions tree | Small | Smaller `bootc upgrade` deltas |
| 14 | **Bats unit tests**, starting with `copr-helpers.sh` and `97-validate-repos.sh` | Medium | Turns a 30-minute build loop into a 3-second one for script logic |
| 15 | **Split the Containerfile cache boundary** (§2.1) | Large | 20–80 min per config-only build; also fixes the §2.2 ordering hazard |
| 16 | **A `testing` stream and promotion gate** | Large | Only worth it if Sivablue gets users other than its author |

Explicitly *not* recommended: the `common`-image split (no sibling image),
`brew-preinstall` for the CLI (baking in is right for one user), the
container-native ISO (Sivablue builds ISOs in its own repository instead), ChairLift and
the dynamic wallpaper (both pull in dependencies — geoclue — that Sivablue
deliberately masks), and the `docs/skills` + `specs/epics` restructure (current
docs suit this repo's size better).

---

## 10. Package differences

Fedora-repo packages only. Excludes packages installed by dedicated stages on
either side (Docker, Tailscale, VS Code, Waterfox, Eddie, Ghostty, akmods,
COPRs), and everything Bluefin delivers per-user through Homebrew rather than
in the image.

### 10.1 Installed by Bluefin, not by Sivablue (50)

| Group | Packages |
|---|---|
| ISO / live media | `anaconda-live`, `dracut-live`, `livesys-scripts`, `isomd5sum`, `squashfs-tools`, `xorriso`, `grub2-efi-x64-cdboot`, `slitherer` |
| Storage backends | `libblockdev-btrfs`, `libblockdev-dm`, `libblockdev-lvm`, `libblockdev-mpath`, `bootupd` |
| Shells & CLI | `fish`, `zsh`, `git-credential-libsecret`, `openssh-askpass`, `zenity` |
| Input / IME | `ibus-mozc`, `ibus-unikey`, `mozc`, `input-remapper` |
| Fonts | `google-noto-sans-cjk-vf-fonts` |
| Tray / indicator | `libappindicator-gtk3`, `libayatana-appindicator-gtk3` |
| Hardware | `alsa-firmware`, `alsa-tools-firmware`, `evtest`, `igt-gpu-tools`, `libratbag-ratbagd`, `openrgb-udev-rules`, `switcheroo-control` |
| Camera / media | `libcamera-gstreamer`, `libcamera-tools`, `libva-utils`, `pipewire-libs-extra`, `mesa-libGLU` |
| Remote / sharing | `nautilus-gsconnect`, `waypipe`, `gvfs-nfs` |
| Containers | `containerd` |
| Desktop plumbing | `gnome-ponytail-daemon`, `python3-gnome-ponytail-daemon`, `xdg-terminal-exec`, `flatpak-spawn`, `firewall-config` |
| Toolchain / compat | `gcc-c++`, `libxcrypt-compat`, `gnupg2-scdaemon` |
| Browser | `firefox` (Sivablue explicitly removes it) |

### 10.2 Installed by Sivablue, not by Bluefin (35)

| Group | Packages |
|---|---|
| Virtualisation | `libvirt`, `libvirt-nss`, `virt-manager`, `virt-v2v`, `virt-viewer`, `swtpm-tools`, `qemu`, `qemu-img`, `qemu-char-spice`, `qemu-system-x86-core`, `qemu-user-binfmt`, `qemu-user-static`, `qemu-device-display-virtio-gpu`, `qemu-device-display-virtio-vga`, `qemu-device-usb-redirect` |
| Containers | `podman-compose`, `podman-machine` |
| CLI tooling | `htop`, `ripgrep`, `tmux`, `glow`, `nvtop`, `p7zip`, `p7zip-plugins` |
| Python | `python3-pip`, `pipx` |
| Hardware / net | `iwd`, `lm_sensors`, `nvme-cli` |
| Crypto / storage | `gocryptfs`, `openssl` |
| Dev / build | `flatpak-builder`, `gtk4-layer-shell`, `curl` |
| Shell UX | `bash-color-prompt` |

Several of these Bluefin does ship — just through Homebrew rather than RPM:
`htop`, `tmux`, `glow` and `fzf` are in `preinstall.d/system-cli.Brewfile`, and
`starship`, `rclone`, `restic`, `smartmontools`, `tcpdump`, `ykman` come with
them. Comparing RPM lists alone overstates the gap.

### 10.3 Installed by both (14)

`adw-gtk3-theme`, `adwaita-fonts-all`, `bootc`, `ddcutil`, `distrobox`,
`fastfetch`, `fzf`, `gcc`, `gnome-tweaks`, `gum`, `just`, `make`,
`wireguard-tools`, `wl-clipboard`

### 10.4 Removed by both (9)

`fedora-bookmarks`, `fedora-chromium-config`, `fedora-chromium-config-gnome`,
`firefox-langpacks`, `gnome-extensions-app`,
`gnome-shell-extension-background-logo`, `gnome-software`,
`gnome-software-rpm-ostree`, `podman-docker`

### 10.5 Removed by Bluefin only (6)

`default-fonts-cjk-sans`, `fedora-third-party`, `gnome-terminal-nautilus`,
`google-noto-sans-cjk-fonts`, `totem-video-thumbnailer`, `yelp`

`fedora-third-party` is the notable one — the opt-in prompt for Fedora's
third-party repositories, which Bluefin treats as a footgun on an atomic image.
Sivablue leaves it installed.

### 10.6 Removed by Sivablue only (9)

`PackageKit-command-not-found`, `dnf-data`, `dracut-config-rescue`, `firefox`,
`gnome-system-monitor`, `iptables-services`, `iptables-utils`,
`mozilla-fira-mono-fonts`, `rsyslog`

### 10.7 Multimedia overrides — Bluefin only

Distro-synced from `negativo17/fedora-multimedia` and `versionlock`ed:
`intel-gmmlib`, `intel-mediasdk`, `intel-vpl-gpu-rt`, `libheif`, `libva`,
`libva-intel-media-driver`, `mesa-dri-drivers`, `mesa-filesystem`, `mesa-libEGL`,
`mesa-libGL`, `mesa-libgbm`, `mesa-vulkan-drivers`.

Plus a bulk install of `ffmpeg`, `ffmpeg-libs`, `libavcodec`, `@multimedia`,
`gstreamer1-plugins-{bad-free,bad-free-libs,good,base}`, `lame`, `lame-libs`,
`libfdk-aac`, `libjxl`, `ffmpegthumbnailer`.

Sivablue's equivalent is narrower: `libavcodec-freeworld` from RPM Fusion and
`openh264`/`mozilla-openh264` from the Cisco repo, both installed in
`12-waterfox.sh` for browser playback specifically.

---

## 11. Method

Read from `../bluefin` at `stable-20260720-81-gc442e5c`: `Containerfile`,
`image-versions.yml`, all of `build_files/`, all of `system_files/`,
`.gitmodules`, `docs/architecture.md`, the `Justfile` recipe list, the `tests/`
listing, and the workflow listing plus `build-image-testing.yml` and
`nightly.yml`.

Read from `../common` at `e802c81` (shallow clone, `--depth 50`): `Containerfile`,
the complete `system_files/` listing (202 files) and the contents of the
setup-service scripts, `libsetup.sh`, `ujust` and all `*.just` files, the
gschema override and dconf trees, uupd units and config, `brew-preinstall` and
the `preinstall.d` Brewfiles, the OEM and hardware hooks, `rechunker-group-fix`,
`bootc-update-stage`, `luks-tpm2-autounlock`, and the `tests/`, `docs/` and
`specs/` listings.

Compared against Sivablue at `83f9ab2`: `Containerfile`, all of `build/`, the
`system/` tree including `libsetup.sh`, `sivablue-user-setup`, `ujust`,
`sivablue-motd`, the gschema override and `distro.d/` files, all `*.just` files,
`.gitmodules`, `.github/workflows/build.yml`, and `docs/`.

Package tables computed by parsing `build_files/packages/base.toml` against the
`FEDORA_PACKAGES` / `EXCLUDED_PACKAGES` arrays in `build/10-packages.sh`.

**Not examined:** `ghcr.io/ublue-os/brew` and `projectbluefin/actions` (the
reusable workflows both images call), and
[`Sir-Mudkip/Sivablue-iso`](https://github.com/Sir-Mudkip/Sivablue-iso) beyond
its top-level layout — the ISO side of Sivablue deserves its own comparison
against Bluefin's embedded approach and does not get one here. Claims about Homebrew delivery mechanics
are inferred from the Brewfiles and unit presets in `common`, not from the brew
image itself.
