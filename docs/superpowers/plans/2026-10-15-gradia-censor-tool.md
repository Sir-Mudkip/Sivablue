# Gradia Capture Censor Tool Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Gradia-style Censor (pixelate) tool to a hard fork of Gradia Capture, and build Sivablue's copy of the extension from that fork.

**Architecture:** A pure-Cairo `pixelate()` helper (`src/pixelate.js`) ports Gradia's `CensorAction._draw_pixelation`. A new `censor` entry in `TOOLS` renders through it whenever the stroke carries `source`/`sourcePoints`, and paints an opaque placeholder otherwise. `extension.js` supplies those fields: from the untouched capture pixbuf when saving, and from a lazily taken snapshot of the frozen stage screenshot in the live preview.

**Tech Stack:** GJS (ES modules), Cairo, GNOME Shell 49/50 extension APIs, GdkPixbuf (tests only), bash, git submodules.

**Spec:** `docs/superpowers/specs/2026-10-15-gradia-censor-tool-design.md`

## Global Constraints

- Fork: `https://github.com/Sir-Mudkip/gradia-capture`, local clone `~/projects/gradia-capture`, remotes `origin` = fork, `upstream` = `AlexanderVanhee/gradia-capture`. Base: upstream `master` `f70a212`.
- Hard fork: work lands on fork `master` directly.
- UUID stays `gradia-integration@alexandervanhee.github.io`. `shell-version` stays `["49","50"]`.
- Licence GPL-3.0; upstream copyright headers untouched.
- Block size: **8 source-image pixels**. `FILTER_NEAREST` upscale. No colour, no width (`hasStyle: false`).
- Keybindings: `Clutter.KEY_0`, `Clutter.KEY_agrave`, `Clutter.KEY_x`.
- Censor samples **original** pixels only, never other annotations.
- A censor stroke rendered without a source paints an **opaque** box — never nothing.
- Commits: conventional commits; footer `Assisted-by: Claude Opus 5.5 via Claude Code` and `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Sivablue rules from `CLAUDE.md` apply to Task 5: `just lint`, `just check`, full `just build`, clean up buildah cache and images afterwards.
- Do not edit `.github/renovate.json5` (already tracks submodules).

## Review Focus

1. **Off-image rectangles** — a censor box dragged past the image edge must clamp to the image, pixelate the in-bounds part, and not throw. → unit test in Task 1 ("rectangle past the image edge is clamped").
2. **HiDPI / fractional scaling** — on a scaled display the live preview blocks must match the saved PNG's blocks. → live checklist item L3 in Task 4.
3. **Closing the UI while the snapshot is still pending** — no crash, and the next screenshot session must not reuse the previous session's snapshot. → live checklist item L7 in Task 4.
4. **Moving a censor box with Drag** — it must re-sample the *original* pixels at its new position, not carry the old pixelated pixels with it. → live checklist item L5 in Task 4.
5. **Censor drawn, then switching to window mode** — upstream applies no annotations in window mode, so the capture is unredacted; the user must see that, not be surprised by it. → live checklist item L8 in Task 4.

---

## File Structure

Fork (`~/projects/gradia-capture`):

| File | Responsibility |
|---|---|
| `src/pixelate.js` (new) | `pixelate()` + `CENSOR_BLOCK_PX`. Pure Cairo, no shell imports. |
| `src/tools.js` (modify) | `censor` tool entry, `rectFromPoints`, opaque placeholder. |
| `src/topBar.js` (modify) | Respect `hasStyle: false` when enabling colour/width controls. |
| `src/extension.js` (modify) | `surfaceFromPixbuf`, export source plumbing, preview snapshot lifecycle. |
| `src/metadata.json` (modify) | `version-name`, `url` → fork. |
| `icons/checkerboard-big-symbolic.svg` (new) | Tool icon (from Gradia, CC0 GNOME icon kit). |
| `README.md` (modify) | Fork note. |
| `tests/helpers.js`, `tests/pixelate.test.js`, `tests/tools.test.js`, `tests/run.sh` (new) | Plain-gjs unit tests; not packed by `build.sh`. |

Sivablue:

| File | Responsibility |
|---|---|
| `.gitmodules` | Submodule URL → fork. |
| submodule pointer | Bumped to fork `master`. |
| `build/99-tests.sh` | Assert installed extension contains the censor tool. |
| `docs/extensions.md` | Fork source + how to merge upstream. |

---

### Task 1: `pixelate()` helper with tests

**Files:**
- Create: `~/projects/gradia-capture/tests/helpers.js`
- Create: `~/projects/gradia-capture/tests/run.sh`
- Create: `~/projects/gradia-capture/tests/pixelate.test.js`
- Create: `~/projects/gradia-capture/src/pixelate.js`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `export const CENSOR_BLOCK_PX = 8`
  - `export function pixelate(cr, source, srcRect, dstRect, blockPx = CENSOR_BLOCK_PX)` — `cr`: `Cairo.Context`; `source`: `Cairo.ImageSurface`; rects: `{ x, y, width, height }` (numbers, may be fractional). Returns `undefined`. Draws nothing for non-positive sizes or a `srcRect` entirely outside `source`.
  - `tests/helpers.js`: `test(name, fn)`, `assert(cond, msg)`, `finish()`, `noiseSurface(w, h, seed?)`, `blankSurface(w, h)`, `copySurface(surface)`, `readPixels(surface)` → `{ width, height, at(x, y) → 'r,g,b,a' }`, `uniqueColours(px, rect)` → `Set`.

- [ ] **Step 1: Write the test helpers**

`tests/helpers.js`:

```js
import Cairo from 'gi://cairo';
import GdkPixbuf from 'gi://GdkPixbuf';
import GLib from 'gi://GLib';
import System from 'system';

let failures = 0;

export function test(name, fn) {
    try {
        fn();
        print(`ok   ${name}`);
    } catch (e) {
        failures++;
        print(`FAIL ${name}\n     ${e.message}`);
    }
}

export function assert(cond, msg) {
    if (!cond)
        throw new Error(msg);
}

export function finish() {
    if (failures > 0) {
        print(`${failures} test(s) failed`);
        System.exit(1);
    }
    print('all passed');
}

// Deterministic per-pixel noise (Park-Miller LCG) so every block of the
// original holds distinct detail that pixelation must destroy.
export function noiseSurface(w, h, seed = 1) {
    const s = new Cairo.ImageSurface(Cairo.Format.ARGB32, w, h);
    const cr = new Cairo.Context(s);
    let x = seed;
    const rnd = () => (x = (x * 16807) % 2147483647) / 2147483647;
    for (let py = 0; py < h; py++) {
        for (let px = 0; px < w; px++) {
            cr.setSourceRGBA(rnd(), rnd(), rnd(), 1);
            cr.rectangle(px, py, 1, 1);
            cr.fill();
        }
    }
    cr.$dispose();
    return s;
}

export function blankSurface(w, h) {
    return new Cairo.ImageSurface(Cairo.Format.ARGB32, w, h);
}

export function copySurface(surface) {
    const s = blankSurface(surface.getWidth(), surface.getHeight());
    const cr = new Cairo.Context(s);
    cr.setSourceSurface(surface, 0, 0);
    cr.paint();
    cr.$dispose();
    return s;
}

// GJS's Cairo bindings expose no pixel accessor, so round-trip through PNG.
export function readPixels(surface) {
    const dir = GLib.dir_make_tmp('gradia-test-XXXXXX');
    const path = GLib.build_filenamev([dir, 'out.png']);
    surface.writeToPNG(path);
    const pb = GdkPixbuf.Pixbuf.new_from_file(path);
    GLib.unlink(path);
    GLib.rmdir(dir);

    const data = pb.read_pixel_bytes().get_data();
    const stride = pb.get_rowstride();
    const n = pb.get_n_channels();
    return {
        width: pb.get_width(),
        height: pb.get_height(),
        at(x, y) {
            const o = y * stride + x * n;
            return Array.from(data.slice(o, o + n)).join(',');
        },
    };
}

export function uniqueColours(px, { x, y, width, height }) {
    const seen = new Set();
    for (let py = y; py < y + height; py++)
        for (let qx = x; qx < x + width; qx++)
            seen.add(px.at(qx, py));
    return seen;
}
```

- [ ] **Step 2: Write the runner**

`tests/run.sh` (mode `0755`):

```bash
#!/usr/bin/env bash
# Runs the unit tests with plain gjs. tools.js imports Clutter, whose typelib
# ships with mutter rather than on the default GI path.
set -euo pipefail
cd "$(dirname "$0")/.."

mutter_dir=$(compgen -G '/usr/lib64/mutter-*' | sort -V | tail -n1 || true)
if [[ -z "${mutter_dir}" ]]; then
    echo "No /usr/lib64/mutter-* typelib directory found" >&2
    exit 1
fi
export GI_TYPELIB_PATH="${mutter_dir}${GI_TYPELIB_PATH:+:${GI_TYPELIB_PATH}}"

status=0
for t in tests/*.test.js; do
    echo "== ${t}"
    gjs -m "${t}" || status=1
done
exit "${status}"
```

Run: `chmod 0755 tests/run.sh`

- [ ] **Step 3: Write the failing tests**

`tests/pixelate.test.js`:

```js
import Cairo from 'gi://cairo';
import { pixelate, CENSOR_BLOCK_PX } from '../src/pixelate.js';
import {
    test, assert, finish, noiseSurface, blankSurface, copySurface, readPixels, uniqueColours,
} from './helpers.js';

// Export case: target starts as a copy of the source, censor drawn in place.
function censorInPlace(source, rect) {
    const target = copySurface(source);
    const cr = new Cairo.Context(target);
    pixelate(cr, source, rect, rect);
    cr.$dispose();
    return target;
}

function assertUniform(px, x0, y0, w, h, label) {
    const first = px.at(x0, y0);
    for (let y = y0; y < y0 + h; y++)
        for (let x = x0; x < x0 + w; x++)
            assert(px.at(x, y) === first, `${label}: (${x},${y}) differs from (${x0},${y0})`);
}

function assertOutsideUnchanged(before, after, rect) {
    for (let y = 0; y < before.height; y++) {
        for (let x = 0; x < before.width; x++) {
            const inside = x >= rect.x && x < rect.x + rect.width &&
                           y >= rect.y && y < rect.y + rect.height;
            if (!inside)
                assert(before.at(x, y) === after.at(x, y), `outside pixel (${x},${y}) changed`);
        }
    }
}

test('block size is 8 image pixels', () => {
    assert(CENSOR_BLOCK_PX === 8, `CENSOR_BLOCK_PX is ${CENSOR_BLOCK_PX}`);
});

test('every block inside the rectangle is a single colour', () => {
    const src = noiseSurface(64, 48);
    const px = readPixels(censorInPlace(src, { x: 8, y: 8, width: 32, height: 24 }));
    for (let by = 0; by < 3; by++)
        for (let bx = 0; bx < 4; bx++)
            assertUniform(px, 8 + bx * 8, 8 + by * 8, 8, 8, `block ${bx},${by}`);
});

test('pixels outside the rectangle are untouched', () => {
    const src = noiseSurface(64, 48);
    const rect = { x: 8, y: 8, width: 32, height: 24 };
    assertOutsideUnchanged(readPixels(src), readPixels(censorInPlace(src, rect)), rect);
});

test('grid is anchored at the rectangle origin', () => {
    const src = noiseSurface(64, 48);
    const px = readPixels(censorInPlace(src, { x: 13, y: 5, width: 24, height: 16 }));
    for (let by = 0; by < 2; by++)
        for (let bx = 0; bx < 3; bx++)
            assertUniform(px, 13 + bx * 8, 5 + by * 8, 8, 8, `block ${bx},${by}`);
});

test('rectangle smaller than a block becomes one block', () => {
    const src = noiseSurface(32, 32);
    const px = readPixels(censorInPlace(src, { x: 10, y: 10, width: 5, height: 3 }));
    assertUniform(px, 10, 10, 5, 3, 'tiny rect');
});

test('partial blocks never yield more colours than blocks', () => {
    const src = noiseSurface(32, 32);
    const rect = { x: 4, y: 4, width: 20, height: 13 };   // floor(20/8)=2, floor(13/8)=1
    const colours = uniqueColours(readPixels(censorInPlace(src, rect)), rect);
    assert(colours.size <= 2, `expected <= 2 colours, got ${colours.size}`);
});

test('zero or negative size draws nothing', () => {
    const src = noiseSurface(32, 32);
    const before = readPixels(src);
    for (const rect of [
        { x: 4, y: 4, width: 0, height: 10 },
        { x: 4, y: 4, width: 10, height: -3 },
    ]) {
        const after = readPixels(censorInPlace(src, rect));
        assertOutsideUnchanged(before, after, { x: 0, y: 0, width: 0, height: 0 });
    }
});

test('reads from the source, not from what is already on the target', () => {
    const src = noiseSurface(32, 32);
    const rect = { x: 0, y: 0, width: 32, height: 32 };
    const expected = readPixels(censorInPlace(src, rect));

    const target = copySurface(src);
    const cr = new Cairo.Context(target);
    cr.setSourceRGBA(1, 0, 0, 1);           // an earlier annotation
    cr.rectangle(0, 0, 32, 32);
    cr.fill();
    pixelate(cr, src, rect, rect);
    cr.$dispose();

    const got = readPixels(target);
    for (let y = 0; y < 32; y++)
        for (let x = 0; x < 32; x++)
            assert(got.at(x, y) === expected.at(x, y), `(${x},${y}) took target pixels`);
});

test('rectangle past the image edge is clamped', () => {
    const src = noiseSurface(32, 32);
    const before = readPixels(src);
    const rect = { x: 20, y: 20, width: 30, height: 30 };   // in-bounds part is 12x12
    const after = readPixels(censorInPlace(src, rect));
    assertUniform(after, 20, 20, 12, 12, 'clamped region');
    assertOutsideUnchanged(before, after, { x: 20, y: 20, width: 12, height: 12 });
});

test('rectangle entirely outside the image draws nothing', () => {
    const src = noiseSurface(32, 32);
    const before = readPixels(src);
    const after = readPixels(censorInPlace(src, { x: 40, y: 40, width: 10, height: 10 }));
    assertOutsideUnchanged(before, after, { x: 0, y: 0, width: 0, height: 0 });
});

test('destination may be scaled relative to source (preview case)', () => {
    const src = noiseSurface(64, 64);
    const target = blankSurface(32, 32);
    const cr = new Cairo.Context(target);
    pixelate(cr, src, { x: 0, y: 0, width: 64, height: 64 }, { x: 0, y: 0, width: 32, height: 32 });
    cr.$dispose();
    const px = readPixels(target);
    for (let by = 0; by < 8; by++)
        for (let bx = 0; bx < 8; bx++)
            assertUniform(px, bx * 4, by * 4, 4, 4, `scaled block ${bx},${by}`);
});

finish();
```

- [ ] **Step 4: Run the tests to verify they fail**

Run: `cd ~/projects/gradia-capture && tests/run.sh`
Expected: FAIL — gjs reports an import error for `../src/pixelate.js` (module not found), non-zero exit.

- [ ] **Step 5: Write the implementation**

`src/pixelate.js`:

```js
import Cairo from 'gi://cairo';

export const CENSOR_BLOCK_PX = 8;

function clampToSource(source, srcRect, dstRect) {
    if (srcRect.width <= 0 || srcRect.height <= 0 || dstRect.width <= 0 || dstRect.height <= 0)
        return null;

    const x0 = Math.max(0, srcRect.x);
    const y0 = Math.max(0, srcRect.y);
    const x1 = Math.min(source.getWidth(), srcRect.x + srcRect.width);
    const y1 = Math.min(source.getHeight(), srcRect.y + srcRect.height);
    if (x1 <= x0 || y1 <= y0)
        return null;

    const kx = dstRect.width / srcRect.width;
    const ky = dstRect.height / srcRect.height;
    return {
        src: { x: x0, y: y0, width: x1 - x0, height: y1 - y0 },
        dst: {
            x: dstRect.x + (x0 - srcRect.x) * kx,
            y: dstRect.y + (y0 - srcRect.y) * ky,
            width: (x1 - x0) * kx,
            height: (y1 - y0) * ky,
        },
    };
}

// Port of Gradia's CensorAction._draw_pixelation: one pixel per block of
// source pixels, scaled back with nearest-neighbour so detail is discarded.
export function pixelate(cr, source, srcRect, dstRect, blockPx = CENSOR_BLOCK_PX) {
    const clamped = clampToSource(source, srcRect, dstRect);
    if (!clamped)
        return;
    const { src, dst } = clamped;

    const blocksX = Math.max(1, Math.floor(src.width / blockPx));
    const blocksY = Math.max(1, Math.floor(src.height / blockPx));

    const tiny = new Cairo.ImageSurface(Cairo.Format.ARGB32, blocksX, blocksY);
    const tcr = new Cairo.Context(tiny);
    tcr.scale(blocksX / src.width, blocksY / src.height);
    tcr.translate(-src.x, -src.y);
    const sourcePattern = new Cairo.SurfacePattern(source);
    sourcePattern.setExtend(Cairo.Extend.PAD);
    tcr.setSource(sourcePattern);
    tcr.paint();
    tcr.$dispose();

    const blocks = new Cairo.SurfacePattern(tiny);
    blocks.setFilter(Cairo.Filter.NEAREST);

    cr.save();
    cr.rectangle(dst.x, dst.y, dst.width, dst.height);
    cr.clip();
    cr.translate(dst.x, dst.y);
    cr.scale(dst.width / blocksX, dst.height / blocksY);
    cr.setSource(blocks);
    cr.paint();
    cr.restore();
}
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `cd ~/projects/gradia-capture && tests/run.sh`
Expected: every line `ok   …`, then `all passed`, exit 0.

- [ ] **Step 7: Commit**

```bash
cd ~/projects/gradia-capture
git add src/pixelate.js tests/helpers.js tests/run.sh tests/pixelate.test.js
git commit -F - <<'EOF'
feat(censor): add pixelate helper ported from Gradia

Assisted-by: Claude Opus 5.5 via Claude Code
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
```

---

### Task 2: `censor` tool entry, icon, toolbar controls

**Files:**
- Modify: `~/projects/gradia-capture/src/tools.js` (imports at top; new entry after the `solid-rectangle` entry ending at line 121)
- Modify: `~/projects/gradia-capture/src/topBar.js:86-87` (`_updateDrawingControlsSensitivity`)
- Create: `~/projects/gradia-capture/icons/checkerboard-big-symbolic.svg`
- Test: `~/projects/gradia-capture/tests/tools.test.js`

**Interfaces:**
- Consumes: `pixelate(cr, source, srcRect, dstRect)` from `src/pixelate.js` (Task 1).
- Produces:
  - `TOOLS` entry `{ id: 'censor', name: 'Censor', icon: 'icons/checkerboard-big-symbolic.svg', keybindings: [KEY_0, KEY_agrave, KEY_x], isDrawing: true, hasStyle: false, … }`.
  - `render(cr, stroke, lineWidth)` contract for censor: `stroke.points` (≥2, in `cr` space), optional `stroke.source` (`Cairo.ImageSurface` of original pixels) and `stroke.sourcePoints` (same stroke in `source` pixel space). Without both, paints an opaque placeholder.
  - Optional tool flag `hasStyle` (default treated as `true`).

- [ ] **Step 1: Write the failing tests**

`tests/tools.test.js`:

```js
import Cairo from 'gi://cairo';
import GLib from 'gi://GLib';
import { TOOLS, TOOL_SHORTCUTS } from '../src/tools.js';
import {
    test, assert, finish, noiseSurface, blankSurface, copySurface, readPixels,
} from './helpers.js';

const ROOT = GLib.path_get_dirname(
    GLib.path_get_dirname(GLib.filename_from_uri(import.meta.url)[0]));
const censor = TOOLS.find(t => t.id === 'censor');

test('censor tool exists', () => {
    assert(censor, 'no tool with id "censor"');
});

test('censor sits directly after solid-rectangle', () => {
    const i = TOOLS.findIndex(t => t.id === 'solid-rectangle');
    assert(TOOLS[i + 1]?.id === 'censor', `found ${TOOLS[i + 1]?.id} after solid-rectangle`);
});

test('censor draws but has no colour or width', () => {
    assert(censor.isDrawing === true, 'isDrawing is not true');
    assert(censor.hasStyle === false, 'hasStyle is not false');
});

test('censor keybindings are 0, agrave and x, all defined', () => {
    assert(censor.keybindings.length === 3, 'expected three keybindings');
    assert(censor.keybindings.every(k => typeof k === 'number'),
        'a keybinding is undefined — check the Clutter.KEY_* names');
});

test('no two tools share a shortcut', () => {
    const total = TOOLS.reduce((n, t) => n + t.keybindings.length, 0);
    const distinct = Object.keys(TOOL_SHORTCUTS).length;
    assert(distinct === total, `${total} keybindings but only ${distinct} distinct`);
});

test('censor icon file exists', () => {
    const path = GLib.build_filenamev([ROOT, censor.icon]);
    assert(GLib.file_test(path, GLib.FileTest.EXISTS), `missing ${path}`);
});

test('render with a source pixelates the rectangle', () => {
    const src = noiseSurface(64, 48);
    const target = copySurface(src);
    const cr = new Cairo.Context(target);
    const points = [{ x: 8, y: 8 }, { x: 20, y: 20 }, { x: 40, y: 32 }];
    censor.render(cr, { color: '#000000', points, source: src, sourcePoints: points }, 4);
    cr.$dispose();

    const px = readPixels(target);
    for (let by = 0; by < 3; by++) {
        for (let bx = 0; bx < 4; bx++) {
            const x0 = 8 + bx * 8, y0 = 8 + by * 8, first = px.at(x0, y0);
            for (let y = y0; y < y0 + 8; y++)
                for (let x = x0; x < x0 + 8; x++)
                    assert(px.at(x, y) === first, `block ${bx},${by} not uniform at (${x},${y})`);
        }
    }
});

test('render without a source paints an opaque box (fail-safe)', () => {
    const target = blankSurface(40, 40);
    const cr = new Cairo.Context(target);
    censor.render(cr, { color: '#000000', points: [{ x: 5, y: 5 }, { x: 35, y: 30 }] }, 4);
    cr.$dispose();

    const px = readPixels(target);
    for (let y = 5; y < 30; y++)
        for (let x = 5; x < 35; x++)
            assert(px.at(x, y).endsWith(',255'), `(${x},${y}) not opaque: ${px.at(x, y)}`);
});

test('render with fewer than two points draws nothing', () => {
    const target = blankSurface(16, 16);
    const cr = new Cairo.Context(target);
    censor.render(cr, { color: '#000000', points: [{ x: 4, y: 4 }] }, 4);
    cr.$dispose();
    assert(readPixels(target).at(4, 4) === '0,0,0,0', 'single-point stroke drew pixels');
});

finish();
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd ~/projects/gradia-capture && tests/run.sh`
Expected: `tests/pixelate.test.js` all pass; `tests/tools.test.js` reports `FAIL censor tool exists` and every censor test after it fails with a TypeError on `censor` being undefined; overall exit non-zero.

- [ ] **Step 3: Add the icon**

```bash
cd ~/projects/gradia-capture
gh api repos/AlexanderVanhee/Gradia/contents/data/icons/scalable/actions/checkerboard-big-symbolic.svg \
    -H 'Accept: application/vnd.github.raw' > icons/checkerboard-big-symbolic.svg
head -c 200 icons/checkerboard-big-symbolic.svg   # must start with <svg or <?xml
```

- [ ] **Step 4: Add the censor entry to `src/tools.js`**

Add to the imports at the top of `src/tools.js`:

```js
import { pixelate } from './pixelate.js';
```

Add these helpers after `standardHitTest` (before `export const TOOLS`):

```js
function rectFromPoints(points) {
    const p0 = points[0], p1 = points[points.length - 1];
    return {
        x: Math.min(p0.x, p1.x),
        y: Math.min(p0.y, p1.y),
        width: Math.abs(p1.x - p0.x),
        height: Math.abs(p1.y - p0.y),
    };
}

// Opaque on purpose: if the original pixels are unavailable, hide the region
// rather than leave it readable.
function renderCensorPlaceholder(cr, r) {
    if (r.width <= 0 || r.height <= 0)
        return;
    cr.save();
    cr.rectangle(r.x, r.y, r.width, r.height);
    cr.clip();
    cr.setSourceRGBA(0.45, 0.45, 0.45, 1.0);
    cr.paint();
    cr.setSourceRGBA(0.65, 0.65, 0.65, 1.0);
    cr.setLineWidth(2);
    for (let d = -r.height; d < r.width; d += 10) {
        cr.moveTo(r.x + d, r.y + r.height);
        cr.lineTo(r.x + d + r.height, r.y);
    }
    cr.stroke();
    cr.restore();
}
```

Insert this entry immediately after the closing `},` of the `solid-rectangle` entry:

```js
    {
        id: 'censor',
        name: 'Censor',
        icon: 'icons/checkerboard-big-symbolic.svg',
        keybindings: [Clutter.KEY_0, Clutter.KEY_agrave, Clutter.KEY_x],
        isDrawing: true,
        hasStyle: false,
        beginStroke: () => ({}),
        bounds: makeStrokeBounds(() => SELECTION_PADDING),
        hitTest: standardHitTest,
        render(cr, stroke, _lineWidth) {
            if (stroke.points.length < 2)
                return;
            const dst = rectFromPoints(stroke.points);
            if (!stroke.source || !(stroke.sourcePoints?.length >= 2)) {
                renderCensorPlaceholder(cr, dst);
                return;
            }
            pixelate(cr, stroke.source, rectFromPoints(stroke.sourcePoints), dst);
        },
    },
```

- [ ] **Step 5: Respect `hasStyle` in the toolbar**

In `src/topBar.js`, `_updateDrawingControlsSensitivity()`, replace:

```js
        const drawing = this._currentToolIsDrawing();
```

with:

```js
        const tool = TOOLS.find(t => t.id === this._selectedTool);
        const drawing = this._currentToolIsDrawing() && tool?.hasStyle !== false;
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `cd ~/projects/gradia-capture && tests/run.sh`
Expected: both files print only `ok` lines and `all passed`; exit 0.

- [ ] **Step 7: Check the package includes the new files**

Run:

```bash
cd ~/projects/gradia-capture && ./build.sh && \
  unzip -l gradia-integration@alexandervanhee.github.io.shell-extension.zip | \
  grep -E 'pixelate\.js|checkerboard-big-symbolic\.svg|tests/'; \
  rm -f gradia-integration@alexandervanhee.github.io.shell-extension.zip
```

Expected: `pixelate.js` and `icons/checkerboard-big-symbolic.svg` listed; **no** `tests/` entries.

- [ ] **Step 8: Commit**

```bash
cd ~/projects/gradia-capture
git add src/tools.js src/topBar.js icons/checkerboard-big-symbolic.svg tests/tools.test.js
git commit -F - <<'EOF'
feat(censor): add Censor tool matching Gradia's pixelation

Drag a rectangle to pixelate it in 8 px blocks. Without original pixels
it paints an opaque box rather than leave the region readable. Colour
and width controls are disabled for it.

Assisted-by: Claude Opus 5.5 via Claude Code
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
```

---

### Task 3: Supply original pixels in preview and export; fork metadata

**Files:**
- Modify: `~/projects/gradia-capture/src/extension.js` — imports (lines 1-16), `DrawingCanvas._init` (lines 50-73), `DrawingCanvas.vfunc_repaint` render call (lines 326-331), `enable()` (line 383+), `_compositeStrokesOntoPixbuf` (lines 778-820), `_setTool` (lines 998-1017), `_removeUI` (line 1380+)
- Modify: `~/projects/gradia-capture/src/metadata.json`
- Modify: `~/projects/gradia-capture/README.md`

**Interfaces:**
- Consumes: censor `render` contract from Task 2 (`stroke.source`, `stroke.sourcePoints`).
- Produces (internal to `extension.js`):
  - `function surfaceFromPixbuf(pixbuf) → Cairo.ImageSurface`
  - `DrawingCanvas.setCensorSource(src)` where `src` is `{ surface: Cairo.ImageSurface, scale: number }` or `null`; `scale` maps stage coordinates to `surface` pixels.
  - `GradiaCompanion._ensureCensorSource() → Promise<void>`; fields `_censorSource`, `_censorSourcePending`, `_censorSession`.

No unit test is possible here: `extension.js` imports `resource:///org/gnome/shell/…`, which only resolves inside GNOME Shell. This task's gate is the package check in Step 8 plus the live checklist in Task 4. Keep every change below exactly as written so the unit-tested `render` contract does the real work.

- [ ] **Step 1: Imports and `surfaceFromPixbuf`**

Add to the imports at the top of `src/extension.js`:

```js
import Gio from 'gi://Gio';
import Shell from 'gi://Shell';
```

Add after `function getToolDef(id) { … }`:

```js
function surfaceFromPixbuf(pixbuf) {
    const surface = new Cairo.ImageSurface(Cairo.Format.ARGB32, pixbuf.get_width(), pixbuf.get_height());
    const cr = new Cairo.Context(surface);
    imports.gi.Gdk.cairo_set_source_pixbuf(cr, pixbuf, 0, 0);
    cr.paint();
    cr.$dispose();
    return surface;
}
```

- [ ] **Step 2: Canvas holds the preview source**

In `DrawingCanvas._init`, after `this._selectedStroke = null;` add:

```js
            this._censorSource = null;
```

Add this method directly after `setTool(id) { … }`:

```js
        setCensorSource(source) {
            this._censorSource = source;
            this.queue_repaint();
        }
```

- [ ] **Step 3: Preview render passes source pixels**

In `vfunc_repaint`, replace the `tool.render(cr, { … }, stroke.strokeWidth);` call with:

```js
                const censorSource = stroke.toolId === 'censor' ? this._censorSource : null;
                tool.render(cr, {
                    color: stroke.color,
                    points: localPoints,
                    counter: stroke.toolId === 'stamp' ? stampCounter++ : stroke.counter,
                    text: stroke.text,
                    source: censorSource?.surface ?? null,
                    sourcePoints: censorSource
                        ? stroke.stagePoints.map(sp => ({ x: sp.x * censorSource.scale, y: sp.y * censorSource.scale }))
                        : null,
                }, stroke.strokeWidth);
```

- [ ] **Step 4: Export render passes the untouched capture**

In `_compositeStrokesOntoPixbuf`, after the existing `cr.paint();` that paints `pixbuf`, add:

```js
        // Censor samples the capture as it was, never other annotations.
        const censorSource = strokes.some(s => s.toolId === 'censor') ? surfaceFromPixbuf(pixbuf) : null;
```

and replace its `tool.render(cr, { … }, lw);` call with:

```js
            const isCensor = stroke.toolId === 'censor';
            tool.render(cr, {
                color: stroke.color,
                points: converted,
                counter: stroke.counter,
                text: stroke.text,
                source: isCensor ? censorSource : null,
                sourcePoints: isCensor ? converted : null,
            }, lw);
```

- [ ] **Step 5: Snapshot lifecycle**

In `enable()`, after `this._pendingTextStroke = null;` add:

```js
        this._censorSource = null;
        this._censorSourcePending = false;
        this._censorSession = 0;
```

Add this method directly before `_isDrawingTool(id)`:

```js
    async _ensureCensorSource() {
        if (this._censorSource || this._censorSourcePending)
            return;
        const content = Main.screenshotUI._stageScreenshot?.get_content();
        if (!content)
            return;

        this._censorSourcePending = true;
        const session = this._censorSession;
        try {
            const stream = Gio.MemoryOutputStream.new_resizable();
            const pixbuf = await Shell.Screenshot.composite_to_stream(
                content.get_texture(), 0, 0, -1, -1, 1, null, 0, 0, 1, stream);
            stream.close(null);
            if (session !== this._censorSession)
                return;
            this._censorSource = {
                surface: surfaceFromPixbuf(pixbuf),
                scale: pixbuf.get_width() / global.stage.width,
            };
            for (const canvas of this._canvases)
                canvas.setCensorSource(this._censorSource);
        } catch (e) {
            console.error(`Gradia Capture: censor snapshot failed: ${e.message}`);
        } finally {
            if (session === this._censorSession)
                this._censorSourcePending = false;
        }
    }
```

In `_setTool(id)`, after `const dragging = id === 'drag';` add:

```js
        if (id === 'censor')
            this._ensureCensorSource();
```

At the top of `_removeUI()`, before `this._cancelTextEntry();`, add:

```js
        this._censorSession++;
        this._censorSource = null;
        this._censorSourcePending = false;
```

- [ ] **Step 6: Fork metadata**

In `src/metadata.json`, set `"url"` to `"https://github.com/Sir-Mudkip/gradia-capture"` and add `"version-name": "sivablue-1",` after the `"uuid"` line. Leave `uuid`, `settings-schema` and `shell-version` unchanged.

- [ ] **Step 7: README fork note**

Insert at the very top of `README.md`, above the existing `<div align="center">`:

```markdown
> **Fork of [AlexanderVanhee/gradia-capture](https://github.com/AlexanderVanhee/gradia-capture)**
> for [Sivablue](https://github.com/Sir-Mudkip/Sivablue). Adds a **Censor** tool
> (shortcut `0` / `x`) that pixelates a dragged rectangle the way the Gradia app
> does. Unit tests: `tests/run.sh`.

```

- [ ] **Step 8: Package check and tests**

Run:

```bash
cd ~/projects/gradia-capture && tests/run.sh && ./build.sh && \
  python3 -I -c 'import json,sys; m=json.load(open("src/metadata.json")); print(m["uuid"], m["version-name"], m["shell-version"])' && \
  rm -f gradia-integration@alexandervanhee.github.io.shell-extension.zip
```

Expected: `all passed` for both test files; `Packing Done!`; `gradia-integration@alexandervanhee.github.io sivablue-1 ['49', '50']`.

- [ ] **Step 9: Commit**

```bash
cd ~/projects/gradia-capture
git add src/extension.js src/metadata.json README.md
git commit -F - <<'EOF'
feat(censor): feed original pixels to the censor tool

Export samples the untouched capture; the live preview samples a
snapshot of the frozen stage screenshot, taken when the tool is first
selected and dropped when the screenshot UI closes.

Assisted-by: Claude Opus 5.5 via Claude Code
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
```

---

### Task 4: Live verification, then push the fork

**Files:** none changed unless a check fails (then fix in the owning file, re-run `tests/run.sh`, commit, and repeat the failing check).

**Interfaces:**
- Consumes: the built extension from Tasks 1-3.
- Produces: fork `master` pushed to `origin` — the commit Task 5 pins.

- [ ] **Step 1: Install the fork as a user extension**

```bash
cd ~/projects/gradia-capture && ./build.sh -i && \
  rm -f gradia-integration@alexandervanhee.github.io.shell-extension.zip
```

Expected: `Extension is installed.` A user-dir copy with the same UUID is loaded in preference to `/usr/share/gnome-shell/extensions/…`.

- [ ] **Step 2: User logs out and back in** (Wayland cannot restart the shell in place). Then confirm the fork is the one loaded:

```bash
gnome-extensions info gradia-integration@alexandervanhee.github.io | grep -E 'Path|Version|State'
```

Expected: `Path:` under `~/.local/share/gnome-shell/extensions/`, `State: ACTIVE`.

- [ ] **Step 3: User walks the live checklist** (Print Screen to open the screenshot UI). Each item must pass:

| # | Action | Expected |
|---|---|---|
| L1 | Area mode: select the Censor tool (toolbar or `0`/`x`), drag over text | Text becomes 8 px blocks immediately (a grey hatched box at most for a split second) |
| L2 | Save (capture button); open the PNG from `~/Pictures/Screenshots` | Same blocks as the preview; text unreadable |
| L3 | If any display uses scaling ≠ 100 %: repeat L1-L2 on it | Saved blocks line up with the preview blocks |
| L4 | Screen mode: censor a region, capture, paste into an editor (clipboard) | Pasted image is censored |
| L5 | Switch to Drag, move the censor box onto different text | Box re-pixelates the text now under it; the old spot shows the original again |
| L6 | Draw an arrow, censor over it, then draw another arrow on top | First arrow hidden under the blocks; second arrow sharp on top — in preview and saved file |
| L7 | Select Censor, press Esc at once; reopen on a different screen; censor | No error; blocks show the *new* screen content |
| L8 | Censor in area mode, then switch to Window mode | Annotations disappear from view; the window capture is **not** censored (upstream behaviour — this is expected, not a failure) |
| L9 | "Save as" (portal) and the toast's edit-in-Gradia button | Both files censored |
| L10 | With Censor selected, look at colour buttons and width slider | Greyed out and unclickable |

Then check the journal for errors from the session:

```bash
journalctl --user -b --since "-15min" | grep -i 'gradia' | grep -iE 'error|exception|censor' || echo "no gradia errors"
```

Expected: `no gradia errors`.

- [ ] **Step 4: Remove the user-dir copy** (so the image's copy is used again after the next login)

```bash
gnome-extensions uninstall gradia-integration@alexandervanhee.github.io 2>/dev/null || \
  rm -rf ~/.local/share/gnome-shell/extensions/gradia-integration@alexandervanhee.github.io
test ! -e ~/.local/share/gnome-shell/extensions/gradia-integration@alexandervanhee.github.io && echo removed
```

Expected: `removed`. (`gnome-extensions uninstall` only removes user-dir extensions; the system copy is untouched.)

- [ ] **Step 5: Push the fork**

```bash
cd ~/projects/gradia-capture && git push origin master && git log --oneline -4
```

Expected: the three `feat(censor)` commits on top of `f70a212`.

---

### Task 5: Point Sivablue at the fork

**Files:**
- Modify: `/var/home/luke/projects/Sivablue/.gitmodules`
- Modify: submodule pointer `system/usr/share/gnome-shell/extensions/gradia-integration@alexandervanhee.github.io`
- Modify: `/var/home/luke/projects/Sivablue/build/99-tests.sh`
- Modify: `/var/home/luke/projects/Sivablue/docs/extensions.md`

**Interfaces:**
- Consumes: fork `master` from Task 4.
- Produces: an image whose installed `tools.js` contains the censor tool.

- [ ] **Step 1: Write the failing image test**

In `build/99-tests.sh`, directly before the `IMPORTANT_PACKAGES=(` line, add:

```bash
# Gradia Capture comes from the Sir-Mudkip fork; the censor tool proves it.
grep -q "id: 'censor'" /usr/share/gnome-shell/extensions/gradia-integration@alexandervanhee.github.io/tools.js
```

- [ ] **Step 2: Verify it fails against the current (upstream) submodule**

Run: `grep -q "id: 'censor'" "system/usr/share/gnome-shell/extensions/gradia-integration@alexandervanhee.github.io/src/tools.js"; echo "exit=$?"` from `/var/home/luke/projects/Sivablue`
Expected: `exit=1` (upstream has no censor tool).

- [ ] **Step 3: Switch the submodule to the fork**

In `.gitmodules`, change the gradia entry's `url` to `https://github.com/Sir-Mudkip/gradia-capture.git` (leave `path` and `branch = master`). Then:

```bash
cd /var/home/luke/projects/Sivablue
git submodule sync -- 'system/usr/share/gnome-shell/extensions/gradia-integration@alexandervanhee.github.io'
git submodule update --remote -- 'system/usr/share/gnome-shell/extensions/gradia-integration@alexandervanhee.github.io'
git submodule status | grep gradia
```

Expected: the submodule now points at the fork's head (the last `feat(censor)` commit from Task 4).

- [ ] **Step 4: Verify the source check now passes**

Run: `grep -q "id: 'censor'" "system/usr/share/gnome-shell/extensions/gradia-integration@alexandervanhee.github.io/src/tools.js"; echo "exit=$?"`
Expected: `exit=0`.

- [ ] **Step 5: Update `docs/extensions.md`**

In the UUID table, replace the gradia row with:

```markdown
| `gradia-integration@alexandervanhee.github.io` | [Sir-Mudkip/gradia-capture](https://github.com/Sir-Mudkip/gradia-capture) (hard fork of [AlexanderVanhee/gradia-capture](https://github.com/AlexanderVanhee/gradia-capture)) |
```

Add this section after the "Per extension" build list:

```markdown
## Gradia Capture is a fork

Upstream Gradia Capture has no way to obscure a region except an opaque box.
The fork adds a **Censor** tool that pixelates a dragged rectangle in 8 px
blocks, ported from the Gradia app's own censor tool, so the result is
irreversible once saved. It is a hard fork: its `master` is the source of
truth and keeps the upstream UUID, so `enabled-extensions` and users'
settings carry over. `build/99-tests.sh` greps the installed `tools.js` for
the censor tool so the submodule cannot silently revert to upstream.

To take upstream changes:

    cd ~/projects/gradia-capture
    git fetch upstream && git merge upstream/master
    tests/run.sh && git push origin master

Renovate then opens the submodule bump PR here. Design:
`docs/superpowers/specs/2026-10-15-gradia-censor-tool-design.md`.
```

- [ ] **Step 6: Lint, check, full build**

```bash
cd /var/home/luke/projects/Sivablue && just lint && just check && just build
```

Expected: lint and check clean; `just build` ends with `Successfully tagged localhost/sivablue:stable`, and the build log shows the new `grep -q "id: 'censor'"` line executing in `99-tests.sh` without failing.

- [ ] **Step 7: Commit**

```bash
cd /var/home/luke/projects/Sivablue
git add .gitmodules 'system/usr/share/gnome-shell/extensions/gradia-integration@alexandervanhee.github.io' build/99-tests.sh docs/extensions.md
git commit -F - <<'EOF'
feat(extensions): build Gradia Capture from the censor-tool fork

Points the submodule at Sir-Mudkip/gradia-capture, which adds a Censor
tool ported from the Gradia app's pixelation. 99-tests asserts the
installed extension carries it.

Assisted-by: Claude Opus 5.5 via Claude Code
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
```

- [ ] **Step 8: Clean up the build**

```bash
podman rmi localhost/sivablue:stable quay.io/fedora-ostree-desktops/silverblue:44 2>/dev/null; podman image prune -f
find /var/tmp/buildah-cache-"$(id -u)" -mindepth 1 -maxdepth 1 -newer /var/home/luke/projects/Sivablue/.gitmodules -exec rm -rf {} +
du -sh /var/tmp/buildah-cache-"$(id -u)"
```

Expected: cache directory back to ~0; no `sivablue` or `silverblue` images in `podman images`.

- [ ] **Step 9: Push (only with the user's go-ahead)**

Ask the user; on yes: `git push origin master`, then watch the `Build container image` run to green.
