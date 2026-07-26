# Filesystem layout

Anything static goes in `system/`; anything that needs to run (downloads,
compiles, package installs) goes in a `build/` stage. This page records
where files end up in the built image and why, for decisions that span
several build stages plus the `Containerfile` and so have no single-stage
home. Per-stage behaviour is documented in `build-stages.md`.

## The `system/` mirror

`build/build.sh:7-8` mirrors the `system/` tree into the image verbatim:

```
cp -rT /ctx/system/usr/ /usr/
cp -rT /ctx/system/etc/ /etc/
```

`system/usr/…` becomes `/usr/…`, and `system/etc/…` becomes `/etc/…`, byte
for byte. There is no filtering step.

Consequence: every file placed under `system/` ships to every installed
machine. That is why no explanatory README lives there — documentation
belongs in `docs/`, which is not mirrored into the image and never reaches
an installed system.

## `/usr` is read-only at runtime

The image is a bootc/ostree system, so `/usr` is read-only once booted.
Bundled self-updaters cannot write to it and must be disabled at build
time, or they will nag users about updates they have no way to apply from
inside the application.

Firefox-family applications need a `distribution/policies.json` with
`DisableAppUpdate` set (see `build/12-waterfox.sh`, which writes this for
Waterfox). Updates arrive via image rebuild plus `bootc upgrade`, so
"latest" means latest **at build time**, not at run time.

## Tarballs go to `/usr/lib`, not `/opt`

Tarball installs go under `/usr/lib/<name>`, with a symlink into
`/usr/bin` so the binary resolves on `PATH`. `/opt` is not available for
this: the `Containerfile` does `rm /opt && mkdir /opt` to make it
immutable, so nothing can be installed there.

`build/12-waterfox.sh` is the reference implementation: it extracts the
tarball to `/usr/lib/waterfox`, symlinks `/usr/bin/waterfox` to the
extracted binary, writes the updater-disabling policy described above,
promotes the bundled icons into the `hicolor` icon theme, and rebuilds the
icon cache and desktop database by hand — steps `rpm` would otherwise do
for a packaged install.

## `/etc` versus `/usr/share`

`/etc` is for configuration an administrator (or user override) may
change; `/usr/share` is for vendor-supplied data that is not meant to be
edited in place.

Concrete examples from this image:

- The fastfetch config lives at `/etc/fastfetch/config.jsonc` so it
  applies to every user, while a user's own
  `~/.config/fastfetch/config.jsonc` still fully overrides it.
- The flatpak preinstall file lives at
  `/usr/share/flatpak/preinstall.d/` (see `flatpaks.md`) — it is vendor
  data, not something an administrator is expected to hand-edit.

## Static assets

The fastfetch logo at `system/usr/share/fastfetch/logos/sivablue.txt` is a
pre-rendered coloured-braille text logo. `config.jsonc` sets `logo.type`
to `file-raw`, so fastfetch prints the file's bytes verbatim: no image
libraries are needed at runtime (no chafa, no ImageMagick), and it renders
in any terminal, even when piped.

It is committed as a static asset rather than generated during the build
because the logo changes almost never, so a build stage would be more
machinery than it warrants. Its source of truth is
`system/usr/share/backgrounds/sivablue/siva-mini-logo.svg`; the `.txt` is a
rasterise-then-symbol-render of that SVG.

Regenerate the logo after the SVG changes (needs `librsvg2-tools` and the
`chafa` CLI):

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

`build/99-tests.sh` checks `/etc/fastfetch/config.jsonc` and
`/usr/share/fastfetch/logos/sivablue.txt` exist, since they are staged
from `system/` and `rpm -q` cannot vouch for them.
