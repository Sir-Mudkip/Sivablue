# Sivablue

A bootc image built on Fedora Silverblue's atomic bootc base (`quay.io/fedora-ostree-desktops/silverblue`).

> `AGENTS.md` is a symlink to this file — one set of instructions for every agent.
>
> This replaced the upstream template's generic guidance, which described a `custom/` layout
> (`custom/brew/`, `custom/flatpaks/`, `custom/ujust/`, `build/10-build.sh`) that does not exist
> here. If you find that advice quoted anywhere, it is stale; `git show 6c5908d` has the original.
>
> Rules live in this file; the reasoning behind them lives in [`docs/`](docs/README.md).

## Layout

| Path | Purpose |
|---|---|
| `build/NN-name.sh` | Numbered build stages, run inside the image build |
| `build/build.sh` | Explicitly calls each stage in order |
| `build/copr-helpers.sh` | `copr_install_isolated` helper |
| `build/ghcurl` | `curl` wrapper that picks up `GITHUB_TOKEN` from `/run/secrets` |
| `system/` | Mirrored into the image verbatim (`cp -rT` in `build.sh`) — `system/usr/…` → `/usr/…` |

Anything static goes in `system/`; anything that needs to run (downloads, compiles, package installs)
goes in a `build/` stage.

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

## Build stages

- `build/build.sh` calls each script **by name** — it does not glob. A new stage must be added there or it silently never runs.
- Numbers set execution order and it is load-bearing. Third-party repo installs must land **before `96-overrides.sh`**, which disables those repos by filename.
- Reordering dnf installs can change dependency resolution. When splitting a stage out, keep its original position.
- Stage boilerplate: `#!/usr/bin/bash`, `set -eoux pipefail`, wrapped in `echo "::group:: ===$(basename "$0")==="` / `echo "::endgroup::"`, mode `0755`.
- `build/99-tests.sh` is the build's own gate — add a check there for anything `rpm -q` cannot verify (tarball installs, files staged from `system/`).

Full stage-by-stage detail: [`docs/build-stages.md`](docs/build-stages.md).

## Installing software

- **Fedora packages** — add to `FEDORA_PACKAGES` in `build/10-packages.sh`.
- **Third-party repo** — one stage per vendor (`06-docker.sh`, `07-tailscale.sh`, `08-vscode.sh`). Pattern: add the repo, immediately disable it, then `dnf -y install --enablerepo=<id>` so it never stays enabled at runtime.
- **COPR** — `copr_install_isolated "owner/project" pkg…` after sourcing `copr-helpers.sh`.
- **Flatpak** — add a `[Flatpak Preinstall <id>]` block to `system/usr/share/flatpak/preinstall.d/default.preinstall`. That file must exist in the image or Bazaar is uninstalled from users' systems.
- **Tarball** — install under `/usr/lib/<name>` and symlink into `/usr/bin`. **Not `/opt`**. See `build/12-waterfox.sh`.
- `/usr` is read-only at runtime, so bundled self-updaters cannot work — disable them. Updates arrive via image rebuild + `bootc upgrade`, so "latest" means latest *at build time*.

Where files go in the image and why: [`docs/filesystem-layout.md`](docs/filesystem-layout.md).

## GNOME extensions

- Vendored as **git submodules** under `system/usr/share/gnome-shell/extensions/<uuid>/`. CI checks out with `submodules: recursive`.
- Build steps (compiling schemas, running upstream build scripts) go in `build/15-extensions.sh`.
- Enable by adding the UUID to `enabled-extensions` in `system/usr/share/glib-2.0/schemas/zz0-sivablue-mods.gschema.override`.
- Check `metadata.json` `shell-version` covers the base image's GNOME release.

Vendoring, building and updating an extension: [`docs/extensions.md`](docs/extensions.md).

## Settings: two mechanisms, not interchangeable

- `system/usr/share/glib-2.0/schemas/zz0-sivablue-mods.gschema.override` — overrides defaults for schemas installed **in that same directory** (`org.gnome.shell`, `org.gnome.desktop.*`, Ptyxis…).
- `system/etc/dconf/db/distro.d/` — sets values **by path**, so it is the only option for relocatable schemas and for extensions that ship their schema inside their own directory.

An override written in the wrong one silently does nothing.

Which mechanism a given schema requires: [`docs/settings.md`](docs/settings.md).

## Per-user setup

`system/usr/share/sivablue/user-setup.hooks.d/NN-name.sh`, run by `sivablue-user-setup` (a user
service that iterates the directory — no registration needed).

- Start with `source /usr/lib/sivablue/setup-services/libsetup.sh` then `version-script <name> user <n> || exit 0`.
- `version-script` records the version **before** the body runs, so a hook that fails partway is never retried. Make hooks defensive and never destructive — guard against clobbering existing user data.
- Bump `<n>` to make an updated hook re-run for existing users.

Writing and versioning a hook: [`docs/user-setup.md`](docs/user-setup.md).

## ujust

User-facing commands live in `system/usr/share/sivablue/just/*.just`. `build/99-tests.sh` stats these
files, so renaming one breaks the build.

Writing a new recipe: [`docs/ujust.md`](docs/ujust.md).

## Validation

```bash
just lint      # shellcheck across all *.sh
just check     # just/Justfile syntax
just format    # shfmt
just build     # full image build
```

- `just lint` recurses into vendored submodules and reports on upstream code (e.g. gradia's `build.sh`) — those failures are not yours.
- The `build-qcow2` / `build-iso` / `run-vm-*` recipes reference an `iso/` directory that does not exist in this repo; they will fail until it is added.
- Only a full `just build` proves a build stage works. Linting a script is not the same as running it.

## Conventions

- **Conventional commits**, enforced for commits and PR titles: `<type>[scope]: <description>`, types `feat: fix: docs: chore: build: ci: refactor: test:`. See `.github/commit-convention.md`.
- AI agents disclose themselves in a commit footer: `Assisted-by: [Model] via [Tool]`.
- Be surgical — the project optimises for being easy to maintain, so prefer the smallest change that works.
- **Always `dnf5`, never bare `dnf`, `yum` or `rpm-ostree`.** Every invocation in `build/` is `dnf5` and it stays that way (reasoning: [`docs/build-stages.md`](docs/build-stages.md)).
- **Never commit `cosign.key`** (it is gitignored; `cosign.pub` is committed deliberately).
- **Do not add massive comment blocks to build files** — If you want to explain something, such as a design decision, it should be added to a file in the docs directory with an explanation as to why that decision was made. Per design change, this file should be updated. Each file should have an explanation of what each part of the build is doing e.g. what each build file is doing, why things are in `/usr/lib`, etc.

### Leave alone unless asked

`.github/renovate.json5`, `.github/workflows/validate-*.yml`, `.gitignore`, `build/copr-helpers.sh`,
`cosign.pub`, `LICENSE`.

Treat with caution: `.github/workflows/build.yml`, `.github/workflows/clean.yml`, `Justfile`
(people rely on those recipe names).
