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
`filesystem-layout.md`). That covers `org.gnome.shell`,
`org.gnome.desktop.*`, Ptyxis (`org.gnome.Ptyxis`), and the two extension
schemas that ship their own compiled `.gschema.xml`
(`org.gnome.shell.extensions.dash-to-dock`,
`org.gnome.shell.extensions.Logo-menu`).

The filename's `zz0-` prefix orders it late among the files in
`/usr/share/glib-2.0/schemas/` — nothing in the repository states the
compiler's tie-break rule explicitly, so treat "sorts late" as the
substantiated claim rather than asserting a precise win mechanism. It is
also, in this image, the only `.gschema.override` file in the directory.

Schemas are compiled with `glib-compile-schemas --strict` once per extension
and then wholesale for the whole directory in `build/15-extensions.sh`, and
recompiled again in `build/20-content-cleanup.sh` after that stage removes
`/usr/src` and `/usr/share/doc` and touches the wallpaper config. Both
recompiles matter: an override edited after the first compile but before the
second would otherwise ship uncompiled.

## dconf database

`system/etc/dconf/db/distro.d/` sets values **by path** rather than by
schema id. This is the only option for relocatable schemas — ones with no
fixed installed schema file for an override to attach to. The two clear
examples here are the Ptyxis terminal profile palette
(`02-sivablue-ptyxis-palette`) and the custom media-key bindings
(`01-sivablue-keybindings`); both source files say as much in their own
header comments. The same directory is also where an extension's settings
go if its schema is not reachable via the compiled
`/usr/share/glib-2.0/schemas/` override at all, per `03-sivablue-logomenu-extension`.

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

- If the schema is installed into `/usr/share/glib-2.0/schemas/` (a normal
  GSettings schema, including most extension schemas), add the override to
  `zz0-sivablue-mods.gschema.override`.
- If the schema is relocatable, or the value has no compiled schema file to
  override (extension settings stored only by path), add it under
  `system/etc/dconf/db/distro.d/` instead.

When in doubt, check whether the setting's schema file lives under
`/usr/share/glib-2.0/schemas/` in the built image. If it does not, the
override file cannot reach it, and the change belongs in `distro.d`.

See `extensions.md` for how a new extension's settings are wired into
whichever mechanism it needs.
