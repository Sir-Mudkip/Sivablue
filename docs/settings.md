# Settings

There are two mechanisms for shipping a GNOME/dconf setting in this image,
and they are **not interchangeable**. Writing an override in the wrong one
does not error at build time or at runtime — it silently does nothing. The
setting simply never takes effect, with no log line to point at. Knowing
which mechanism a given schema requires is the only way to avoid that.

## gschema overrides

`system/usr/share/glib-2.0/schemas/zz0-sivablue-mods.gschema.override`
overrides the *defaults* for schemas that are themselves installed in that
same directory, `/usr/share/glib-2.0/schemas/` on the built image (the
`system/usr/` tree is mirrored verbatim to `/usr/`, per
`filesystem-layout.md`). Nothing in this repository puts a schema there —
`system/usr/share/glib-2.0/schemas/` contains the override file and
nothing else, and no build stage copies a schema in. Every schema the
override can reach therefore comes from a package in the base image.

`org.gnome.shell` is the worked example: its schema is already in
`/usr/share/glib-2.0/schemas/`, put there by the base image's own GNOME
packages, the `system/` mirror drops the override alongside it, and
`glib-compile-schemas` then folds the override into the compiled defaults.
That is how `favorite-apps` and
`enabled-extensions` take effect. The same holds for `org.gnome.desktop.*`,
`org.gnome.mutter`, `org.gnome.settings-daemon.plugins.*` and
`org.gnome.Ptyxis`.

### Why the override carries no extension blocks

It used to carry two — for `org.gnome.shell.extensions.dash-to-dock` and
`org.gnome.shell.extensions.Logo-menu` — and neither had any effect. They
were removed; this section records why, because the failure is entirely
silent and the mistake is easy to repeat.

A vendored extension keeps its schema inside its own directory. Dash to
Dock's `.gschema.xml` sits in
`system/usr/share/gnome-shell/extensions/dash-to-dock@micxgx.gmail.com/schemas/`
and is compiled in place by `build/15-extensions.sh:12`; the same is true
of Logo Menu (`build/15-extensions.sh:17`). Nothing moves them into
`/usr/share/glib-2.0/schemas/`, so an override file living there has no
schema to attach to. Dash to Dock's `Makefile` does have an `install-local`
target that would copy the schema across (line 107), but
`build/15-extensions.sh` runs bare `make`, whose `all:` target is
`extension` and never invokes `install`. Neither extension appears in
`FEDORA_PACKAGES` either, so no package installs a schema on their behalf.

Logo Menu's block additionally had the id in the wrong case — the schema
declares `org.gnome.shell.extensions.logo-menu`, all lowercase, and
GSettings ids are case-sensitive — but that was a second fault on top of a
block that could not have matched anyway.

The build does not complain because the whole-directory compile
(`build/15-extensions.sh:30`, `build/20-content-cleanup.sh:19`) runs
without `--strict`; an override naming an absent schema is skipped with a
warning rather than treated as an error. Only the per-extension compiles
use `--strict`, and they never see this file.

So Logo Menu's settings reach the system only through
`system/etc/dconf/db/distro.d/03-sivablue-logomenu-extension`, which is
where they still live. Dash to Dock has no `distro.d` file, so the dock
runs on upstream defaults — deleting its block changed nothing, it only
stopped the file claiming otherwise. **Any future extension setting belongs
in `distro.d/`, never here.**

The filename's `zz0-` prefix orders it late among the files in
`/usr/share/glib-2.0/schemas/` — nothing in the repository states the
compiler's tie-break rule explicitly, so treat "sorts late" as the
substantiated claim rather than asserting a precise win mechanism. It is
also the only `.gschema.override` file this repository ships.

Compilation happens in two separate places, over two separate sets of
files. `build/15-extensions.sh` compiles each extension's own `schemas/`
directory with `glib-compile-schemas --strict`, then compiles
`/usr/share/glib-2.0/schemas` — the directory holding this override and
the base image's schemas — as a separate step. `build/20-content-cleanup.sh`
repeats only that whole-directory compile, after removing `/usr/src` and
`/usr/share/doc` and touching the wallpaper config. Both whole-directory
compiles matter: an override edited after the first would otherwise ship
uncompiled.

## dconf database

`system/etc/dconf/db/distro.d/` sets values **by path** rather than by
schema id. This is the only option for relocatable schemas — ones with no
fixed installed schema file for an override to attach to. The two clear
examples here are the Ptyxis terminal profile palette
(`02-sivablue-ptyxis-palette`) and the custom media-key bindings
(`01-sivablue-keybindings`); both source files say as much in their own
header comments. The same directory is also the only working route for a
vendored extension, whose schema stays inside its own directory where the
override file cannot reach it. Logo Menu
(`03-sivablue-logomenu-extension`) is the one extension wired up this way,
and it is why its settings apply while the override block meant for it does
not: `distro.d` matches on the path the schema declares
(`/org/gnome/shell/extensions/Logo-menu/`), which needs neither the schema
to be installed centrally nor the id to be spelled correctly.

`system/etc/dconf/db/distro.d/locks/` is where a lock file would go to
prevent a user changing a given key; the directory currently exists but is
empty, so no dconf keys in this image are locked yet.

`dconf-update.service` is enabled in `build/25-sysconfig.sh` (see the
"Enabling system services" block). It runs `dconf update` at boot, which is
what compiles the text files under `distro.d/` into the binary dconf
database that clients actually read — without it, changes to `distro.d/`
would sit on disk and never apply.

## Choosing between them

Apply this rule:

- If the schema is installed into `/usr/share/glib-2.0/schemas/` by a
  package in the base image, add the override to
  `zz0-sivablue-mods.gschema.override`.
- If the schema is relocatable, or belongs to a vendored extension and so
  lives in that extension's own directory, add it under
  `system/etc/dconf/db/distro.d/` instead.

When in doubt, check whether the setting's schema file lives under
`/usr/share/glib-2.0/schemas/` in the built image. If it does not, the
override file cannot reach it, and the change belongs in `distro.d`.
Assume it does not for anything vendored under
`system/usr/share/gnome-shell/extensions/`.

See `extensions.md` for how a new extension's settings are wired into
whichever mechanism it needs.
