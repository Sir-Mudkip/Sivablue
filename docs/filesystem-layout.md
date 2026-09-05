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
an installed system. Two Markdown files under `system/` are nonetheless
functional, not documentation, and must not be tidied away:
`system/etc/misc.d/hashcat-install.md` (rendered by `glow` from
`fetch.just:20` at the end of `ujust pull-hashcat`) and
`system/usr/share/sivablue/motd/welcome.md` (the MOTD body, below).

## `/usr` is read-only at runtime

The image is a bootc/ostree system, so `/usr` is read-only once booted.
Bundled self-updaters cannot write to it and must be disabled at build
time, or they will nag users about updates they have no way to apply from
inside the application.

Firefox-family applications need a `distribution/policies.json` with
`DisableAppUpdate` set. A properly packaged build usually does this for
itself — the Waterfox RPM sets `app.update.enabled=false` in its own
`defaults/pref/package-prefs.js` — but an unpackaged one will not, and
`build/12-waterfox.sh` writes that file regardless for the settings the
package leaves alone. Updates arrive via image rebuild plus `bootc upgrade`,
so "latest" means latest **at build time**, not at run time.

## Tarballs go to `/usr/lib`, not `/opt`

Tarball installs go under `/usr/lib/<name>`, with a symlink into
`/usr/bin` so the binary resolves on `PATH`. `/opt` is not available for
this: the `Containerfile` does `rm /opt && mkdir /opt` to make it
immutable, so nothing can be installed there.

No stage currently installs a tarball — `build/12-waterfox.sh` was the
reference implementation until Waterfox 6.7.0 gained an upstream RPM. The
shape it had is what to reproduce: extract to `/usr/lib/<name>`, symlink the
binary into `/usr/bin`, write the updater-disabling policy described above,
promote the bundled icons into the `hicolor` icon theme, and rebuild the icon
cache and desktop database by hand — all steps `rpm` would otherwise do for a
packaged install. `git show 5f39d95:build/12-waterfox.sh` has the full
version.

### Exception: builds that install an FHS tree

Ghostty is the one install that does not follow the rule above. `build/11-ghostty.sh`
runs `zig build -p /usr`, which spreads files across the prefix —
`/usr/bin/ghostty`, `/usr/share/ghostty/shell-integration`, the compiled
terminfo entry under `/usr/share/terminfo`, `/usr/share/applications/com.mitchellh.ghostty.desktop`,
hicolor icons and GTK shortcuts.

Confining that to `/usr/lib/ghostty` with a symlink would break it. Shell
integration, the terminfo database and the desktop entry are only found at
their real FHS paths, and upstream's `-p` flag is what wires them up. This is
the same layout an RPM would produce, which is what the previous COPR package
did produce — so it is not a special case so much as a package-shaped install
performed without a package.

The `/usr/lib/<name>` rule still applies to prebuilt tarballs, which ship a
self-contained application directory rather than an FHS tree.

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

## Units and helper binaries shipped from `system/`

These are the image's own units and scripts, as opposed to the packaged
ones (`podman.socket`, `docker.socket`, `libvirtd`, `brew-setup.service`,
`uupd.timer`, `rpm-ostree-countme.timer`) that `build/25-sysconfig.sh`
enables alongside them. All seven of the units in the table below are enabled
there; see `build-stages.md`. `uupd-on-ac.service` is the exception — it is
started by a udev rule rather than enabled, so it is listed separately.

`system/usr/lib/systemd/system/`:

| Unit | Does |
|---|---|
| `auto-groups.service` | Oneshot on `default.target` running `/usr/bin/auto-groups`; `Restart=on-failure` every 30s with `StartLimitIntervalSec=0`, so it retries until a wheel user exists. Ordered after `systemd-sysusers.service`, which creates the groups. |
| `dconf-update.service` | Runs `dconf update` at boot, compiling `/etc/dconf/db/distro.d/` into the binary database clients read (see `settings.md`). |
| `flatpak-nuke-fedora.service` | Deletes the `fedora` and `fedora-testing` Flatpak remotes and touches `/var/lib/flatpak/.fedora-initialized`; ordered before `flatpak-preinstall.service` so preinstalls resolve against Flathub. |
| `libvirt-workaround.service` | `restorecon -R` over `/var/log/libvirt/` and `/var/lib/libvirt/` to repair SELinux labels; both `ExecStart=` lines are `-`-prefixed, so failures do not fail the unit. |
| `set-hostname.service` | Sets the hostname to `Sivablue` on first boot only, guarded by `ConditionPathExists=!/etc/.hostname-set` and a matching `ExecStartPost` touch. |
| `swtpm-workaround.service` | Copies `/usr/bin/swtpm` into `/usr/local/bin/overrides` and bind-mounts it back over itself so `restorecon` can label it — `/usr` is read-only, so it cannot be relabelled in place. |
| `tailscale-operator.service` | `WantedBy=tailscaled.service`; runs `tailscale-operator-setup` once Tailscale is up. |

### Hardware enablement: `usr/lib/modprobe.d/`

| File | Does |
|---|---|
| `fw-charge-control.conf` | Sets `probe_with_fwk_charge_control=1` on `cros_charge_control` so the in-tree driver binds on Framework laptops, which is what creates the `charge_control_end_threshold` sysfs node battery charge limiting reads. Inert elsewhere — the module only loads where it binds. Asserted in `build/99-tests.sh`. |

Kernel module options belong here rather than `/etc/modprobe.d/`: `/etc` is the
administrator's, and this is the image's own hardware enablement. It needs no
initramfs regeneration, since `cros_charge_control` is a runtime power-supply
driver rather than something dracut pulls in.

### Update policy: `uupd` only on AC

Three files decide when background image updates run, and none of them is
enabled by `25-sysconfig.sh`:

| Path | Does |
|---|---|
| `usr/lib/systemd/system/uupd.service.d/10-sivablue.conf` | Adds `ConditionACPower=true`, so the scheduled run is skipped on battery. systemd treats the condition as met when the machine has no AC connector at all, so a desktop is unaffected. |
| `usr/lib/systemd/system/uupd-on-ac.service` | Oneshot that waits 60s for the network then starts `uupd.service`, catching up the skipped run. Rate-limited to once per six hours (`StartLimitBurst=1`, `StartLimitIntervalSec=21600`) so repeated plugging in does not mean repeated updating. Not enabled — started on demand. |
| `usr/lib/udev/rules.d/99-uupd-on-ac.rules` | Starts the above when a `Mains` supply comes online. `ACTION=="change"` keeps it from firing during boot device enumeration. |

`build/99-tests.sh` asserts all three, because they are staged from `system/`
and `rpm -q` vouches for none of them. Losing the drop-in silently means a
laptop updates on battery; losing either of the other two silently means the
skipped run is never caught up.

`system/usr/bin/`:

| Binary | Does |
|---|---|
| `auto-groups` | Adds every wheel member to the `docker` and `libvirt` groups, creating either group from `/usr/lib/group` first if `systemd-sysusers` has not yet. Exits 1 when wheel is still empty so the unit retries. Runs on **every** boot: `usermod -aG` is idempotent, and the state file it used to write meant a user added to wheel later never got the groups. |
| `sivablue-motd` | Renders the MOTD with `glow`, wrapped to `tput cols` when on a terminal; silently exits if `glow` or the template is missing. |
| `sivablue-user-setup` | Runs every hook in the user hooks directory; see `user-setup.md`. |
| `tailscale-operator-setup` | Sets the Tailscale operator to the first wheel user, so `tailscale` works without `sudo`. Version-stamped in `/etc/sivablue/tailscale-operator`. |
| `ujust` | One-line wrapper: `just --justfile /usr/share/sivablue/just/entry.just "$@"`. See `ujust.md`. |

### The MOTD path

`system/etc/profile.d/welcome.sh` runs on every interactive login shell. It
returns immediately for non-interactive shells, for a non-tty stdout, or if
`~/.hushlogin` exists; otherwise it calls `sivablue-motd`, which renders
`/usr/share/sivablue/motd/welcome.md`. `ujust toggle-welcome`
(`system.just:35`) is the user-facing switch — it creates or removes
`~/.hushlogin`. Editing the welcome text means editing that Markdown file;
nothing generates it.

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
