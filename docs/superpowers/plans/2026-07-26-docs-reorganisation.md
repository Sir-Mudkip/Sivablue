# Documentation Reorganisation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Consolidate all build and design documentation into `docs/`, delete the stale upstream-template documentation (three files of which currently ship into the image), and split `CLAUDE.md` so enforceable rules stay auto-loaded while rationale moves to `docs/`.

**Architecture:** Ten Markdown pages under `docs/`, one ordered stage reference plus topic pages for cross-cutting decisions. No shell script is edited; the only executable-path change is deleting three READMEs from `system/`, which `build/build.sh` mirrors into the image via `cp -rT`.

**Tech Stack:** Markdown, bash (verification only), `just` recipes (`lint`, `check`, `format`, `build`), `git`.

**Spec:** `docs/superpowers/specs/2026-07-26-docs-reorganisation-design.md`

## How content is specified in this plan

This is a documentation task, so the deliverable is prose rather than code. Each
page below is specified by its exact heading structure plus the specific facts
each section must state, with `file:line` citations so the writer verifies against
the source rather than inventing. Where exact wording matters — the `ghcurl`
paragraph, the `CLAUDE.md` convention line — verbatim text is given and must be
used as written. "Write something sensible about X" is never acceptable; every
required fact is enumerated.

Prose style: plain declarative sentences, British spelling to match the existing
repository, no marketing language, no emoji. Explain **why**, not just what — the
what is readable from the scripts.

## Global Constraints

- **Always `dnf5`** in any example or prose. Never bare `dnf`, `yum`, or `rpm-ostree`.
- **Conventional commits**: `<type>[scope]: <description>`, types `feat: fix: docs: chore: build: ci: refactor: test:`.
- **Every commit ends with** the footer `Assisted-by: Claude Opus 5 via Claude Code`.
- **Never commit `cosign.key`.** It is gitignored; `cosign.pub` is committed deliberately.
- **Be surgical.** Prefer the smallest change that works.
- **Do not touch:** `.github/renovate.json5`, `.github/workflows/validate-*.yml`, `.gitignore`, `build/copr-helpers.sh`, `cosign.pub`, `LICENSE`.
- **Do not edit any build script.** The only change under `build/` is deleting `build/README.md`.
- **`docs/` is maintainer-facing only.** No end-user documentation, no docs site.
- **No automated drift check** between `docs/` and `build/` — decided against in the spec.
- **Never move or edit** `system/etc/misc.d/hashcat-install.md` or `system/usr/share/sivablue/motd/welcome.md`. Both are functional: the first is rendered by `glow` from `system/usr/share/sivablue/just/fetch.just:20`, the second is the MOTD body rendered via `system/etc/profile.d/welcome.sh`.
- Run every command from the repository root, `/var/home/luke/projects/Sivablue`.

## File Structure

**Created:**

| File | Responsibility |
|---|---|
| `docs/README.md` | Index; the rule for which page to update for a given change |
| `docs/build-stages.md` | Every build stage in execution order, and why ordering is load-bearing |
| `docs/filesystem-layout.md` | Where files go in the image and why |
| `docs/settings.md` | The two settings mechanisms and when each applies |
| `docs/extensions.md` | GNOME extension vendoring, building, enabling |
| `docs/flatpaks.md` | Flatpak preinstall mechanism |
| `docs/ujust.md` | User-facing `ujust` commands |
| `docs/user-setup.md` | Per-user setup hooks and their versioning semantics |
| `docs/signing.md` | cosign signing, enforcement, rotation |
| `docs/ci.md` | Workflows, secrets, image identity |

**Deleted:** `build/README.md`, `system/usr/share/sivablue/just/README.md`, `system/usr/share/flatpak/preinstall.d/README.md`, `system/usr/share/fastfetch/README.md`, `.github/SETUP_CHECKLIST.md`

**Modified:** `CLAUDE.md`, `Containerfile`, `CONTRIBUTING.md`, `README.md`, `.github/copilot-instructions.md`, `.github/workflows/renovate.yml`, `.github/workflows/build.yml`

---

### Task 1: `docs/build-stages.md`

The largest new page, and the one nothing in the repository currently records.

**Files:**
- Create: `docs/build-stages.md`
- Delete: `build/README.md`
- Read for source: `build/build.sh`, `build/*.sh` (all 16 stages), `build/copr-helpers.sh`, `build/ghcurl`

**Interfaces:**
- Produces: `docs/build-stages.md`, linked from `docs/README.md` (Task 7) and `CLAUDE.md` (Task 8).

- [ ] **Step 1: Write the verification check first**

Create the check that proves every stage is documented. Run it now, before writing the page, and confirm it fails:

```bash
for f in build/[0-9]*.sh; do
  grep -q "$(basename "$f")" docs/build-stages.md 2>/dev/null || echo "UNDOCUMENTED: $(basename "$f")"
done
```

Expected now: 16 `UNDOCUMENTED:` lines (the file does not exist yet).

- [ ] **Step 2: Write `docs/build-stages.md`**

Required heading structure and the facts each section must state:

**`# Build stages`** — intro: `Containerfile` runs `build/build.sh`, which first mirrors the `system/` tree into the image with two `cp -rT` calls (`build/build.sh:7-8`), then calls each stage **by name**. It does not glob. A new stage that is not added to `build.sh` silently never runs.

**`## Ordering`** — state both constraints:
- Third-party repository installs must land **before `96-overrides.sh`**, which disables those repositories by filename (`build/96-overrides.sh:26-31`).
- Reordering dnf installs can change dependency resolution, so when splitting a stage out, keep its original position.

**`## Stage boilerplate`** — every stage is `#!/usr/bin/bash`, `set -eoux pipefail`, wrapped in `echo "::group:: ===$(basename "$0")==="` / `echo "::endgroup::"`, mode `0755`. The `::group::` markers fold the stage's output in GitHub Actions logs.

**`## The stages`** — one subsection per stage, in `build.sh` order. Each states what it does and why it sits at that number:

| Stage | Must state |
|---|---|
| `00-image-info.sh` | Writes `/usr/share/sivablue/image-info.json` and rewrites `/usr/lib/os-release` branding fields. `VERSION` defaults to the UTC build date, so image version *is* the build date. Derives `IMAGE_NAME`/`IMAGE_REPO` from `VARIANT`; `IMAGE_REPO` is lowercase because OCI/GHCR repository names must be. Sets `IMAGE_REF` to `ostree-image-signed:` — this is what makes signature verification mandatory on clients. Runs first so everything later sees correct branding. |
| `05-kernel-akmods.sh` | Nvidia variant only. Pulls prebuilt akmods from `ghcr.io/ublue-os/akmods-nvidia-open` with `skopeo`, runs upstream's `nvidia-install.sh`, blacklists nouveau via `/usr/lib/bootc/kargs.d/00-nvidia.toml`, installs `nvidia-container-toolkit-base` for CDI-based GPU passthrough (the `-base` variant deliberately excludes `libnvidia-container` and the legacy OCI hook, because CDI is the correct path for bootc/rootless containers), then removes the toolkit repo file. Early because the kernel must be settled before packages layer on it. |
| `06-docker.sh` | Runs `sysctl -p` **before** installing Docker to apply IP forwarding first and avoid breaking LXC networking. Writes `/etc/modules-load.d/ip_tables.conf` loading `iptable_nat` for docker-in-docker. Adds `docker-ce.repo`, immediately disables it with `sed`, installs with `--enablerepo=docker-ce-stable`. |
| `07-tailscale.sh` | Adds the Tailscale repo, disables it via `dnf5 config-manager setopt tailscale-stable.enabled=0`, installs with `--enablerepo`. Note it uses `setopt` where `06`/`08` use `sed` — same outcome, different idiom. |
| `08-vscode.sh` | Writes the Microsoft `vscode.repo` inline via a `tee` heredoc rather than fetching it, disables it, installs `code` with `--enablerepo=code`. |
| `10-packages.sh` | Sources `copr-helpers.sh`. Bulk-installs `FEDORA_PACKAGES` in one `dnf5` call — the comment "safe from COPR injection" is the reason it is a single bulk install from Fedora repos only. Then three isolated COPR installs (`che/nerd-fonts`, `ublue-os/packages` for `uupd`, `scottames/ghostty`). Then removes `EXCLUDED_PACKAGES` — note it first queries which are actually installed with `rpm -qa`, because `dnf5 remove` on an absent package would abort under `set -e`. Nvidia variant additionally removes ROCm packages, which conflict with the Nvidia stack. **This is the file to edit when adding a Fedora package.** |
| `12-waterfox.sh` | Tarball install. Queries GitHub's `releases/latest` via `ghcurl` (latest excludes prereleases, so betas are skipped), validates the tag against `^[0-9]+\.[0-9]+\.[0-9]+$` and hard-fails otherwise rather than shipping a stale browser. Installs to `/usr/lib/waterfox`, symlinks to `/usr/bin`. Installs `bzip2` only if missing and removes it again afterwards. Upstream publishes no checksums, so it sanity-checks the archive with `tar -tjf` — a truncated download or HTML error page fails here. Writes `distribution/policies.json` with `DisableAppUpdate` because `/usr` is read-only at runtime. Promotes bundled icons into hicolor and runs `gtk-update-icon-cache -f`, because GTK trusts the base image's icon cache and will not rescan for icons it predates — rpm does this for packaged installs, a tarball must do it by hand. |
| `13-eddie.sh` | Same `ghcurl` + version-validation pattern, but installs a standalone RPM fetched from `eddie.website`. Verifies it really is an RPM with `rpm -qp` before `dnf5 -y install`, so a truncated download fails here rather than inside dnf. |
| `15-extensions.sh` | Installs build tooling (`glib2-devel meson sassc cmake dbus-devel`), builds each vendored extension, compiles every schema with `glib-compile-schemas --strict`, then **removes the tooling again** to keep it out of the final image. Recompiles `/usr/share/glib-2.0/schemas` wholesale at the end. Must run after `system/` is mirrored, since the extensions are staged from there. |
| `20-content-cleanup.sh` | Removes `/usr/src` and `/usr/share/doc`. Erases `kernel-devel` from the rpmdb because its files under `/usr/src` are gone — guarded by `rpm -q` because it only exists on the nvidia variant and an unconditional erase would abort under `set -e`. Recompiles gschemas after wallpaper config changes. |
| `25-sysconfig.sh` | Service state. Masks cups/avahi/ModemManager/sssd/geoclue. Disables `rpm-ostreed-automatic.timer` (superseded by `uupd`). **Disables but does not mask `tailscaled.service`** — Tailscale is opt-in, so it must remain startable on demand. Enables system units and, via `systemctl --global`, the per-user `sivablue-user-setup.service`. Installs swtpm SELinux policy modules so `restorecon` can label `/usr/bin/swtpm` at boot. |
| `30-initramfs.sh` | Regenerates the initramfs with `dracut --no-hostonly --reproducible --add ostree`. Sets `DRACUT_NO_XATTR=1` and `chmod 0600` the result. Must run after all kernel-affecting stages. |
| `96-overrides.sh` | Patches `uupd.service` to add `--disable-module-distrobox` so background updates leave Distrobox containers alone. Hides `fish`/`htop`/`nvtop` desktop entries (`Hidden=true` also removes MIME associations). Adds the Flathub remote and disables `flatpak-add-fedora-repos.service`. **Disables third-party, COPR and RPM Fusion repos by filename** — this is why third-party installs must come earlier. |
| `97-validate-repos.sh` | Fails the build if any repo file still contains `enabled=1`. Security gate: an enabled COPR could inject malicious versions of Fedora packages at runtime. Allows `fedora-updates-testing` only when `UBLUE_IMAGE_TAG=beta`. |
| `98-clean-stage.sh` | Resets `keepcache=0`, clears versionlocks, masks and deletes `flatpak-add-fedora-repos.service`, then empties `/var` (keeping `cache/libdnf5` and `cache/rpm-ostree`), `/tmp` and `/boot`. |
| `99-tests.sh` | The build's own gate. Verifies the ublue-os signing key hashes (without them a published image cannot pull `ghcr.io/ublue-os/*` and therefore cannot update), stats the `ujust` binary and each `.just` file, checks the Waterfox tarball install, the fastfetch config and logo, and `default.preinstall`. Asserts required packages are present, unwanted ones absent, and required timers enabled. **Add a check here for anything `rpm -q` cannot verify** — tarball installs and files staged from `system/`. |

**`## COPR installs`** — `copr_install_isolated "owner/project" pkg…` from `build/copr-helpers.sh` enables the COPR, immediately disables it, then installs with `--enablerepo=<generated id>`. The repo is therefore never globally enabled, which is what `97-validate-repos.sh` enforces.

**`## Adding a stage`** — create `build/NN-name.sh` with the boilerplate, `chmod 0755`, and **add an explicit call in `build/build.sh`**. Place it before `96-overrides.sh` if it adds a third-party repo. Update this page.

**`## `ghcurl` token permissions`** — use this text verbatim:

> `ghcurl` requires no token scopes. Its two callers, `12-waterfox.sh` and
> `13-eddie.sh`, read release metadata from public repositories, so a token only
> lifts the GitHub API rate limit from 60 requests per hour per IP to 5,000. CI's
> automatic `secrets.GITHUB_TOKEN` (`contents: read`, `.github/workflows/build.yml:21`)
> is sufficient; locally, any scopeless classic PAT exported as `GITHUB_TOKEN` is
> forwarded as a podman secret by `Justfile:143-145`. Without a token the build
> still works but can fail on HTTP 403, and both stages deliberately hard-fail
> rather than ship a stale version.

**`## dnf5, always`** — DNF 4 is gone; on Fedora 41+ `dnf` is only a symlink to `dnf5`. Writing `dnf` reads as if DNF 4 semantics were intended when they are not, and these scripts already use DNF 5-only syntax (`config-manager addrepo`, `config-manager setopt`) that DNF 4 cannot parse. Being explicit also keeps the scripts honest if the image is ever rebased onto a base where `dnf` really is DNF 4.

- [ ] **Step 3: Run the check to verify it now passes**

```bash
for f in build/[0-9]*.sh; do
  grep -q "$(basename "$f")" docs/build-stages.md || echo "UNDOCUMENTED: $(basename "$f")"
done
echo "check complete"
```

Expected: no `UNDOCUMENTED:` lines, just `check complete`.

- [ ] **Step 4: Verify the ghcurl requirement is satisfied**

```bash
grep -c 'ghcurl' docs/build-stages.md
grep -q '5,000' docs/build-stages.md && echo "rate-limit line present"
```

Expected: a non-zero count, and `rate-limit line present`.

- [ ] **Step 5: Delete the stale build README and confirm nothing referenced it**

```bash
git rm build/README.md
grep -rn 'build/README' . --exclude-dir=.git --exclude-dir=docs || echo "no references — clean"
```

Expected: `no references — clean`.

- [ ] **Step 6: Commit**

```bash
git add docs/build-stages.md
git commit -m "$(cat <<'EOF'
docs: document every build stage in docs/build-stages.md

Records what each of the 16 stages does and why its position is
load-bearing, plus the ghcurl token permissions, which were previously
written down nowhere. Deletes build/README.md, which described the
upstream template layout (10-build.sh, .example scripts) that does not
exist in this repository.

Assisted-by: Claude Opus 5 via Claude Code
EOF
)"
```

---

### Task 2: `docs/filesystem-layout.md`

**Files:**
- Create: `docs/filesystem-layout.md`
- Delete: `system/usr/share/fastfetch/README.md`
- Read for source: `system/usr/share/fastfetch/README.md` (before deleting), `Containerfile`, `build/build.sh:7-8`, `build/12-waterfox.sh`

**Interfaces:**
- Consumes: nothing.
- Produces: `docs/filesystem-layout.md`. Task 1's Waterfox section may link here for the `/usr/lib` rationale.

- [ ] **Step 1: Capture the fastfetch content before deleting it**

```bash
cat system/usr/share/fastfetch/README.md
```

This page is accurate and its regeneration recipe must survive verbatim. Copy it out now.

- [ ] **Step 2: Write `docs/filesystem-layout.md`**

Required headings and facts:

**`# Filesystem layout`** — intro: anything static goes in `system/`; anything that needs to run goes in a `build/` stage.

**`## The `system/` mirror`** — `build/build.sh:7-8` does `cp -rT /ctx/system/usr/ /usr/` and `cp -rT /ctx/system/etc/ /etc/`. So `system/usr/…` becomes `/usr/…` verbatim. **Consequence: every file placed under `system/` ships to every installed machine.** That is why no explanatory README lives there — documentation belongs in `docs/`, which is not mirrored.

**`## `/usr` is read-only at runtime`** — bundled self-updaters cannot work and must be disabled. Firefox-family applications need a `distribution/policies.json` with `DisableAppUpdate` (see `build/12-waterfox.sh`). Updates arrive via image rebuild plus `bootc upgrade`, so "latest" means latest **at build time**.

**`## Tarballs go to `/usr/lib`, not `/opt``** — install under `/usr/lib/<name>` and symlink into `/usr/bin`. `/opt` is not available: the `Containerfile` does `rm /opt && mkdir /opt` to make it immutable. `build/12-waterfox.sh` is the reference implementation.

**`## `/etc` versus `/usr/share``** — `/etc` is for configuration an administrator may override; `/usr/share` is for vendor data. Concrete examples from this image: the fastfetch config lives at `/etc/fastfetch/config.jsonc` so it applies to every user while a user's own `~/.config/fastfetch/config.jsonc` still fully overrides it; the flatpak preinstall file lives at `/usr/share/flatpak/preinstall.d/` (see `docs/flatpaks.md`).

**`## Static assets`** — include the fastfetch logo rationale **verbatim from the deleted README**: `logos/sivablue.txt` is a pre-rendered coloured-braille text logo; `config.jsonc` sets `logo.type` to `file-raw` so fastfetch prints the file's bytes verbatim, meaning no image libraries are needed at runtime (no chafa, no ImageMagick) and it renders in any terminal, even when piped. It is committed as a static asset rather than generated during the build because the logo changes almost never, so a build stage would be more machinery than it warrants. Its source of truth is `system/usr/share/backgrounds/sivablue/siva-mini-logo.svg`.

Include the regeneration recipe verbatim:

```bash
png="$(mktemp --suffix=.png)"
rsvg-convert -w 640 -h 612 -b none \
  system/usr/share/backgrounds/sivablue/siva-mini-logo.svg -o "$png"

# coloured braille, transparent background; strip chafa's cursor-control escapes
# so the baked-in logo never fiddles with the viewer's terminal cursor
chafa --format symbols --symbols braille --fg-only --fill braille --size 40x20 "$png" \
  | sed -E 's/\x1b\[\?25[lh]//g' \
  > system/usr/share/fastfetch/logos/sivablue.txt
rm -f "$png"
```

Note it needs `librsvg2-tools` and the `chafa` CLI.

- [ ] **Step 3: Verify the required facts are present**

```bash
for s in 'cp -rT' 'read-only' '/usr/lib' 'rm /opt' 'file-raw' 'chafa' 'librsvg2-tools'; do
  grep -q -- "$s" docs/filesystem-layout.md || echo "MISSING: $s"
done
echo "check complete"
```

Expected: no `MISSING:` lines.

- [ ] **Step 4: Delete the fastfetch README and confirm nothing referenced it**

```bash
git rm system/usr/share/fastfetch/README.md
grep -rn 'fastfetch/README' . --exclude-dir=.git --exclude-dir=docs || echo "no references — clean"
grep -n 'fastfetch' build/99-tests.sh
```

Expected: `no references — clean`, and `99-tests.sh` shows it stats `config.jsonc` and `logos/sivablue.txt` only — never the README.

- [ ] **Step 5: Commit**

```bash
git add docs/filesystem-layout.md
git commit -m "$(cat <<'EOF'
docs: record filesystem placement decisions

Explains the system/ mirror, why /usr being read-only forces bundled
updaters off, why tarballs go to /usr/lib rather than /opt, and the
fastfetch logo rationale. Deletes the fastfetch README, which shipped
into the image at /usr/share/fastfetch/README.md.

Assisted-by: Claude Opus 5 via Claude Code
EOF
)"
```

---

### Task 3: `docs/settings.md` and `docs/extensions.md`

**Files:**
- Create: `docs/settings.md`, `docs/extensions.md`
- Read for source: `CLAUDE.md`, `.gitmodules`, `build/15-extensions.sh`, `system/usr/share/glib-2.0/schemas/zz0-sivablue-mods.gschema.override`, `system/etc/dconf/db/distro.d/`

**Interfaces:**
- Produces: `docs/settings.md`, `docs/extensions.md`. `extensions.md` links to `settings.md` for the enabling mechanism.

- [ ] **Step 1: Write `docs/settings.md`**

Required headings and facts:

**`# Settings`** — open with the central warning: there are two mechanisms and they are **not interchangeable**. An override written in the wrong one silently does nothing.

**`## gschema overrides`** — `system/usr/share/glib-2.0/schemas/zz0-sivablue-mods.gschema.override` overrides defaults for schemas installed **in that same directory**: `org.gnome.shell`, `org.gnome.desktop.*`, Ptyxis, and so on. The `zz0-` prefix makes it sort last so it wins. Schemas are recompiled by `build/15-extensions.sh` and again by `build/20-content-cleanup.sh`.

**`## dconf database`** — `system/etc/dconf/db/distro.d/` sets values **by path**, so it is the only option for relocatable schemas and for extensions that ship their schema inside their own directory. `system/etc/dconf/db/distro.d/locks/` prevents users changing a value. `dconf-update.service` is enabled in `build/25-sysconfig.sh`.

**`## Choosing between them`** — a decision rule: if the schema is installed into `/usr/share/glib-2.0/schemas/` use the override file; if the schema is relocatable or ships inside an extension directory, use `distro.d`.

- [ ] **Step 2: Write `docs/extensions.md`**

Required headings and facts:

**`# GNOME extensions`** — extensions are vendored as **git submodules** under `system/usr/share/gnome-shell/extensions/<uuid>/`. CI checks out with `submodules: recursive`; a plain clone gives empty directories and a failing build.

**`## Current extensions`** — table from `.gitmodules`: `dash-to-dock@micxgx.gmail.com` (micheleg/dash-to-dock), `logomenu@aryan_k` (ublue-os/Logomenu), `gradia-integration@alexandervanhee.github.io` (AlexanderVanhee/gradia-capture), `clipboard-indicator@tudmotu.com` (Tudmotu/gnome-shell-extension-clipboard-indicator).

**`## Building`** — build steps live in `build/15-extensions.sh`, which installs `glib2-devel meson sassc cmake dbus-devel`, builds each extension, compiles every schema with `glib-compile-schemas --strict`, then removes the tooling so it stays out of the final image. Dash to Dock uses `make`; Logo Menu installs two helper binaries into `/usr/bin`; Gradia runs its own `build.sh` and the resulting zip is unpacked and deleted.

**`## Enabling`** — add the UUID to `enabled-extensions` in `system/usr/share/glib-2.0/schemas/zz0-sivablue-mods.gschema.override`. Link to `docs/settings.md`.

**`## Adding one`** — `git submodule add` under the UUID-named path, add build steps to `build/15-extensions.sh`, add the UUID to `enabled-extensions`, and **check `metadata.json`'s `shell-version` covers the base image's GNOME release** — an extension that does not claim support for the running shell version is silently ignored.

**`## Note on linting`** — `just lint` recurses into vendored submodules and reports on upstream code (for example gradia's `build.sh`). Those findings are upstream's, not this repository's.

- [ ] **Step 3: Verify both pages**

```bash
for s in 'not interchangeable' 'distro.d' 'relocatable' 'zz0-sivablue-mods'; do
  grep -q -- "$s" docs/settings.md || echo "MISSING in settings.md: $s"
done
for s in 'submodule' 'recursive' 'enabled-extensions' 'shell-version' '15-extensions.sh'; do
  grep -q -- "$s" docs/extensions.md || echo "MISSING in extensions.md: $s"
done
echo "check complete"
```

Expected: no `MISSING` lines.

- [ ] **Step 4: Commit**

```bash
git add docs/settings.md docs/extensions.md
git commit -m "$(cat <<'EOF'
docs: document the two settings mechanisms and GNOME extensions

settings.md records why gschema overrides and the dconf database are not
interchangeable and how to choose. extensions.md covers submodule
vendoring, the build steps in 15-extensions.sh, and the shell-version
check that silently disables an extension when wrong.

Assisted-by: Claude Opus 5 via Claude Code
EOF
)"
```

---

### Task 4: `docs/flatpaks.md` and `docs/ujust.md`

Both replace a stale README that currently ships into the image.

**Files:**
- Create: `docs/flatpaks.md`, `docs/ujust.md`
- Delete: `system/usr/share/flatpak/preinstall.d/README.md`, `system/usr/share/sivablue/just/README.md`
- Read for source: `system/usr/share/flatpak/preinstall.d/default.preinstall`, `system/usr/share/sivablue/just/*.just`, `build/99-tests.sh`

**Interfaces:**
- Produces: `docs/flatpaks.md`, `docs/ujust.md`.

- [ ] **Step 1: List the real `.just` files so the page is accurate**

```bash
ls system/usr/share/sivablue/just/
grep -n 'share/sivablue/just' build/99-tests.sh
```

Note the exact filenames — the page must name them, and `99-tests.sh` stats them.

- [ ] **Step 2: Write `docs/flatpaks.md`**

Required headings and facts:

**`# Flatpaks`** — applications are declared for preinstall, not baked into the image.

**`## The critical constraint`** — `system/usr/share/flatpak/preinstall.d/default.preinstall` **must exist in the image**. If it does not, Bazaar is uninstalled from users' systems. `build/99-tests.sh` asserts `test -f /usr/share/flatpak/preinstall.d/default.preinstall` for exactly this reason. Never delete or rename that file.

**`## Adding a Flatpak`** — add a `[Flatpak Preinstall <id>]` block to `default.preinstall`. Keys: `Install` (boolean, default true), `Branch` (string, commonly `stable`), `IsRuntime` (boolean, default false), `CollectionID`. Show a two-entry INI example.

**`## Installation timing`** — Flatpaks are **not** in the ISO or container image. They download on first boot after user setup completes and a network connection exists. Consequences: the ISO stays small and bootable offline, users need an internet connection afterwards, and first boot takes longer while Flatpaks download. This is not an offline ISO with pre-embedded applications.

**`## Remotes`** — `build/96-overrides.sh` adds the Flathub remote and disables `flatpak-add-fedora-repos.service`; `build/98-clean-stage.sh` masks and deletes that unit, and `build/99-tests.sh` fails the build if it reappears.

**Correctness note for the writer:** the deleted README claimed these files go to `/etc/flatpak/preinstall.d/`. They do not — the path is `/usr/share/flatpak/preinstall.d/`. Use the correct path.

- [ ] **Step 3: Write `docs/ujust.md`**

Required headings and facts:

**`# ujust`** — user-facing commands live in `system/usr/share/sivablue/just/*.just` and are surfaced to users by the `ujust` command.

**`## Renaming breaks the build`** — `build/99-tests.sh` stats each `.just` file by name, so renaming one fails the build. Name the actual files present (from Step 1) and quote the `for i in bin/ujust share/sivablue/just/{…}` loop.

**`## Writing a recipe`** — show a real, correct example using the `[group('…')]` attribute and a `#!/usr/bin/bash` shebang for multi-line recipes. Note `source /usr/lib/ujust/ujust.sh` provides `Choose()` and `Confirm()` helpers, and `gum` is available for prompts.

**`## Naming`** — verb prefixes: `install-`, `configure-`, `setup-`, `toggle-`, `fix-`.

**`## Do not install packages in a recipe`** — the image is immutable and `/usr` is read-only; package installation happens at build time in `build/10-packages.sh`. At runtime, use Flatpaks, Homebrew, or distrobox/toolbox containers instead.

**Correctness note for the writer:** the deleted README described a `custom/ujust/` directory, `custom/brew/` Brewfile shortcuts, and consolidation into `/usr/share/ublue-os/just/60-custom.just` by `build/10-build.sh`. **None of that exists.** Document only the real layout. Keep the page short — generic `just` syntax is covered better by the Just Manual, which the page should link to rather than reproduce.

- [ ] **Step 4: Delete both stale READMEs and verify nothing referenced them**

```bash
git rm system/usr/share/flatpak/preinstall.d/README.md
git rm system/usr/share/sivablue/just/README.md
grep -rn 'preinstall.d/README\|just/README' . --exclude-dir=.git --exclude-dir=docs || echo "no references — clean"
```

Expected: `no references — clean`.

- [ ] **Step 5: Confirm the test gate still only references recipe files**

```bash
grep -n 'share/sivablue/just' build/99-tests.sh
grep -n 'default.preinstall' build/99-tests.sh
```

Expected: the `.just` recipe names and `default.preinstall` — no README. Confirms the deletions cannot fail the build.

- [ ] **Step 6: Commit**

```bash
git add docs/flatpaks.md docs/ujust.md
git commit -m "$(cat <<'EOF'
docs: document flatpak preinstall and ujust

Replaces two stale READMEs that shipped into the image. The flatpak one
gave the wrong install path (/etc rather than /usr/share); the ujust one
was 241 lines describing a custom/ujust layout that does not exist.

Assisted-by: Claude Opus 5 via Claude Code
EOF
)"
```

---

### Task 5: `docs/user-setup.md`

**Files:**
- Create: `docs/user-setup.md`
- Read for source: `system/usr/lib/sivablue/setup-services/libsetup.sh`, `system/usr/share/sivablue/user-setup.hooks.d/`, `build/25-sysconfig.sh`

**Interfaces:**
- Produces: `docs/user-setup.md`.

- [ ] **Step 1: Confirm the hook list and the versioning semantics**

```bash
ls system/usr/share/sivablue/user-setup.hooks.d/
sed -n '1,35p' system/usr/lib/sivablue/setup-services/libsetup.sh
```

Confirm: `version-script` writes the new version into `setup_versioning.json` and *then* returns 0, so the version is recorded **before** the hook body executes.

- [ ] **Step 2: Write `docs/user-setup.md`**

Required headings and facts:

**`# Per-user setup`** — hooks live in `system/usr/share/sivablue/user-setup.hooks.d/NN-name.sh` and are run by `sivablue-user-setup`, a user service that iterates the directory. **No registration is needed** — unlike build stages, which must be named explicitly in `build/build.sh`. The service is enabled globally in `build/25-sysconfig.sh` via `systemctl --global enable sivablue-user-setup.service`.

**`## Hook boilerplate`** — show it exactly:

```bash
source /usr/lib/sivablue/setup-services/libsetup.sh
version-script <name> user <n> || exit 0
```

**`## Versioning semantics`** — state the consequence plainly: `version-script` records the version in `$HOME/.local/share/sivablue/setup_versioning.json` **before** the hook body runs. A hook that fails partway is therefore **never retried**. Make hooks defensive and never destructive, and guard against clobbering existing user data. Bump `<n>` to make an updated hook re-run for existing users.

**`## Current hooks`** — list those found in Step 1 with one line each on what they do.

- [ ] **Step 3: Verify required facts**

```bash
for s in 'version-script' 'never retried' 'no registration' 'setup_versioning.json' 'sivablue-user-setup'; do
  grep -qi -- "$s" docs/user-setup.md || echo "MISSING: $s"
done
echo "check complete"
```

Expected: no `MISSING` lines.

- [ ] **Step 4: Commit**

```bash
git add docs/user-setup.md
git commit -m "$(cat <<'EOF'
docs: document per-user setup hooks

Records that version-script writes the version before the hook body runs,
so a hook failing partway is never retried — the reason hooks must be
defensive and non-destructive.

Assisted-by: Claude Opus 5 via Claude Code
EOF
)"
```

---

### Task 6: `docs/signing.md`, `docs/ci.md`, and the dangling workflow references

**Files:**
- Create: `docs/signing.md`, `docs/ci.md`
- Delete: `.github/SETUP_CHECKLIST.md`
- Modify: `.github/workflows/renovate.yml:36`, `.github/workflows/build.yml:192`
- Read for source: `.github/SETUP_CHECKLIST.md`, `.github/workflows/build.yml`, `.github/actions/check-token-health/action.yml`, `Containerfile:1-16`

**Interfaces:**
- Produces: `docs/signing.md`, `docs/ci.md`. Both workflow comments will point at these paths, so the filenames are fixed.

- [ ] **Step 1: Confirm both dangling references before changing anything**

```bash
grep -n 'SETUP_CHECKLIST' .github/workflows/renovate.yml
sed -n '190,193p' .github/workflows/build.yml
grep -ic 'sign' README.md || echo "README.md has no signing section — build.yml:192 is dangling"
```

Expected: `renovate.yml:36` mentions `SETUP_CHECKLIST.md`; `build.yml:192` says `See README.md "Optional: Enable Image Signing"`; `README.md` has no such section, confirming the reference is dangling.

- [ ] **Step 2: Write `docs/signing.md`**

Port the signing half of `.github/SETUP_CHECKLIST.md` — its content is current and accurate. Required headings and facts:

**`# Image signing`** — signing is **not optional**. `system/etc/containers/policy.json` requires every `ghcr.io/sir-mudkip/sivablue` and `ghcr.io/sir-mudkip/sivablue-nvidia` image to carry a valid cosign signature made with the key in `system/usr/lib/pki/containers/sivablue.pub`. A machine will **refuse to pull or `bootc upgrade`** to an image that is not correctly signed — the image ref is `ostree-image-signed:`, set in `build/00-image-info.sh`. This defeats registry tampering and unsigned or third-party images.

**`## Key setup`** — keep the existing commands verbatim, including the `cosign public-key --key cosign.key | diff - system/usr/lib/pki/containers/sivablue.pub` check and the note that it must be identical or signing will not satisfy the policy. Use a dedicated cosign key for this image only. `SIGNING_SECRET` must stay set; if signing fails, publishing fails by design. **Never commit `cosign.key`** — it is gitignored; `cosign.pub` is committed deliberately.

**`## Rotation`** — the existing three steps, in order, ending with "build and publish a newly-signed image **before** clients drop the old key".

**`## Verification`** — keep both commands: `cosign verify --key …` and the enforcement smoke test with `podman pull --signature-policy`.

**`## Residual risk`** — keep verbatim in substance: this gate stops tampered, unsigned and third-party images, but does **not** stop a fully compromised GitHub account, since CI would still sign a malicious build with the real key. Closing that gap needs phishing-resistant 2FA/passkeys plus branch protection with required signed commits, a publish-approval environment gate, or out-of-band signing with a key the GitHub account cannot use.

- [ ] **Step 3: Write `docs/ci.md`**

Required headings and facts:

**`# CI and repository setup`**

**`## Workflows`** — `build.yml` builds and publishes; `clean.yml` prunes; `renovate.yml` runs dependency updates; the `validate-*.yml` workflows are left alone by convention. `build.yml` ignores `**.md` on push and pull request, so a documentation-only change does not trigger an image build.

**`## Permissions`** — `build.yml` declares `contents: read`, `packages: write`, `id-token: write`, `attestations: write` (`.github/workflows/build.yml:20-24`).

**`## Secrets`** — `SIGNING_SECRET` holds the cosign private key (see `docs/signing.md`). The Renovate token is validated by the `check-token-health` composite action in `.github/actions/check-token-health/`, which fails fast if a token is expired, revoked, or missing required scopes; Renovate requires `repo,workflow`. `GITHUB_TOKEN` for `ghcurl` needs **no scopes** — link to the rate-limit explanation in `docs/build-stages.md` rather than repeating it.

**`## Image identity`** — the image name is set in `build/00-image-info.sh` (`IMAGE_NAME`, `IMAGE_REPO`, `IMAGE_VENDOR`) and referenced by `Justfile` and `artifacthub-repo.yml`. `IMAGE_REPO` must stay lowercase because OCI and GHCR repository names must be. Changing the name means updating all of those together.

- [ ] **Step 4: Repoint the two dangling workflow references**

Edit `.github/workflows/renovate.yml:36`, changing only the string inside the `echo`:

```
See docs/ci.md to set up the token.
```

Edit `.github/workflows/build.yml:192`, changing only the comment text:

```
      # OPTIONAL: Image Signing with Cosign (key-based)
      # Preserves the repository's existing cosign key signing. To disable, remove
      # the two steps below. See docs/signing.md.
```

Both are single-line string changes. Do not alter any step, `uses:`, `if:`, or permission.

- [ ] **Step 5: Delete the checklist and verify nothing still points at it**

```bash
git rm .github/SETUP_CHECKLIST.md
grep -rn 'SETUP_CHECKLIST' . --exclude-dir=.git --exclude-dir=docs || echo "no references — clean"
```

Expected: `no references — clean`.

- [ ] **Step 6: Verify the workflows are still valid YAML and otherwise unchanged**

```bash
python3 -c "import yaml,sys; [yaml.safe_load(open(f)) for f in ['.github/workflows/build.yml','.github/workflows/renovate.yml']]; print('both parse')"
git diff --stat .github/workflows/
```

Expected: `both parse`, and the diff shows exactly 1 changed line in each file.

- [ ] **Step 7: Commit**

```bash
git add docs/signing.md docs/ci.md .github/workflows/renovate.yml .github/workflows/build.yml
git commit -m "$(cat <<'EOF'
docs: split setup checklist into signing and CI pages

Moves the signing documentation and repository setup out of
.github/SETUP_CHECKLIST.md, whose first instruction was still to rename
the "finpilot" template. Repoints two dangling workflow references:
renovate.yml pointed at the deleted checklist and build.yml pointed at a
README.md section that never existed.

Assisted-by: Claude Opus 5 via Claude Code
EOF
)"
```

---

### Task 7: `docs/README.md` index

Written after every page exists, so no link is dangling at any point.

**Files:**
- Create: `docs/README.md`

**Interfaces:**
- Consumes: all nine pages from Tasks 1–6.
- Produces: `docs/README.md`, linked from `CLAUDE.md` (Task 8), root `README.md` and `CONTRIBUTING.md` (Task 9).

- [ ] **Step 1: Write `docs/README.md`**

Required content:

**`# Sivablue documentation`** — one line stating this documents **how the image is built and why**, for maintainers. End users want the root `README.md`, the welcome message, and `ujust --choose`.

**`## Pages`** — a table of all nine pages with a one-line description each: `build-stages.md`, `filesystem-layout.md`, `settings.md`, `extensions.md`, `flatpaks.md`, `ujust.md`, `user-setup.md`, `signing.md`, `ci.md`.

**`## Which page do I update?`** — a lookup table, because this is the question the convention in `CLAUDE.md` now obliges people to answer:

| Change | Page |
|---|---|
| Added, removed or renumbered a build stage | `build-stages.md` |
| Added a Fedora package, COPR or third-party repo | `build-stages.md` |
| Chose where a file lives in the image | `filesystem-layout.md` |
| Changed a default setting | `settings.md` |
| Added or updated a GNOME extension | `extensions.md` |
| Changed the preinstalled Flatpak list | `flatpaks.md` |
| Added a `ujust` command | `ujust.md` |
| Added a per-user setup hook | `user-setup.md` |
| Touched signing or key rotation | `signing.md` |
| Changed a workflow, secret or the image name | `ci.md` |

**`## Note`** — `docs/superpowers/` holds design specs and implementation plans generated during development. It is process history, not reference documentation, and is deliberately not indexed here.

- [ ] **Step 2: Verify every linked page exists**

```bash
grep -o '(\./[a-z-]*\.md)' docs/README.md | tr -d '()' | while read -r p; do
  test -f "docs/${p#./}" || echo "DANGLING: $p"
done
echo "check complete"
```

Expected: no `DANGLING:` lines. (Adjust the pattern if links are written without `./`.)

- [ ] **Step 3: Confirm all nine pages are indexed**

```bash
for p in build-stages filesystem-layout settings extensions flatpaks ujust user-setup signing ci; do
  grep -q "$p.md" docs/README.md || echo "NOT INDEXED: $p.md"
done
echo "check complete"
```

Expected: no `NOT INDEXED:` lines.

- [ ] **Step 4: Commit**

```bash
git add docs/README.md
git commit -m "$(cat <<'EOF'
docs: add docs/ index with a which-page-do-I-update table

Assisted-by: Claude Opus 5 via Claude Code
EOF
)"
```

---

### Task 8: `CLAUDE.md` — rules stay, rationale moves

The most delicate task. `CLAUDE.md` is auto-loaded into every agent session; `docs/` is not. **Every rule stays verbatim.** Only explanatory prose is removed, and only where `docs/` now carries it.

**Files:**
- Modify: `CLAUDE.md` (`AGENTS.md` is a symlink to it and needs no separate edit)

**Interfaces:**
- Consumes: all ten `docs/` pages.
- Produces: a `CLAUDE.md` whose Documentation section is referenced by Task 9's `CONTRIBUTING.md`.

- [ ] **Step 1: Confirm the symlink, so only one file is edited**

```bash
ls -l AGENTS.md
```

Expected: `AGENTS.md -> CLAUDE.md`.

- [ ] **Step 2: Replace the convention bullet**

Find this text in the Conventions section:

```
- **Do you not add massive comment blocks** - It is not neeeded to big blocks of comments in build files. If you want to explain something, or a design decision, it should be added to a file in each directory with an explanation as to why that decision was made.
```

Replace it with exactly this:

```
- **Do not add massive comment blocks to build files** — If you want to explain something, such as a design decision, it should be added to a file in the docs directory with an explanation as to why that decision was made. Per design change, this file should be updated. Each file should have an explanation of what each part of the build is doing e.g. what each build file is doing, why things are in `/usr/lib`, etc.
```

Use this wording verbatim. It is the user's own text and was approved in the spec.

- [ ] **Step 3: Add a Documentation section**

Insert after the Layout table:

```markdown
## Documentation

Build and design documentation lives in `docs/` — see [`docs/README.md`](docs/README.md)
for the index and a table of which page to update for a given change.

| Topic | Page |
|---|---|
| What each build stage does, ordering, `ghcurl` token | [`docs/build-stages.md`](docs/build-stages.md) |
| Where files go in the image and why | [`docs/filesystem-layout.md`](docs/filesystem-layout.md) |
| The two settings mechanisms | [`docs/settings.md`](docs/settings.md) |
| GNOME extensions | [`docs/extensions.md`](docs/extensions.md) |
| Flatpak preinstall | [`docs/flatpaks.md`](docs/flatpaks.md) |
| `ujust` commands | [`docs/ujust.md`](docs/ujust.md) |
| Per-user setup hooks | [`docs/user-setup.md`](docs/user-setup.md) |
| Signing and key rotation | [`docs/signing.md`](docs/signing.md) |
| Workflows, secrets, image identity | [`docs/ci.md`](docs/ci.md) |

Rules live here; the reasoning behind them lives in `docs/`. When you change a
design decision, update the relevant page in the same commit.
```

- [ ] **Step 4: Trim rationale, keeping every rule**

Work through these sections. In each, keep the rule sentence and append a `docs/` pointer; remove only the explanatory sentences now duplicated in `docs/`.

| Section | Keep verbatim | Remove (now in docs) |
|---|---|---|
| Build stages | All five bullets: calls by name, ordering load-bearing, reordering changes resolution, boilerplate, `99-tests.sh` is the gate | Nothing — these are all rules. Append: *Full stage-by-stage detail: [`docs/build-stages.md`](docs/build-stages.md).* |
| Installing software | All five bullets (Fedora, third-party, COPR, Flatpak, tarball) and both `/usr` bullets | The parenthetical worked detail in the tarball and `/usr` bullets, replaced by a link to `docs/filesystem-layout.md` |
| GNOME extensions | All four bullets | Append a link to `docs/extensions.md` |
| Settings | The two-mechanism rule and the "silently does nothing" warning | Append a link to `docs/settings.md` |
| Per-user setup | All three bullets, especially the `version-script` failure semantics | Append a link to `docs/user-setup.md` |
| ujust | The rule that renaming breaks the build | Append a link to `docs/ujust.md` |
| Conventions | `dnf5` rule sentence, conventional commits, `Assisted-by:` footer, never commit `cosign.key`, be surgical, and the replaced comment-block bullet | The long DNF 4/5 symlink explanation, replaced by: *(reasoning: [`docs/build-stages.md`](docs/build-stages.md))* |

Also update the stale-template blockquote near the top: it may now point readers at `docs/` rather than only warning that `custom/` guidance is stale.

- [ ] **Step 5: Verify no rule was lost**

```bash
for r in 'dnf5' 'Conventional commits' 'Assisted-by' 'cosign.key' 'surgical' \
         '96-overrides' 'version-script' 'silently does nothing' 'by name'; do
  grep -q -- "$r" CLAUDE.md || echo "RULE LOST: $r"
done
echo "check complete"
```

Expected: no `RULE LOST:` lines.

- [ ] **Step 6: Verify every docs link resolves**

```bash
grep -o 'docs/[a-z-]*\.md' CLAUDE.md | sort -u | while read -r p; do
  test -f "$p" || echo "DANGLING: $p"
done
echo "check complete"
```

Expected: no `DANGLING:` lines.

- [ ] **Step 7: Verify the convention line was replaced**

```bash
grep -q 'neeeded' CLAUDE.md && echo "FAIL: old typo'd bullet still present"
grep -q 'a file in the docs directory' CLAUDE.md && echo "PASS: new convention present"
```

Expected: only the `PASS:` line.

- [ ] **Step 8: Commit**

```bash
git add CLAUDE.md
git commit -m "$(cat <<'EOF'
docs: split CLAUDE.md so rules stay and rationale moves to docs/

CLAUDE.md is auto-loaded into every agent session and docs/ is not, so
every rule stays verbatim and only explanatory prose moves. Adds a
Documentation section indexing docs/, and replaces the per-directory
design-decision convention with one pointing at docs/.

Assisted-by: Claude Opus 5 via Claude Code
EOF
)"
```

---

### Task 9: Remaining stale references

**Files:**
- Modify: `Containerfile` (lines 1–16), `CONTRIBUTING.md`, `README.md`, `.github/copilot-instructions.md`

**Interfaces:**
- Consumes: `docs/README.md`, `docs/ci.md`.

- [ ] **Step 1: Trim the `Containerfile` header block**

Lines 1–16 currently instruct the reader to change `finpilot` to their project name and cite `custom/ujust/README.md`, a path that does not exist. This also contradicts the no-large-comment-blocks convention. Replace the whole block with:

```
###############################################################################
# Sivablue — see docs/ci.md for image identity and docs/build-stages.md for the
# build. Image name is set in build/00-image-info.sh.
###############################################################################
```

Leave the MULTI-STAGE BUILD ARCHITECTURE block that follows it alone — it documents the actual architecture and is accurate.

- [ ] **Step 2: Verify the Containerfile still builds as a valid file**

```bash
grep -n 'finpilot\|custom/ujust' Containerfile || echo "no stale references — clean"
hadolint --config .hadolint.yaml Containerfile 2>/dev/null || echo "hadolint not installed, skipping"
```

Expected: `no stale references — clean`.

- [ ] **Step 3: Rewrite `CONTRIBUTING.md`**

It currently sends contributors to `projectbluefin/common`, which is wrong for this repository. Replace with a short page stating: this repository builds the Sivablue image; read `docs/README.md` first; validate with `just lint`, `just check`, `just format` and `just build`; commits follow Conventional Commits per `.github/commit-convention.md`; AI agents disclose themselves with an `Assisted-by:` footer. Keep it under 25 lines — it is a signpost, not a manual.

- [ ] **Step 4: Add a docs link to the root `README.md`**

In the existing `## Documentation:` section, add one sentence pointing maintainers at `docs/README.md` for build and design documentation. **Change nothing else** — the rest is accurate user-facing content, including the download table.

- [ ] **Step 5: Fix `.github/copilot-instructions.md`**

Change the title `# Copilot Instructions for finpilot` to `# Copilot Instructions for Sivablue`. It remains a pointer to `AGENTS.md`. Optionally add one line noting that build documentation is in `docs/`.

- [ ] **Step 6: Verify no `finpilot` reference survives anywhere**

```bash
grep -rn 'finpilot' . --exclude-dir=.git --exclude-dir=superpowers || echo "no finpilot references — clean"
```

Expected: `no finpilot references — clean`. `docs/superpowers/` is excluded because
the spec and this plan quote "finpilot" while describing the work; those hits are
expected and correct.

- [ ] **Step 7: Commit**

```bash
git add Containerfile CONTRIBUTING.md README.md .github/copilot-instructions.md
git commit -m "$(cat <<'EOF'
docs: remove remaining template references and link to docs/

Trims the Containerfile header block, which told readers to rename the
"finpilot" template and cited a custom/ujust/README.md that does not
exist. Rewrites CONTRIBUTING.md to describe this repository rather than
upstream Bluefin, and corrects the copilot instructions title.

Assisted-by: Claude Opus 5 via Claude Code
EOF
)"
```

---

### Task 10: Final verification

Nothing new is written here. This task proves the whole change is sound.

**Files:** none modified.

- [ ] **Step 1: Confirm no build script was edited**

```bash
git diff --stat faecf6f..HEAD -- build/ Justfile
```

`faecf6f` is the plan commit — the base this work started from. Expected: only
`build/README.md` shown as deleted. Any other `build/` file appearing is a plan
violation — stop and investigate.

- [ ] **Step 2: Confirm every deleted path is unreferenced**

```bash
for p in 'build/README' 'just/README' 'preinstall.d/README' 'fastfetch/README' 'SETUP_CHECKLIST'; do
  echo "── $p"
  grep -rn "$p" . --exclude-dir=.git --exclude-dir=docs || echo "   clean"
done
```

Expected: `clean` under every path. Hits inside `docs/superpowers/` are the spec and this plan describing the work and are expected — that is why `docs` is excluded.

- [ ] **Step 3: Confirm the functional Markdown files are untouched**

```bash
git status --porcelain system/etc/misc.d/hashcat-install.md system/usr/share/sivablue/motd/welcome.md
grep -n 'hashcat-install.md' system/usr/share/sivablue/just/fetch.just
```

Expected: no output from `git status` (both unmodified), and `fetch.just:20` still runs `glow /etc/misc.d/hashcat-install.md`.

- [ ] **Step 4: Confirm every cross-link in `docs/` resolves**

```bash
grep -rho '](\.\{0,2\}/\?[A-Za-z0-9./-]*\.md)' docs/*.md | sed 's/^](//; s/)$//' | sort -u | while read -r p; do
  case "$p" in
    /*) target="${p#/}" ;;
    ./*) target="docs/${p#./}" ;;
    *) target="docs/$p" ;;
  esac
  test -f "$target" || echo "DANGLING: $p -> $target"
done
echo "check complete"
```

Expected: no `DANGLING:` lines.

- [ ] **Step 5: Run the repository's own validation**

```bash
just lint
just check
just format
```

Expected: `lint` reports no new findings — no shell script was edited, so any output should match the pre-change baseline, including the known upstream findings from vendored submodules such as gradia's `build.sh`. `check` and `format` should be clean. If `format` rewrites a file, that is a pre-existing condition, not caused by this change — confirm with `git diff` before committing anything.

- [ ] **Step 6: Full image build**

```bash
just build
```

Expected: a successful build. This is the only thing that proves removing three READMEs from `system/` breaks nothing, since `build/build.sh` mirrors that tree into the image with `cp -rT`. `build/99-tests.sh` runs inside the build and asserts the `.just` recipe files, the fastfetch config and logo, and `default.preinstall` all exist — none of which were touched.

This build takes a long time. If it cannot be run in this environment, say so explicitly and report the change as unverified rather than claiming success.

- [ ] **Step 7: Report**

State plainly which checks ran and their results. If `just build` was not run, say so. Do not describe the work as complete on the strength of the grep checks alone.

---

## Self-Review

**Spec coverage:**

| Spec requirement | Task |
|---|---|
| Ten `docs/` pages | 1–7 |
| `ghcurl` token line, verbatim | 1 (Steps 2, 4) |
| Delete `build/README.md` | 1 |
| Delete fastfetch README, content preserved | 2 |
| Delete flatpak + ujust READMEs | 4 |
| Delete `SETUP_CHECKLIST.md`, split into signing + ci | 6 |
| `CLAUDE.md` rules/rationale split | 8 |
| Convention line replaced verbatim | 8 (Step 2) |
| `Containerfile` header trim | 9 |
| `renovate.yml` repoint | 6 (Step 4) |
| `build.yml:192` repoint | 6 (Step 4) |
| `CONTRIBUTING.md` rewrite | 9 |
| `copilot-instructions.md` name fix | 9 |
| Root `README.md` docs link | 9 |
| Functional `.md` files untouched | 10 (Step 3) |
| Dangling-reference grep | 10 (Step 2) |
| Link resolution | 7 (Step 2), 8 (Step 6), 10 (Step 4) |
| `just lint/check/format/build` | 10 (Steps 5, 6) |
| No automated drift check added | Absent by design |

No gaps.

**Placeholder scan:** every page specification enumerates its required facts with source citations; the two passages where wording matters (`ghcurl`, the convention bullet) are given verbatim. No "TBD", no "add appropriate…", no "similar to Task N".

**Consistency:** page filenames are identical across the file-structure table, every task, `docs/README.md` (Task 7), the `CLAUDE.md` Documentation table (Task 8), and both workflow repoints (Task 6). Task 10 Step 1 uses `master~9`, matching the nine commits produced by Tasks 1–9.
