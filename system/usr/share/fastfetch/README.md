# fastfetch assets

System-wide fastfetch configuration for Sivablue.

- `logos/sivablue.png` — the SIVA mark, rendered from
  `system/usr/share/backgrounds/sivablue/siva-mini-logo.svg`. It is committed as a
  static asset rather than generated during the build: the SVG changes ~never, so a
  build stage (plus `librsvg2-tools` and a test) would be more machinery than the
  asset warrants. The config points fastfetch at this PNG and lets fastfetch's
  built-in chafa render it as coloured terminal art, which works in any terminal
  without needing the kitty/sixel graphics protocols.

  Regenerate it if the SVG ever changes:

  ```bash
  rsvg-convert -w 640 -h 612 -b none \
    system/usr/share/backgrounds/sivablue/siva-mini-logo.svg \
    -o system/usr/share/fastfetch/logos/sivablue.png
  ```

The config itself lives at `system/etc/fastfetch/config.jsonc` (the `/etc/fastfetch/`
slot in `fastfetch --list-config-paths`) so it applies to every user while a user's
own `~/.config/fastfetch/config.jsonc` still fully overrides it.
