# ujust

User-facing commands live in `system/usr/share/sivablue/just/*.just` and are
surfaced to users by the `ujust` command (`entry.just` imports each file;
see `filesystem-layout.md` for how `system/` reaches `/usr/`).

The current files are `apps.just`, `system.just`, `utils.just`,
`fetch.just`, and `entry.just` itself.

This page covers what is specific to this repository. Generic `just`
syntax — recipe parameters, dependencies, string interpolation — is
documented better by the
[Just Manual](https://just.systems/man/en/) than it would be by repeating
it here.

## Renaming breaks the build

`build/99-tests.sh` stats each recipe file by name, not by globbing the
directory:

```bash
for i in bin/ujust share/sivablue/just/{apps.just,system.just,utils.just,fetch.just,utils.just,entry.just} ; do
   stat /usr/$i
done
```

Renaming, removing, or adding a `.just` file without updating this list
either fails the build (a missing name) or leaves a new file untested (not
added to the list). Keep the two in sync.

## Writing a recipe

```just
# Toggle Welcome Msg
[group('Maintenance')]
toggle-welcome:
    #!/usr/bin/env bash
    if [ -f "$HOME/.hushlogin" ]; then
        rm -f "$HOME/.hushlogin"
    else
        touch "$HOME/.hushlogin"
    fi
```

The `[group('…')]` attribute controls how `ujust --list` sections the
recipe. Multi-line recipes need their own shebang line — this repository
uses `#!/usr/bin/env bash` throughout the existing `.just` files.

`source /usr/lib/ujust/ujust.sh` provides `Choose()` and `Confirm()` helper
functions for interactive prompts. `gum` is also available directly for
confirmations, spinners, and similar prompts — see `system.just` and
`fetch.just` for examples of both.

## Naming

Recipe names use a verb prefix that says what the recipe does:
`install-`, `configure-`, `setup-`, `toggle-`, `fix-`.

## Do not install packages in a recipe

The image is immutable and `/usr` is read-only at runtime, so a recipe
cannot `dnf5 install` anything into the base system. Package installation
happens once, at build time, in `build/10-packages.sh`.

At runtime, a recipe may install software through channels designed for
it: Flatpaks (`flatpak install`), Homebrew (`brew install`), or a
distrobox/toolbox container. See `apps.just`'s `install-flatpak` and
`install-vscodium` recipes for the pattern.
