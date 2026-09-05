# Containerfile Cache Boundary Split — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop an edit to `system/` from invalidating the package-install and
source-build layers, so a settings or wallpaper change no longer recompiles
Ghostty. Item 15 in [`docs/bluefin-comparison.md`](../../bluefin-comparison.md).

**Why now:** Verifying items 7-13 in the 2026-09-05 session took five full
rebuilds, each recompiling Ghostty from source, to validate changes that were
mostly one line of shell. The current single `RUN` means any change to any file
under `build/` or `system/` rebuilds everything. Bluefin reports 20-80 minutes
saved per config-only build after making this split.

**Tech Stack:** Containerfile (buildah/podman), bash, `just` recipes.

## Background: why a single context is the problem

`Containerfile` currently has one context stage:

```
FROM scratch AS ctx
COPY build /build
COPY system /system
```

and one `RUN` that bind-mounts it and calls `build/build.sh`, which runs all
eighteen stages in order.

Buildah folds the **mounted stage's image ID** into the `RUN` cache key. Because
`ctx` contains both `build/` and `system/`, editing any file in either changes
that image ID, which invalidates the single `RUN`, which re-runs every stage.
There is no partial reuse: changing a wallpaper recompiles Ghostty.

Bluefin's `Containerfile` documents this explicitly and splits into four scratch
contexts, each carrying only what its consumer reads. Read
`../bluefin/Containerfile` before starting — the comments there are the clearest
statement of the mechanism, and this plan follows the same approach adapted to
Sivablue's stage list.

## Design

Three phases, split across two build stages plus the existing lint step.

**Phase 1 — package and source installs.** Mounts a context containing only
`build/`. Runs the stages that install packages or compile software:
`05-kernel-akmods.sh`, `06-docker.sh`, `07-tailscale.sh`, `08-vscode.sh`,
`10-packages.sh`, `11-ghostty.sh`, `12-waterfox.sh`, `13-eddie.sh`.

**Phase 2 — overlay and finalise.** Mounts a context containing `system/` plus
only the stages that run after the overlay: `00-image-info.sh`,
`15-extensions.sh`, `20-content-cleanup.sh`, `25-sysconfig.sh`,
`30-initramfs.sh`, `96-overrides.sh`, `97-validate-repos.sh`,
`98-clean-stage.sh`, `99-tests.sh`.

The `system/` mirror moves from the top of `build.sh` into the start of phase 2.
**This also fixes the ordering hazard in §2.2 of the comparison** — packages can
no longer overwrite a file staged from `system/`, because the overlay now happens
after the installs rather than before.

### Ordering constraints that must not break

- `96-overrides.sh` disables third-party repos by filename, so every stage that
  adds a repo must stay before it. All of those are in phase 1; `96` is in
  phase 2. Safe.
- `30-initramfs.sh` must run after every kernel-affecting stage. `05-kernel-akmods.sh`
  is phase 1, `30` is phase 2. Safe.
- `20-content-cleanup.sh` prunes orphan `/usr/lib/modules/` trees and must stay
  before `30-initramfs.sh`. Both phase 2, order preserved.
- `00-image-info.sh` currently runs first. It only writes `/usr/share/sivablue/image-info.json`
  and rewrites `/usr/lib/os-release`, neither of which any phase 1 stage reads.
  Moving it to phase 2 is safe **but must be verified**, not assumed.
- `96-overrides.sh` edits `/etc/uupd/config.json`, which the uupd package
  provides, so it must stay after `10-packages.sh`. Phase 1 then phase 2. Safe.

### What must not regress

`build/build.sh` gained `set -eo pipefail` and an `ERR` trap in the 2026-09-05
session. Both phases must keep that behaviour — a stage failing in phase 1 must
fail the build. If `build.sh` is split into two scripts, each needs the trap.

## Tasks

- [ ] **1. Record a baseline.** Run `just build` twice from a clean cache and time
      both. Record cold and warm times in the PR description. Without this there
      is no evidence the change worked.
- [ ] **2. Read `../bluefin/Containerfile`** and note how `ctx-build` vs `ctx`
      are constructed and why the comments say a combined context defeats caching.
- [ ] **3. Split `build/build.sh`** into `build/build-packages.sh` (phase 1) and
      `build/build-overlay.sh` (phase 2), each with `set -eo pipefail` and the
      `ERR` trap. Move the `cp -rT` mirror into `build-overlay.sh`. Keep calling
      stages **by name** — do not introduce globbing (see `CLAUDE.md`).
- [ ] **4. Add the context stages** to `Containerfile`: `ctx-build` carrying
      `build/`, and `ctx` carrying `system/` plus the phase 2 stage scripts and
      `copr-helpers.sh`/`ghcurl` if those are read. A stage added to phase 2 must
      be added to the context too, or the build fails loudly — say so in a comment.
- [ ] **5. Split the `RUN`** into two, each mounting only its own context, and
      preserving the existing cache and tmpfs mounts (`/var/cache`, `/var/log`,
      `/tmp`) plus the `GITHUB_TOKEN` secret where needed. `11-ghostty.sh` and
      `13-eddie.sh` use `ghcurl`, so phase 1 needs the secret.
- [ ] **6. Verify ordering** by reading the full build log: every stage runs
      exactly once, in the same relative order as before.
- [ ] **7. Prove the cache boundary works.** Build once, then touch a file under
      `system/` (a wallpaper is ideal) and build again. Phase 1 must report
      `Using cache`; Ghostty must not recompile. Record the time.
- [ ] **8. Prove the inverse.** Touch `build/10-packages.sh` and confirm phase 1
      **does** rebuild — a cache boundary that never invalidates is worse than none.
- [ ] **9. Confirm `99-tests.sh` still passes** and `bootc container lint
      --fatal-warnings` still reports 13 checks passed.
- [ ] **10. Update the docs** in the same commit: `docs/build-stages.md` (the
      phase split and which stage belongs where), `CLAUDE.md` (the "must be added
      to `build.sh`" rule becomes "must be added to the right phase *and* its
      context"), and mark item 15 done in `docs/bluefin-comparison.md`.
- [ ] **11. Clean up** every image and layer the builds produced, per `CLAUDE.md`.

## Risks

- **Cache boundaries are invisible when wrong.** A stage that silently stops
  running still produces an image. Task 6 exists specifically to catch that;
  do not skip it because the build went green.
- **A context missing a file fails late**, deep in a 30-minute build. Check the
  context `COPY` list against the stage list before building.
- **`00-image-info.sh` moving phases** is the one genuine behaviour change.
  Verify `/usr/lib/os-release` and `image-info.json` are correct in the built
  image, not merely that the build passed.
- **Iteration is expensive** until the split works — each failed attempt is a
  full rebuild. Read twice, build once.

## Verification

```bash
just lint && just check      # must pass
just build                   # cold: full run, 13 lint checks, 99-tests to completion
touch system/usr/share/backgrounds/sivablue/siva-red.jpg
just build                   # warm: phase 1 cached, no Ghostty recompile
```

The change has succeeded when the second build skips the package layer and
finishes in a small fraction of the first. If both builds take the same time,
the split did not work regardless of what the log says.
