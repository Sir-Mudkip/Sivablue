# GNOME extensions

Extensions are vendored as **git submodules** under
`system/usr/share/gnome-shell/extensions/<uuid>/`, one submodule per
extension, checked out at the path GNOME Shell expects to find them once
`system/usr/` is mirrored to `/usr/` (see `filesystem-layout.md`).

CI checks out with `submodules: recursive`
(`.github/workflows/build.yml`, the `Checkout` step). A plain, non-recursive
clone leaves these directories empty, and the build fails when
`build/15-extensions.sh` tries to build or compile schemas for extensions
that were never fetched.

## Current extensions

| UUID | Upstream |
|---|---|
| `dash-to-dock@micxgx.gmail.com` | [micheleg/dash-to-dock](https://github.com/micheleg/dash-to-dock) |
| `logomenu@aryan_k` | [ublue-os/Logomenu](https://github.com/ublue-os/Logomenu) |
| `gradia-integration@alexandervanhee.github.io` | [AlexanderVanhee/gradia-capture](https://github.com/AlexanderVanhee/gradia-capture) |
| `clipboard-indicator@tudmotu.com` | [Tudmotu/gnome-shell-extension-clipboard-indicator](https://github.com/Tudmotu/gnome-shell-extension-clipboard-indicator) |

(Source: `.gitmodules`.)

## Building

Build steps live in `build/15-extensions.sh`. It installs the tooling those
builds need — `glib2-devel meson sassc cmake dbus-devel` — builds each
extension, compiles every extension's schema directory with
`glib-compile-schemas --strict`, then removes the tooling again so it does
not stay in the final image.

Per extension:

- **Dash to Dock** is built with `make` directly in its submodule
  directory, then its `schemas/` directory is compiled.
- **Logo Menu** ships two helper binaries
  (`distroshelf-helper`, `missioncenter-helper`) that are installed straight
  into `/usr/bin` with `install -Dpm0755`, then its schemas are compiled.
- **Gradia Capture** runs its own `build.sh`, which produces a
  `.shell-extension.zip`; that zip is unpacked back into the extension's own
  directory with `unzip -o` and then deleted, before its schemas are
  compiled.
- **Clipboard Indicator** ships pre-built, so only its schemas are compiled
  — no separate build step runs.

At the end of the stage, `/usr/share/glib-2.0/schemas/gschemas.compiled` is
removed and `glib-compile-schemas` is rerun over the whole directory, so the
per-extension schemas and `zz0-sivablue-mods.gschema.override` are compiled
together. `build/20-content-cleanup.sh` repeats that whole-directory
recompile later in the build, after cleanup steps that also touch the
schema directory.

## Enabling

An extension is enabled by adding its UUID to `enabled-extensions` in
`system/usr/share/glib-2.0/schemas/zz0-sivablue-mods.gschema.override`. See
`settings.md` for why this file, specifically, is the right place, and what
happens if a setting for the extension needs the dconf database instead.

## Adding one

1. `git submodule add <url> system/usr/share/gnome-shell/extensions/<uuid>`.
2. Add build steps for it to `build/15-extensions.sh` — at minimum a
   `glib-compile-schemas --strict` call over its `schemas/` directory if it
   ships one, plus whatever the upstream build process requires (a `make`,
   a `meson` build, a bundled `build.sh`, or nothing at all if it ships
   pre-built).
3. Add its UUID to `enabled-extensions` in
   `zz0-sivablue-mods.gschema.override`.
4. Check the extension's `metadata.json` `shell-version` array covers the
   base image's GNOME release. GNOME Shell will not load an extension whose
   `shell-version` does not list the running shell's version — it is
   silently skipped, with nothing in the logs that names it as the cause.
   Widening `shell-version` (or confirming it already covers the target
   release) before merging avoids finding this out only after the image
   boots.

## Note on linting

`just lint` recurses into vendored submodules, so it will report on
upstream code too — for example Gradia's own `build.sh`. Those findings
belong to the upstream project, not this repository, and are not something
this repository needs to fix.
