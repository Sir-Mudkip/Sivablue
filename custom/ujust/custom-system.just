# vim: set ft=make :
#######################
### custom-system.just
#######################
## Example system configuration commands
## These are simplified examples adapted from Bluefin

[group('System')]
get-dotfiles:
    #!/usr/bin/env bash
    source /usr/lib/ujust/ujust.sh
    git clone https://github.com/Sir-Mudkip/dotfiles $HOME/dotfiles
    echo "To install these dotfiles, simply run \`./dotfiles/install.sh\`" | glow

[group('System')]
pull-hashcat:
    #!/usr/bin/env bash
    source /usr/lib/ujust/ujust.sh
    distrobox create --nvidia --name hashcat-cuda --no-entry -Y --image ghcr.io/sir-mudkip/hashcat-distrobox:latest
    export PATH="$HOME/.local/bin:$PATH"
    echo "To use hashcat like a local binary, run the following commands in order:"
    echo "\`distrobox enter hashcat-cuda\`" | glow
    echo "\`distrobox-export --bin /usr/bin/hashcat\`" | glow

[group('System')]
pull-seclists:
    #!/usr/bin/env bash
    source /usr/lib/ujust/ujust.sh
    mkdir -p $HOME/toolkit/
    git clone --depth 1 https://github.com/danielmiessler/SecLists.git $HOME/toolkit/seclists
    tar -xzvf $HOME/toolkit/seclists/Passwords/Leaked-Databases/rockyou.txt.tar.gz -C $HOME/toolkit/seclists/Passwords/Leaked-Databases/
    echo "Seclists and Rockyou are ready to be used"

[group('System')]
install-clipboard-indicator:
    #!/usr/bin/env bash
    source /usr/lib/ujust/ujust.sh
    git clone https://github.com/Tudmotu/gnome-shell-extension-clipboard-indicator.git "$HOME"/.local/share/gnome-shell/extensions/clipboard-indicator@tudmotu.com
    dconf write /org/gnome/shell/extensions/clipboard-indicator/toggle-menu "['<Super>v']"
    echo "installed - you need to log out and back in for the extention to be registered"
    echo "you can then enable with gnome-extensions enable clipboard-indicator@tudmotu.com"

[group('System')]
setup-gnome:
    #!/usr/bin/env bash
    source /usr/lib/ujust/ujust.sh
    # workspace shortcuts
    dconf write /org/gnome/desktop/wm/keybindings/move-to-workspace-1 "['<Super><Shift>1']"
    dconf write /org/gnome/desktop/wm/keybindings/move-to-workspace-2 "['<Super><Shift>2']"
    dconf write /org/gnome/desktop/wm/keybindings/move-to-workspace-3 "['<Super><Shift>3']"
    dconf write /org/gnome/desktop/wm/keybindings/move-to-workspace-4 "['<Super><Shift>4']"
    dconf write /org/gnome/desktop/wm/keybindings/move-to-workspace-5 "['<Super><Shift>5']"
    dconf write /org/gnome/desktop/wm/keybindings/move-to-workspace-6 "['<Super><Shift>6']"
    dconf write /org/gnome/desktop/wm/keybindings/switch-to-workspace-1 "['<Super>1']"
    dconf write /org/gnome/desktop/wm/keybindings/switch-to-workspace-2 "['<Super>2']"
    dconf write /org/gnome/desktop/wm/keybindings/switch-to-workspace-3 "['<Super>3']"
    dconf write /org/gnome/desktop/wm/keybindings/switch-to-workspace-4 "['<Super>4']"
    dconf write /org/gnome/desktop/wm/keybindings/switch-to-workspace-5 "['<Super>5']"
    dconf write /org/gnome/desktop/wm/keybindings/switch-to-workspace-6 "['<Super>6']"

    # fixed number of workspaces at 6
    dconf write /org/gnome/mutter/dynamic-workspaces false
    dconf write /org/gnome/desktop/wm/preferences/num-workspaces 6

    # disable application switching shortcuts
    dconf write /org/gnome/shell/keybindings/switch-to-application-1 "['']"
    dconf write /org/gnome/shell/keybindings/switch-to-application-2 "['']"
    dconf write /org/gnome/shell/keybindings/switch-to-application-3 "['']"
    dconf write /org/gnome/shell/keybindings/switch-to-application-4 "['']"
    dconf write /org/gnome/shell/keybindings/switch-to-application-5 "['']"
    dconf write /org/gnome/shell/keybindings/switch-to-application-6 "['']"
    dconf write /org/gnome/shell/keybindings/switch-to-application-7 "['']"
    dconf write /org/gnome/shell/keybindings/switch-to-application-8 "['']"
    dconf write /org/gnome/shell/keybindings/switch-to-application-9 "['']"

    # auto screen lock disable
    dconf write /org/gnome/desktop/screensaver/lock-enabled false

    # night light
    dconf write /org/gnome/settings-daemon/plugins/color/night-light-enabled true
    dconf write /org/gnome/settings-daemon/plugins/color/night-light-schedule-automatic true

    # Reset app grid to alphabetical order
    gsettings reset org.gnome.shell app-picker-layout

# Run a system benchmark (requires stress-ng from Homebrew)
[group('System')]
benchmark:
    #!/usr/bin/env bash
    source /usr/lib/ujust/ujust.sh
    if ! type -P "stress-ng" &>/dev/null ; then
        echo "stress-ng is not installed."
        if command -v brew &>/dev/null; then
            if gum confirm "Install stress-ng via Homebrew?" ; then
                brew install stress-ng
                brew link stress-ng
            else
                exit 0
            fi
        else
            echo "Please install stress-ng to run benchmarks."
            exit 1
        fi
    fi
    echo 'Running a 1 minute benchmark...'
    pushd $(mktemp -d) > /dev/null
    stress-ng --matrix 0 -t 1m --times
    popd > /dev/null

# Clean up container images and volumes
[group('Maintenance')]
clean-containers:
    #!/usr/bin/bash
    echo "Cleaning up Podman containers, images, and volumes..."
    podman system prune -af
    podman volume prune -f
    echo "Cleanup complete!"

# Update system and reboot if needed
[group('Maintenance')]
update-and-reboot:
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh
    echo "Updating system..."
    sudo bootc upgrade
    if gum confirm "Reboot now to apply updates?"; then
        systemctl reboot
    else
        echo "Reboot later to apply updates."
    fi
