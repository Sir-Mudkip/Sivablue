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
removed and `glib-compile-schemas` is rerun over that directory. This is a
*separate* compile, not a combined one: each extension's schemas were
already compiled in its own `schemas/` directory and stay there, while
`/usr/share/glib-2.0/schemas/` holds the base image's schemas plus
`zz0-sivablue-mods.gschema.override`. The two sets never meet, which is why
the override file cannot set an extension's defaults — see `settings.md`.
`build/20-content-cleanup.sh` repeats the whole-directory recompile later in
the build, after cleanup steps that also touch that directory.

## Enabling

An extension is enabled by adding its UUID to `enabled-extensions` in
`system/usr/share/glib-2.0/schemas/zz0-sivablue-mods.gschema.override`. That
key belongs to `org.gnome.shell`, whose schema the base image installs
centrally, so the override reaches it.

The extension's *own* settings are a different matter: they belong in
`system/etc/dconf/db/distro.d/`, because a vendored extension's schema
never lands in `/usr/share/glib-2.0/schemas/` for an override to attach to.
See `settings.md`, which uses this repository's own override file as the
worked example of that failing silently.

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
