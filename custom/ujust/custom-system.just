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

    # browser launch shortcut
    dconf write /org/gnome/settings-daemon/plugins/media-keys/www "['<Control><Alt>w']"
    dconf write /org/gnome/settings-daemon/plugins/media-keys/home "['<Super>e']"

    # shortcuts for ptyxis and keepass
    dconf write /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/']"
    dconf write /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/name "'Ptyxis'"
    dconf write /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/binding "'<Control><Alt>t'"
    dconf write /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/command "'/usr/bin/ptyxis --new-window'"
    dconf write /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/name "'KeePass'"
    dconf write /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/binding "'<Control><Alt>k'"
    dconf write /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/command "'flatpak run org.keepassxc.KeePassXC'"

    # window switcher
    dconf write /org/gnome/desktop/wm/keybindings/switch-windows "['<Alt>Tab']"

    # Add minimise button to apps
    gsettings set org.gnome.desktop.wm.preferences button-layout ':minimize,maximize,close'

[group('System')]
organise-gui:
    #!/usr/bin/env bash	
    echo "Organizing apps into folders"
    # Create folder structure
    dconf write /org/gnome/desktop/app-folders/folder-children "['Internet', 'Utilities', 'Graphics', 'System', 'Development', 'Media']"

    # Internet folder
    dconf write /org/gnome/desktop/app-folders/folders/Internet/name "'Internet'"
    dconf write /org/gnome/desktop/app-folders/folders/Internet/apps "['net.waterfox.waterfox.desktop', 'org.mozilla.Thunderbird.desktop', 'org.signal.Signal.desktop', 'org.qbittorrent.qBittorrent.desktop']"

    # Utilities folder
    dconf write /org/gnome/desktop/app-folders/folders/Utilities/name "'Utilities'"
    dconf write /org/gnome/desktop/app-folders/folders/Utilities/apps "['org.gnome.Calculator.desktop', 'org.gnome.Calendar.desktop', 'org.gnome.Characters.desktop', 'org.gnome.Contacts.desktop', 'org.gnome.DejaDup.desktop', 'org.gnome.FileRoller.desktop', 'org.gnome.Maps.desktop', 'org.gnome.Papers.desktop', 'org.gnome.SimpleScan.desktop', 'org.gnome.baobab.desktop', 'org.gnome.clocks.desktop', 'org.gnome.font-viewer.desktop']"

    # Graphics folder
    dconf write /org/gnome/desktop/app-folders/folders/Graphics/name "'Graphics'"
    dconf write /org/gnome/desktop/app-folders/folders/Graphics/apps "['com.github.PintaProject.Pinta.desktop', 'org.gnome.Loupe.desktop', 'page.codeberg.Imaginer.Refine.desktop', 'be.alexandervanhee.gradia.desktop']"

    # Media folder
    dconf write /org/gnome/desktop/app-folders/folders/Media/name "'Media'"
    dconf write /org/gnome/desktop/app-folders/folders/Media/apps "['com.github.rafostar.Clapper.desktop']"

    # System folder
    dconf write /org/gnome/desktop/app-folders/folders/System/name "'System'"
    dconf write /org/gnome/desktop/app-folders/folders/System/apps "['org.gnome.Connections.desktop', 'org.gnome.Firmware.desktop', 'com.github.tchx84.Flatseal.desktop', 'com.mattjakeman.ExtensionManager.desktop', 'io.github.flattool.Warehouse.desktop', 'io.github.flattool.Ignition.desktop', 'io.gitlab.adhami3310.Impression.desktop', 'io.github.fabrialberio.pinapp.desktop', 'ca.desrt.dconf-editor.desktop', 'org.kde.kleopatra.desktop', 'com.ranfdev.Distrobox.desktop']"

    # Development folder
    dconf write /org/gnome/desktop/app-folders/folders/Development/name "'Development'"
    dconf write /org/gnome/desktop/app-folders/folders/Development/apps "['com.sublimetext.three.desktop', 'me.iepure.devtoolbox.desktop', 'org.virt_manager.virt-viewer.desktop', 'io.github.kolunmi.Bazaar.desktop']"

    echo "Done! Apps organized into folders."

    # Make apps appear on first page
    echo "Ensuring apps appear on the first page"
    # Force layout order so folders + KeePassXC + Terminal land on page 1
    dconf write /org/gnome/shell/app-picker-layout "[{'Internet': <{'position': <0>}>, 'Utilities': <{'position': <1>}>, 'Graphics': <{'position': <2>}>, 'Media': <{'position': <3>}>, 'System': <{'position': <4>}>, 'Development': <{'position': <5>}>, 'org.keepassxc.KeePassXC.desktop': <{'position': <6>}>, 'Terminal': <{'position': <7>}>}]"

    echo "Gnome Setup and Organised!"

# Install Kali containers and shell aliases into user directory
[group('System')]
install-pentest-tools:
    #!/usr/bin/env bash
    source /usr/lib/ujust/ujust.sh
    sudo podman pull ghcr.io/sir-mudkip/kali-base:latest
    sudo podman pull registry.gitlab.com/snotra.uk/containers/metasploit-framework:latest
    echo "alias kali='sudo podman run --rm -it --security-opt label=disable --network host --privileged -v $HOME:$HOME ghcr.io/sir-mudkip/kali-base:latest'" > "$HOME/.bashrc.d/kali.rc"
    cat > "$HOME/.bashrc.d/msf.rc" << 'EOF'
podman-msf() {
	# if an argument is given to the function, use this as the name of the containers and persist the database container
	if [ "$1" ]; then

		# postgres
		sudo podman run \
			--security-opt label=disable \
			--name msf_"$1" \
			-p 127.0.0.1:5432:5432 \
			-e POSTGRES_PASSWORD=postgres \
			-e POSTGRES_USER=postgres \
			-e POSTGRES_DB="$1" \
			-d \
			docker.io/library/postgres:alpine

		# wait for db to fire up
		sleep 3

		# msfconsole
		sudo podman run \
			--security-opt label=disable \
			--privileged \
			--rm \
			-it \
			--network host \
			-v $PWD:/run/host \
			-v /tmp:/tmp \
			-e DATABASE_URL=postgres://postgres:postgres@127.0.0.1:5432/"$1" \
			-e MSF_UID=0 \
			registry.gitlab.com/snotra.uk/containers/metasploit-framework

	else

		# postgres
		sudo podman run \
			--name msf \
			--rm \
			-p 127.0.0.1:5432:5432 \
			-e POSTGRES_PASSWORD=postgres \
			-e POSTGRES_USER=postgres \
			-e POSTGRES_DB=msf \
			-d \
			docker.io/library/postgres:alpine

		# wait for db to fire up
		sleep 3

		# msfconsole
		sudo podman run \
			--security-opt label=disable \
			--privileged \
			--rm \
			-it \
			--network host \
			-v $PWD:/run/host \
			-v /tmp:/tmp \
			-e DATABASE_URL=postgres://postgres:postgres@127.0.0.1:5432/msf \
			-e MSF_UID=0 \
			registry.gitlab.com/snotra.uk/containers/metasploit-framework
	fi
}

podman-msf-connect() {
	# connect to existing db e.g podman-msf-connect customer1
	sudo podman run \
		--security-opt label=disable \
		--rm \
		-it \
		--network host \
		--privileged \
		-v /tmp:/tmp \
		-v $PWD:/run/host \
		-v /media/$USER/data:/media/$USER/data \
		-e DATABASE_URL=postgres://postgres:postgres@127.0.0.1:5432/"$1" \
		-e MSF_UID=0 \
		registry.gitlab.com/snotra.uk/containers/metasploit-framework
}
EOF

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
