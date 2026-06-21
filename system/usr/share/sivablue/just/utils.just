# vim: set ft=make :

uid := `id -u`
shell := `grep :$(id -u): /etc/passwd | cut -d: -f7`

[group('Maintenance')]
bios:
    #!/usr/bin/bash
    if [ ! -d /sys/firmware/efi ]; then
      echo "Rebooting to legacy BIOS from OS is not supported."
      exit 1
    fi

    if gum confirm "Reboot into BIOS?" ; then
      systemctl reboot --firmware-setup
    fi

# Show BIOS info
bios-info:
    #!/usr/bin/bash
    sudo bash <<'EOF'
    echo "Manufacturer: $(dmidecode -s baseboard-manufacturer)"
    echo "Product Name: $(dmidecode -s baseboard-product-name)"
    echo "Version: $(dmidecode -s bios-version)"
    echo "Release Date: $(dmidecode -s bios-release-date)"
    EOF

alias upgrade := update

# Update system, flatpaks and homebrew packages all at once
[group('Maintenance')]
update:
    #!/usr/bin/bash
    if systemctl cat -- uupd.timer &> /dev/null; then
        SERVICE="uupd.service"
    else
        SERVICE="rpm-ostreed-automatic.service"
    fi
    if systemctl is-active --quiet "$SERVICE"; then
        echo "automatic updates are currently running, use \`journalctl -fexu $SERVICE\` to see logs"
        exit 1
    fi
    if rpm-ostree status --booted 2>/dev/null | grep -q "Layered packages:"; then
        echo "Status: Layered Packages Detected"
        echo "Run an \`rpm-ostree reset\` and try again. This removes the Zero Maintenance guarantee, take appropriate precautions!"
        exit 1
    fi
    sudo bootc upgrade
    # Updates system Flatpaks
    if flatpak remotes | grep -q system; then
        flatpak update -y
    fi
    # Update user Flatpaks
    if flatpak remotes | grep -q user; then
        flatpak update --user -y
    fi
    # Guard Brew if the user does not own brew/doesn't exist
    if [[ -O /var/home/linuxbrew/.linuxbrew/bin/brew ]]; then
        # Upgrade will run brew update if needed
        /var/home/linuxbrew/.linuxbrew/bin/brew upgrade
    fi

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
