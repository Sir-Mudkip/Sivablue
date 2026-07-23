# fastfetch assets

System-wide fastfetch configuration for Sivablue.

- `logos/sivablue.txt` — the SIVA mark as a **pre-rendered coloured-braille text
  logo**. This is the asset the config renders: `config.jsonc` sets `logo.type` to
  `file-raw`, so fastfetch just prints the file's bytes verbatim. That means the
  logo needs **no image libraries at runtime** (no chafa, no ImageMagick) and shows
  up in any terminal, even when output is piped.

It is committed as a static asset rather than generated during the build: the logo
changes ~never, so a build stage would be more machinery than it warrants. Its
source of truth is `system/usr/share/backgrounds/sivablue/siva-mini-logo.svg`; the
`.txt` is a rasterise-then-symbol-render of that SVG.

Regenerate after the SVG changes (needs `librsvg2-tools` and the `chafa` CLI):

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

The config itself lives at `system/etc/fastfetch/config.jsonc` (the `/etc/fastfetch/`
slot in `fastfetch --list-config-paths`) so it applies to every user while a user's
own `~/.config/fastfetch/config.jsonc` still fully overrides it.
