# Sivablue

A bootc image built on Fedora Silverblue's atomic bootc base (`quay.io/fedora-ostree-desktops/silverblue`).

> `AGENTS.md` is a symlink to this file — one set of instructions for every agent.
>
> This replaced the upstream template's generic guidance, which described a `custom/` layout
> (`custom/brew/`, `custom/flatpaks/`, `custom/ujust/`, `build/10-build.sh`) that does not exist
> here. If you find that advice quoted anywhere, it is stale; `git show 6c5908d` has the original.

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

## Build stages

- `build/build.sh` calls each script **by name** — it does not glob. A new stage must be added there or it silently never runs.
- Numbers set execution order and it is load-bearing. Third-party repo installs must land **before `35-clean.sh`**, which disables those repos by filename.
- Reordering dnf installs can change dependency resolution. When splitting a stage out, keep its original position.
- Stage boilerplate: `#!/usr/bin/bash`, `set -eoux pipefail`, wrapped in `echo "::group:: ===$(basename "$0")==="` / `echo "::endgroup::"`, mode `0755`.
- `build/50-tests.sh` is the build's own gate — add a check there for anything `rpm -q` cannot verify (tarball installs, files staged from `system/`).

## Installing software

- **Fedora packages** — add to `FEDORA_PACKAGES` in `build/10-packages.sh`.
- **Third-party repo** — one stage per vendor (`06-docker.sh`, `07-tailscale.sh`, `08-vscode.sh`). Pattern: add the repo, immediately disable it, then `dnf -y install --enablerepo=<id>` so it never stays enabled at runtime.
- **COPR** — `copr_install_isolated "owner/project" pkg…` after sourcing `copr-helpers.sh`.
- **Flatpak** — add a `[Flatpak Preinstall <id>]` block to `system/usr/share/flatpak/preinstall.d/default.preinstall`. That file must exist in the image or Bazaar is uninstalled from users' systems.
- **Tarball** — install under `/usr/lib/<name>` and symlink into `/usr/bin`. **Not `/opt`**: the Containerfile does `rm /opt && mkdir /opt` to make it immutable. See `build/12-waterfox.sh`.
- `/usr` is read-only at runtime, so bundled self-updaters cannot work — disable them (Firefox-family: a `distribution/policies.json` with `DisableAppUpdate`). Updates arrive via image rebuild + `bootc upgrade`, so "latest" means latest *at build time*.

## GNOME extensions

- Vendored as **git submodules** under `system/usr/share/gnome-shell/extensions/<uuid>/`. CI checks out with `submodules: recursive`.
- Build steps (compiling schemas, running upstream build scripts) go in `build/15-extensions.sh`.
- Enable by adding the UUID to `enabled-extensions` in `system/usr/share/glib-2.0/schemas/zz0-sivablue-mods.gschema.override`.
- Check `metadata.json` `shell-version` covers the base image's GNOME release.

## Settings: two mechanisms, not interchangeable

- `system/usr/share/glib-2.0/schemas/zz0-sivablue-mods.gschema.override` — overrides defaults for schemas installed **in that same directory** (`org.gnome.shell`, `org.gnome.desktop.*`, Ptyxis…).
- `system/etc/dconf/db/distro.d/` — sets values **by path**, so it is the only option for relocatable schemas and for extensions that ship their schema inside their own directory.

An override written in the wrong one silently does nothing.

## Per-user setup

`system/usr/share/sivablue/user-setup.hooks.d/NN-name.sh`, run by `sivablue-user-setup` (a user
service that iterates the directory — no registration needed).

- Start with `source /usr/lib/sivablue/setup-services/libsetup.sh` then `version-script <name> user <n> || exit 0`.
- `version-script` records the version **before** the body runs, so a hook that fails partway is never retried. Make hooks defensive and never destructive — guard against clobbering existing user data.
- Bump `<n>` to make an updated hook re-run for existing users.

## ujust

User-facing commands live in `system/usr/share/sivablue/just/*.just`. `build/50-tests.sh` stats these
files, so renaming one breaks the build.

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
- **Always `dnf5`, never bare `dnf`, `yum` or `rpm-ostree`.** Every invocation in `build/` is `dnf5` and it stays that way. On Fedora 41+ `dnf` is only a symlink to `dnf5`, so writing `dnf` reads as if DNF 4 semantics were intended when they are not — and the scripts already use DNF 5-only syntax (`config-manager addrepo`, `config-manager setopt`) that DNF 4 cannot parse. Being explicit also keeps the scripts honest if the image is ever rebased onto a base where `dnf` really is DNF 4.
- **Never commit `cosign.key`** (it is gitignored; `cosign.pub` is committed deliberately).
- **Do you not add massive comment blocks** - It is not neeeded to big blocks of comments in build files. If you want to explain something, or a design decision, it should be added to a file in each directory with an explanation as to why that decision was made.

### Leave alone unless asked

`.github/renovate.json5`, `.github/workflows/validate-*.yml`, `.gitignore`, `build/copr-helpers.sh`,
`cosign.pub`, `LICENSE`.

Treat with caution: `.github/workflows/build.yml`, `.github/workflows/clean.yml`, `Justfile`
(people rely on those recipe names).
