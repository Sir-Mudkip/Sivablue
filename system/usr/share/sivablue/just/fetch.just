# vim: set ft=make :
####################
### custom-fetch.just
####################

[group('Fetch')]
get-dotfiles:
    #!/usr/bin/env bash
    OPTION=$(gum choose --header "Which of the following dotfiles would you like to install?" "Personal" "Sir-Mudkip's" "None")
    if [[ $OPTION == "Personal" ]]; then
        DOTFILES=$(gum input --prompt "Specify your dotfiles path: " --placeholder "https://dotfiles.url")
        git -C $HOME clone $DOTFILES
        echo "Dotfiles installed in your home directory"
    elif [[ $OPTION == "Sir-Mudkip's" ]]; then
        git clone https://github.com/Sir-Mudkip/dotfiles $HOME/dotfiles
        echo "To install these dotfiles, simply run \`./dotfiles/install.sh\`" | glow
    else
        echo "Cancelling"
    fi

[group('Fetch')]
pull-hashcat:
    #!/usr/bin/env bash
    distrobox create --nvidia --name hashcat-cuda --no-entry -Y --image ghcr.io/sir-mudkip/hashcat-distrobox:latest
    export PATH="$HOME/.local/bin:$PATH"
    glow /etc/misc.d/hashcat-install.md

[group('Fetch')]
pull-seclists:
    #!/usr/bin/env bash
    mkdir -p $HOME/toolkit/
    git clone --depth 1 https://github.com/danielmiessler/SecLists.git $HOME/toolkit/seclists
    echo "Extracting rockyou.txt"
    tar -xzvf $HOME/toolkit/seclists/Passwords/Leaked-Databases/rockyou.txt.tar.gz -C $HOME/toolkit/seclists/Passwords/Leaked-Databases/
    glow /etc/misc.d/seclists-install.md

[group('Fetch')]
pull-kali:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "You will need to enter a password to complete this action"
    sudo podman pull ghcr.io/sir-mudkip/kali-base:latest

    echo "If you have not installed the provided dotfiles, Kali will not be aliased to run immediately"
    if ! gum confirm "Would you like to alias the Kali Container?"; then
        echo "Skipping alias configuration"
        exit 0
    fi

    curl -fsSL https://raw.githubusercontent.com/Sir-Mudkip/dotfiles/refs/heads/master/shell/bashrc.d/kali.rc > $HOME/.bashrc.d/kali.rc
    glow /etc/misc.d/kali-install.md

[group('Fetch')]
pull-metasploit:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "You will need to enter a password to complete this action"
    sudo podman pull ghcr.io/sir-mudkip/metasploit:latest
    sudo podman pull docker.io/library/postgres:alpine

    echo "If you have not installed the provided dotfiles, Metasploit will not be aliased to run immediately"
    if ! gum confirm "Would you like to alias the Metasploit Container?"; then
        echo "Skipping alias configuration"
        exit 0
    fi

    curl -fsSL https://raw.githubusercontent.com/Sir-Mudkip/dotfiles/refs/heads/master/shell/bashrc.d/msf.rc > $HOME/.bashrc.d/msf.rc
    glow /etc/misc.d/msf-install.md

[group('Fetch')]
pull-bloodhound:
    #!/usr/bin/env bash
    mkdir -p $HOME/.bashrc.d/
    mkdir -p $HOME/toolkit/bloodhound/
    curl -fsSL https://raw.githubusercontent.com/SpecterOps/BloodHound/refs/heads/main/examples/docker-compose/docker-compose.yml > $HOME/toolkit/bloodhound/docker-compose.yml
    curl -fsSL https://raw.githubusercontent.com/SpecterOps/BloodHound/refs/heads/main/examples/docker-compose/bloodhound.config.json > $HOME/toolkit/bloodhound/bloodhound.config.json
    curl -fsSL https://raw.githubusercontent.com/SpecterOps/BloodHound/refs/heads/main/examples/docker-compose/.env.example > $HOME/toolkit/bloodhound/.env.example
    curl -fsSL https://raw.githubusercontent.com/SpecterOps/BloodHound/refs/heads/main/examples/docker-compose/README.md > $HOME/toolkit/bloodhound/README.md
    glow /etc/misc.d/01-bloodhound-install.md

    PROMPT=$(gum choose --header "Would you like to alias with:" "Podman" "Docker" "Skip Alias Setup")
    case "$PROMPT" in
        "Podman")
            COMPOSE_CMD="podman-compose"
        ;;
        "Docker")
            COMPOSE_CMD="docker compose"
        ;;
        *)
            "echo Skipping Alias configuration"
            exit 0
        ;;
    esac
    echo "alias bloodhound-up=\"$COMPOSE_CMD -f \$HOME/toolkit/bloodhound/docker-compose.yml up -d\"" > $HOME/.bashrc.d/bloodhound.rc
    echo "alias bloodhound-down=\"$COMPOSE_CMD -f \$HOME/toolkit/bloodhound/docker-compose.yml down\"" >> $HOME/.bashrc.d/bloodhound.rc
    echo "alias bloodhound-logs=\"$COMPOSE_CMD -f \$HOME/toolkit/bloodhound/docker-compose.yml logs -f\"" >> $HOME/.bashrc.d/bloodhound.rc
    glow /etc/misc.d/02-bloodhound-install.md

[group('Fetch')]
install-clipboard-indicator:
    #!/usr/bin/env bash
    git clone https://github.com/Tudmotu/gnome-shell-extension-clipboard-indicator.git "$HOME"/.local/share/gnome-shell/extensions/clipboard-indicator@tudmotu.com
    dconf write /org/gnome/shell/extensions/clipboard-indicator/toggle-menu "['<Super>v']"
    echo "installed - you need to log out and back in for the extention to be registered"
    echo "you can then enable with gnome-extensions enable clipboard-indicator@tudmotu.com"

[group('Fetch')]
setup-gnome:
    #!/usr/bin/env bash
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
