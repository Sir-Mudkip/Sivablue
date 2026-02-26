# vim: set ft=make :
#######################
### custom-system.just
#######################
## Example system configuration commands
## These are simplified examples adapted from Bluefin

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

    # dark mode slate
    dconf write /org/gnome/desktop/interface/accent-color "'slate'"
    dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'"

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

    # unpin apps from dock
    dconf write /org/gnome/shell/favorite-apps "['Terminal']"

    # shortcuts for ptyxis and keepass
    dconf write /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3/']"
    dconf write /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/name "'Ptyxis'"
    dconf write /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/binding "'<Control><Alt>t'"
    dconf write /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/command "'/usr/bin/ptyxis --new-window'"
    dconf write /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/name "'KeePass'"
    dconf write /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/binding "'<Control><Alt>k'"
    dconf write /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/command "'flatpak run org.keepassxc.KeePassXC'"
    dconf write /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/name "'Gradia'"
    dconf write /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/binding "'F10'"
    dconf write /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/command "'flatpak run be.alexandervanhee.gradia --screenshot'"
    dconf write /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3/name "'Mission Center'"
    dconf write /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3/binding "'<Control><Shift>Escape'"
    dconf write /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3/command "'flatpak run io.missioncenter.MissionCenter'"

    # window switcher
    dconf write /org/gnome/desktop/wm/keybindings/switch-windows "['<Alt>Tab']"

    # Add minimise button to apps
    gsettings set org.gnome.desktop.wm.preferences button-layout ':minimize,maximize,close'

    # Configure neovim
    mkdir -p ~/.config/nvim/
    git clone https://github.com/Sir-Mudkip/nvim.git ~/.config/nvim/
    
# Install Kali containers and shell aliases into user directory
[group('System')]
install-pentest-tools:
    #!/usr/bin/env bash
    source /usr/lib/ujust/ujust.sh
    echo "Installing Kali and Metasploit... be patient this may take a while"
    sudo podman pull ghcr.io/sir-mudkip/kali-base:latest
    sudo podman pull registry.gitlab.com/snotra.uk/containers/metasploit-framework:latest
    cp /usr/share/image-extras/kali.rc $HOME/.bashrc.d/
    cp /usr/share/image-extras/kali.rc $HOME/.bashrc.d/
    source $HOME/.bashrc
    echo "Kali and Metasploit are now properly aliased. Check .bashrc.d/ for aliases"

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

# Configure libvirt groups for development
[group('System')]
configure-dev-groups:
    #!/usr/bin/pkexec bash
    CURRENT_USER="{{ `id -un` }}"
    echo "Adding $CURRENT_USER to docker and libvirt groups..."

    # Ensure groups exist in /etc/group
    for group in libvirt; do
        if ! grep -q "^$group:" /etc/group; then
            echo "Adding $group to /etc/group"
            grep "^$group:" /usr/lib/group | tee -a /etc/group > /dev/null
        fi
        usermod -aG $group $CURRENT_USER
    done

    echo "Groups configured. Log out and back in for changes to take effect."

# Example toggle command with user choice
[group('System')]
toggle-example-feature:
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh
    echo "This is an example toggle command."
    echo "Current status: [check your status here]"
    OPTION=$(Choose "Enable" "Disable" "Cancel")
    case "$OPTION" in
        "Enable")
            echo "Enabling feature..."
            # Add your enable logic here
            ;;
        "Disable")
            echo "Disabling feature..."
            # Add your disable logic here
            ;;
        "Cancel")
            echo "No changes made."
            ;;
    esac

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
