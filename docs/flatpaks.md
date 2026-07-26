# Flatpaks

Flatpak applications are not baked into the image. They are declared for
preinstall — a list the built system carries, which Flatpak itself acts on
after the user's first boot.

## The critical constraint

`system/usr/share/flatpak/preinstall.d/default.preinstall` (mirrored to
`/usr/share/flatpak/preinstall.d/default.preinstall`, see
`filesystem-layout.md`) **must exist in the image**. If it does not, Bazaar
is uninstalled from users' systems.

`build/99-tests.sh` asserts:

```bash
test -f /usr/share/flatpak/preinstall.d/default.preinstall
```

with a comment stating exactly why:

```
# If this file is not on the image bazaar will automatically be removed from users systems :(
# See: https://docs.flatpak.org/en/latest/flatpak-command-reference.html#flatpak-preinstall
```

Never delete or rename this file.

## Adding a Flatpak

Add a `[Flatpak Preinstall <id>]` block to `default.preinstall`. Recognised
keys:

- `Install` — boolean, default `true`.
- `Branch` — string, commonly `stable`.
- `IsRuntime` — boolean, default `false`; set for runtimes rather than
  applications.
- `CollectionID` — string identifying the remote's collection.

Example, one application and one runtime:

```ini
[Flatpak Preinstall org.gnome.Calculator]
Branch=stable

[Flatpak Preinstall org.gtk.Gtk3theme.adw-gtk3]
Branch=3.22
IsRuntime=true
```

## Installation timing

Flatpaks are **not** in the ISO or the container image. They download on
first boot, after user setup completes and a network connection exists.

Consequences:

- The ISO stays small and bootable offline.
- Users need an internet connection afterwards for these applications to
  appear.
- First boot takes longer while Flatpaks download.

This is not an offline ISO with pre-embedded applications — treat
`default.preinstall` as a wish list handed to Flatpak, not a bundle.

## Remotes

`build/96-overrides.sh` adds the Flathub remote and disables
`flatpak-add-fedora-repos.service` (the systemd unit that would otherwise
add Fedora's own Flatpak remote). `build/98-clean-stage.sh` masks that unit
and deletes it from the image outright. `build/99-tests.sh` fails the build
if the unit file reappears:

```bash
test -f /usr/lib/systemd/system/flatpak-add-fedora-repos.service && false
```

So Fedora's remote is not merely disabled at runtime — the unit that would
add it is gone before the image ships.
