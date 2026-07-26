# Documentation reorganisation

**Date:** 2026-07-26
**Status:** Approved, not yet implemented

## Problem

Documentation about how Sivablue is built is scattered across seven locations, and
most of it is wrong. Roughly 400 of the repository's ~880 documentation lines
describe the upstream template layout — `custom/ujust/`, `custom/brew/`,
`build/10-build.sh`, "modify the Containerfile to run each script" — none of which
exists here. `CLAUDE.md` already disowns that guidance but the files themselves
were never removed.

Three of the stale files live under `system/`, which `build/build.sh` mirrors into
the image with `cp -rT`. They therefore ship to every installed machine. The ujust
README alone puts 241 lines of instructions for a non-existent directory layout
onto users' systems at `/usr/share/sivablue/just/README.md`.

Meanwhile the things a maintainer most needs — what each of the 17 build stages
does, why stage ordering is load-bearing, why tarballs go to `/usr/lib` rather than
`/opt` — are written down nowhere. They exist only in the scripts.

## Goals

- One home for build and design documentation: `docs/`.
- Every build stage explained, in execution order.
- Filesystem placement decisions recorded with their rationale.
- Stale template documentation deleted, not relocated.
- Wrong instructions stop shipping in the image.

## Non-goals

- End-user documentation. `docs/` serves maintainers only; the root `README.md`,
  the MOTD and `ujust` remain the user-facing surface.
- A documentation site or publishing pipeline.
- Any change to build behaviour. No build script is edited; the only change under
  `build/` is the deletion of its stale `README.md`.
- Any change to the functional Markdown files (see "Untouched" below).
- Automated drift checking between `docs/` and `build/`.

## Decisions

### `CLAUDE.md` keeps the rules; `docs/` gets the rationale

`CLAUDE.md` is loaded automatically into every agent session; `docs/` is not. Rules
that move out of `CLAUDE.md` stop being enforced by default. Every rule therefore
stays in `CLAUDE.md` verbatim, and only explanatory prose moves. `CLAUDE.md` gains
a Documentation section pointing at the `docs/` pages so an agent knows where to
read and where to write.

### Stale documentation is deleted, not rewritten

The stale files are largely upstream boilerplate about generic `just` and `flatpak`
usage, which their own upstream manuals cover better. Replacing them with short,
accurate pages about what this repository actually does is a net reduction in
volume and matches the project's preference for surgical change.

### A single ordered stage reference, plus topic pages

Stage ordering is load-bearing: third-party repository installs must land before
`96-overrides.sh`, which disables those repositories by filename, and reordering
dnf installs can change dependency resolution. A single ordered document keeps that
ordering visible on one screen; one file per stage would hide it. Cross-cutting
decisions such as "why `/usr/lib` and not `/opt`" span several stages plus the
`Containerfile` and have no natural single-stage home, so they get topic pages.

### No automated drift check

The revised `CLAUDE.md` convention mandates updating `docs/` per design change.
Adding a CI or `99-tests.sh` assertion was considered and rejected as more
machinery than the project warrants.

## The `docs/` tree

| Page | Contents | Sourced from |
|---|---|---|
| `README.md` | Index, and the rule for which page to update for a given change | new |
| `build-stages.md` | The `cp -rT` mirror step, then all 17 stages in execution order: what each does and why it sits at that number. The two ordering constraints. Stage boilerplate. The `dnf5` reasoning. The `ghcurl` token line below. | `build/*.sh`, `CLAUDE.md` |
| `filesystem-layout.md` | `system/` to image mirroring; `/usr` read-only at runtime so bundled self-updaters must be disabled; `/usr/lib` not `/opt` because the `Containerfile` does `rm /opt && mkdir /opt`; `/etc` versus `/usr/share`; static assets, including the fastfetch logo rationale and its regeneration recipe | `CLAUDE.md`, `system/usr/share/fastfetch/README.md` |
| `settings.md` | `gschema.override` versus `dconf/db/distro.d`: why relocatable schemas force the latter, and why choosing wrong fails silently | `CLAUDE.md` |
| `extensions.md` | Submodules, recursive CI checkout, `15-extensions.sh` build steps, `enabled-extensions`, the `shell-version` check | `CLAUDE.md` |
| `flatpaks.md` | `preinstall.d` format; `default.preinstall` must exist or Bazaar is uninstalled from users' systems; first-boot download timing | `CLAUDE.md`, `system/usr/share/flatpak/preinstall.d/README.md` |
| `ujust.md` | How ujust works in this repository; `99-tests.sh` stats the `.just` files, so renaming one breaks the build | `CLAUDE.md`, `system/usr/share/sivablue/just/README.md` |
| `user-setup.md` | Hook directory, `libsetup.sh`, `version-script` recording the version before the body runs so failures never retry, bumping `<n>` | `CLAUDE.md` |
| `signing.md` | cosign enforcement via `policy.json`, key setup, rotation, verification, residual risk | `.github/SETUP_CHECKLIST.md` |
| `ci.md` | Workflows, repository secrets (`SIGNING_SECRET`, Renovate token), Actions permissions, image identity | `.github/SETUP_CHECKLIST.md`, `Containerfile` header |

### Required line in `build-stages.md`

`build-stages.md` must state the permissions `ghcurl` needs, to the following
effect:

> `ghcurl` requires no token scopes. Its two callers, `12-waterfox.sh` and
> `13-eddie.sh`, read release metadata from public repositories, so a token only
> lifts the GitHub API rate limit from 60 requests per hour per IP to 5,000. CI's
> automatic `secrets.GITHUB_TOKEN` (`contents: read`, `build.yml:21`) is
> sufficient; locally, any scopeless classic PAT exported as `GITHUB_TOKEN` is
> forwarded as a podman secret by `Justfile:143-145`. Without a token the build
> still works but can fail on HTTP 403, and both stages deliberately hard-fail
> rather than ship a stale version.

This matters because nothing in the repository currently records that the token is
rate-limit-only. A maintainer hitting a 403 would reasonably assume a missing scope
and mint an over-privileged PAT.

## File changes

### Deleted

| File | Note |
|---|---|
| `build/README.md` | Describes `10-build.sh` and `.example` scripts that do not exist |
| `system/usr/share/sivablue/just/README.md` | 241 stale lines; also stops shipping to the image |
| `system/usr/share/flatpak/preinstall.d/README.md` | Wrong install path; also stops shipping to the image |
| `system/usr/share/fastfetch/README.md` | Accurate; content moves to `filesystem-layout.md`; stops shipping to the image |
| `.github/SETUP_CHECKLIST.md` | Split into `docs/signing.md` and `docs/ci.md` |

`build/99-tests.sh` stats the `.just` recipe files but not the READMEs, so removing
them cannot fail the build's own gate.

### Edited

| File | Change |
|---|---|
| `CLAUDE.md` | Rules/rationale split; new Documentation section; convention line replaced (below) |
| `Containerfile` lines 1–16 | The "change `finpilot` to your desired project name" block references `custom/ujust/README.md` and contradicts the no-large-comment-blocks convention. Trimmed to a one-line name declaration; identity notes move to `docs/ci.md` |
| `.github/workflows/renovate.yml` line 36 | `echo` message repointed from `.github/SETUP_CHECKLIST.md` to `docs/ci.md` |
| `.github/workflows/build.yml` line 192 | Comment repointed from `README.md "Optional: Enable Image Signing"`, a section that does not exist, to `docs/signing.md` |
| `CONTRIBUTING.md` | Rewritten to describe this repository rather than sending contributors to `projectbluefin/common`; links into `docs/` |
| `.github/copilot-instructions.md` | `finpilot` corrected to Sivablue; remains a pointer to `AGENTS.md` |
| `README.md` | Documentation section gains a link to `docs/`; otherwise untouched |

Both workflow edits are single-line strings inside a comment and an `echo`. No
step, logic or permission is changed.

### Untouched

`system/etc/misc.d/hashcat-install.md` is rendered at runtime by `glow` from
`system/usr/share/sivablue/just/fetch.just:20`. `system/usr/share/sivablue/motd/welcome.md`
is the MOTD body, rendered by `sivablue-motd` via `system/etc/profile.d/welcome.sh`.
Both are functional content, not documentation, and stay where they are.

`.github/renovate.json5`, `.github/workflows/validate-*.yml`, `.gitignore`,
`build/copr-helpers.sh`, `cosign.pub` and `LICENSE` are out of scope.

## The replaced `CLAUDE.md` convention

The existing bullet:

> **Do you not add massive comment blocks** - It is not neeeded to big blocks of
> comments in build files. If you want to explain something, or a design decision,
> it should be added to a file in each directory with an explanation as to why that
> decision was made.

becomes:

> **Do not add massive comment blocks to build files** — If you want to explain
> something, such as a design decision, it should be added to a file in the docs
> directory with an explanation as to why that decision was made. Per design
> change, this file should be updated. Each file should have an explanation of what
> each part of the build is doing e.g. what each build file is doing, why things
> are in `/usr/lib`, etc.

This replaces the per-directory convention. `docs/` becomes the only home for
design rationale, which is also why no explanatory README remains under `system/`.

## Verification

```bash
just lint      # shellcheck; expect no new findings, no .sh is touched
just check     # Justfile syntax
just format    # shfmt
just build     # proves removing three READMEs from system/ breaks nothing
```

Two checks specific to this work:

1. `grep -rn` for each deleted path across `build/`, `system/`, `Justfile`,
   `Containerfile` and `.github/` must return nothing.
2. Every `docs/` cross-link and every new `CLAUDE.md` pointer must resolve to a
   file that exists.

## Risks

| Risk | Mitigation |
|---|---|
| Removing READMEs from `system/` changes shipped image contents | Nothing reads them; the two functional Markdown files are explicitly untouched |
| A shorter `CLAUDE.md` costs agents inline rationale | Every rule stays verbatim; explicit `docs/` pointers are added |
| `build-stages.md` is newly written and could misdescribe intent | Written by reading each of the 17 scripts and cross-checked against `build.sh` ordering |
| Workflow edits | Single-line strings only, in a comment and an `echo` |
| `docs/` drifts as stages are added | Accepted. The revised convention mandates updates; no automated check by decision |
