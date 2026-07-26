# Per-user setup

Hooks live in `system/usr/share/sivablue/user-setup.hooks.d/NN-name.sh` and
are run by `sivablue-user-setup`, a user service that iterates the
directory. **No registration is needed** — unlike build stages (see
`build-stages.md`), which must be named explicitly in `build/build.sh` or
they silently never run.

The service (`system/usr/lib/systemd/user/sivablue-user-setup.service`,
`WantedBy=graphical-session.target`) runs `/usr/bin/sivablue-user-setup`,
which loops over every file in the hooks directory and runs it with
`bash`. It is enabled globally in `build/25-sysconfig.sh` via:

```bash
systemctl --global enable sivablue-user-setup.service
```

`systemctl --global enable` enables the unit for every user on the system,
not just the user running the build, so it starts in each new graphical
session without any further per-user action.

## Hook boilerplate

```bash
source /usr/lib/sivablue/setup-services/libsetup.sh
version-script <name> user <n> || exit 0
```

`<name>` is a versioning tag (keep it stable across edits) and `<n>` is
the version number. Anything after this line is the hook body — it only
runs when `<n>` is higher than the version already recorded for
`<name>`.

## Versioning semantics

`version-script`, defined in
`system/usr/lib/sivablue/setup-services/libsetup.sh`, records the version
in `$HOME/.local/share/sivablue/setup_versioning.json` (overridable via
the `SETUP_CHECKER_FILE` environment variable) **before** the hook body
runs, not after. Concretely: if the recorded version already equals `<n>`,
the function returns 1 and `|| exit 0` stops the hook before the body
runs. Otherwise it writes `<n>` into the JSON file straight away and only
then returns 0, letting the rest of the script execute.

The consequence is that a hook which fails partway through is **never retried**
— its version was already marked done before the failure happened. This is
why hooks must be defensive and non-destructive: guard every step against a
partially-applied previous run, and never clobber existing user data on the
assumption that this is the first run.

To make an already-shipped hook run again for existing users (for example
because its logic changed), bump `<n>`. A new version number that nobody
has recorded yet makes `version-script` treat every user as needing the
update.

## Current hooks

- `10-vscode.sh` — copies the default VS Code `settings.json` into
  `$HOME/.config/Code/User` if none exists yet, then installs a fixed
  list of VS Code extensions.
- `30-gnome-extensions.sh` — merges the image's default-on GNOME
  extension UUIDs (parsed out of
  `zz0-sivablue-mods.gschema.override`) into the user's existing
  `enabled-extensions` dconf list, additively, so a migrated or
  pre-existing profile still picks up the shipped extensions without
  losing anything the user added or turned off.
