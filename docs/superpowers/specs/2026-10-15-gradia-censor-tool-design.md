# Gradia Capture censor tool (hard fork)

**Date:** 2026-10-15
**Status:** Approved in conversation, spec awaiting review

## Problem

Sivablue ships the Gradia Capture GNOME extension
(`gradia-integration@alexandervanhee.github.io`, vendored as a submodule of
`AlexanderVanhee/gradia-capture`). It has no way to obscure sensitive regions
other than the opaque Solid Rectangle. The Gradia app has a **Censor** tool that
pixelates a dragged rectangle; the extension does not.

Upstream has the request open (issue #10) with two unreviewed PRs (#20
pixelate brush, #35 blur). We are deliberately **not** using either: the
decision is to write our own tool in a hard fork.

## Goals

- A Censor tool in Gradia Capture that behaves exactly like the Gradia app's.
- Censored output is irreversible: original detail is discarded, not softened,
  and the result is flattened into every output the extension produces.
- What the user sees while editing is what gets saved.
- Sivablue builds the extension from `Sir-Mudkip/gradia-capture`.

## Non-goals

- Upstreaming the tool (hard fork; may be offered later, not designed for).
- A strength slider, colour, or smooth/Gaussian blur.
- Publishing the fork on extensions.gnome.org.

## Reference behaviour (Gradia app)

`CensorAction._draw_pixelation` in `gradia/overlay/drawing_actions.py`
(AlexanderVanhee/Gradia): drag a rectangle; the region is reduced to one
pixel per **8×8 block of image pixels** and scaled back with
`FILTER_NEAREST`; it always samples the original background image, never other
annotations; the tool has no scale and no colour
(`has_scale=False`, `has_primary_color=False`).

## Part 1 — The fork and Sivablue wiring

**Fork:** `https://github.com/Sir-Mudkip/gradia-capture`, cloned to
`~/projects/gradia-capture` with `origin` = fork, `upstream` = AlexanderVanhee.
Base: upstream `master` at `f70a212` (one commit ahead of Sivablue's current pin
`9e44149`).

- Hard fork: fork `master` is the source of truth. Upstream changes are merged
  in deliberately (`git fetch upstream && git merge upstream/master`).
- GPL-3.0 kept; upstream copyright headers kept. README gains a short "Fork of
  AlexanderVanhee/gradia-capture — adds a Censor tool" note at the top.
- **UUID unchanged** (`gradia-integration@alexandervanhee.github.io`), so
  `enabled-extensions` in `zz0-sivablue-mods.gschema.override`, the paths in
  `build/15-extensions.sh`, and users' saved settings keep working.
- `src/metadata.json`: add `"version-name": "sivablue-1"`; `url` points at the
  fork. `shell-version` stays `["49","50"]` (base image is GNOME 50).
- Fork commits use conventional commits and the `Assisted-by:` footer.

**Sivablue changes:**

| File | Change |
|---|---|
| `.gitmodules` | Submodule `url` → `https://github.com/Sir-Mudkip/gradia-capture.git`; path and `branch = master` unchanged. `git submodule sync` + update to the fork's head. |
| `build/15-extensions.sh` | None — the fork keeps upstream's `build.sh`. |
| `build/99-tests.sh` | Assert the installed extension contains the censor tool (`grep -q "id: 'censor'"` on the installed `tools.js`) — guards against the submodule silently reverting to upstream. |
| `docs/extensions.md` | Source table → fork URL; a short section on why it is a fork and how to merge upstream into it. |
| `.github/renovate.json5` | None. `git-submodules` is already enabled (never automerged), so fork pushes arrive as reviewable submodule-bump PRs. |

## Part 2 — The censor tool

**Files (fork):**

- `src/pixelate.js` — new; exports `pixelate()`. Imports only `cairo`, so it
  is testable with plain `gjs` (`tools.js` imports Clutter, which plain gjs
  cannot load). `build.sh` already packs every `src/*.js`.
- `src/tools.js` — new `censor` entry in `TOOLS`, placed directly after
  `solid-rectangle`.
- `icons/checkerboard-big-symbolic.svg` — the icon Gradia uses for Censor
  (GNOME icon development kit, CC0).
- `src/extension.js` — supplies source pixels to `render()` in preview and
  export; snapshot lifecycle; disables colour/width controls for censor.

**Tool definition:**

- `id: 'censor'`, `name: 'Censor'`, `isDrawing: true`.
- Keybindings `Clutter.KEY_0`, `Clutter.KEY_agrave` (AZERTY 0, matching the
  existing per-tool pattern), `Clutter.KEY_x`. GNOME's screenshot UI already
  uses `c`/`s`/`w`/`p`/`v`; existing tools use 1–9 and `q d f r b h a t n`.
- `beginStroke`, `bounds`, `hitTest` identical to Solid Rectangle, so the Drag
  tool can select, move and delete censor regions.
- Colour and line-width controls insensitive while censor is active, via the
  mechanism `_updateDrawingControlsSensitivity` already uses.

**`pixelate(cr, source, srcRect, dstRect, blockPx = 8)`:**

- `source`: a Cairo surface of original pixels. `srcRect` in source pixels,
  `dstRect` in `cr` user space.
- `blocksX = max(1, floor(srcW / blockPx))`, `blocksY` likewise.
- Paint `srcRect` of `source` scaled into a `blocksX × blocksY` ARGB32
  surface; paint that back over `dstRect` with `FILTER_NEAREST`, clipped to
  `dstRect`.
- The block grid is anchored at the rectangle's own origin, so preview and
  export produce the same blocks.
- Zero or negative `srcRect`/`dstRect` size draws nothing.

**Source pixels to `render()`:** the stroke object passed to `render` gains
`source` (Cairo surface) and `sourcePoints` (the stroke's points in that
surface's pixel space). Other tools ignore them.

- **Export** (`_compositeStrokesOntoPixbuf`): `source` is a surface created
  once from the incoming, unannotated `pixbuf`, before any stroke is drawn;
  `sourcePoints` are the image-space points already computed there. Censor
  therefore samples original pixels only.
- **Preview** (`DrawingCanvas.vfunc_repaint`): `source` is a snapshot of
  `Main.screenshotUI._stageScreenshot` (frozen full stage, physical pixels),
  obtained via `Shell.Screenshot.composite_to_stream` — the call the extension
  already uses. `sourcePoints = stagePoints × ui._scale`.
- Snapshot taken lazily when the censor tool is first selected in a screenshot
  session, cached, and released when the screenshot UI closes. Until it is
  ready, a censor stroke renders as a hatched placeholder; drawing never
  blocks.

**Every output path must carry the censored pixels.** Save to disk, copy to
clipboard, "Save as", and hand-off to the Gradia app must all go through the
composited result. Implementation traces each path and fixes any that bypass
`_compositeStrokesOntoPixbuf`.

**Known limitation:** in window-capture mode the preview samples the on-screen
stage while export uses the window's own texture; with an overlapping window
the pixels under the blocks can differ between preview and export. Export is
still correctly pixelated.

## Part 3 — Testing and verification

**Unit tests (TDD, written first):** `tests/pixelate.test.js` in the fork, run
with `gjs -m tests/pixelate.test.js`; outside `src/`, so never packed.

1. Detail destroyed: random-noise source; every 8×8 block inside the
   rectangle is a single colour.
2. Outside untouched: pixels outside `dstRect` are byte-identical.
3. Grid anchoring: a rectangle at an odd origin (e.g. x=13) has blocks starting
   at its own corner.
4. Edges: a rectangle smaller than 8 px becomes one block; partial edge blocks
   are pixelated; zero/negative size draws nothing.
5. Source independence: drawing onto the target before pixelating does not
   change the result.

**Live verification (needs a GNOME session, done by the user):** install the
fork with `./build.sh -i` to `~/.local/share/gnome-shell/extensions/`, which
takes precedence over the system copy with the same UUID; log out and in; walk
a checklist — area, screen, window modes; preview matches saved PNG; clipboard
paste; "Save as"; Gradia hand-off; move/delete a censor box; annotations drawn
after it stay sharp. Remove the `~/.local` copy afterwards.

**Sivablue:** `just lint`, `just check`, full `just build` (runs the fork's
`build.sh` and the new `99-tests.sh` check), CI after push, then clean up the
buildah cache and images.

## Order of work

1. Fork: `pixelate.js` + tests (TDD) → censor tool → source plumbing → output
   path audit → live verification → push to fork `master`.
2. Sivablue: `.gitmodules` + submodule bump → `99-tests.sh` →
   `docs/extensions.md` → `just build` → commit and push.
