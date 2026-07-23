#!/usr/bin/bash

set -eoux pipefail

###############################################################################
# Main Build Script
###############################################################################

# Source helper functions
# shellcheck source=/dev/null
source /ctx/build/copr-helpers.sh

# Enable nullglob for all glob operations to prevent failures on empty matches
shopt -s nullglob

echo "::group:: ===$(basename "$0")==="

# Install packages using dnf5
# Example: dnf5 install -y tmux

echo "Main Packages"

FEDORA_PACKAGES=(
    adwaita-fonts-all
    adw-gtk3-theme
    bash-color-prompt
    bootc
    curl
    distrobox
    ddcutil
    flatpak-builder
    fastfetch
    fzf
    gcc
    glow
    gnome-tweaks
    gocryptfs
    gum
    htop
    igt-gpu-tools
    iwd
    just
    libvirt
    libvirt-nss
    lm_sensors
    make
    openssl
    net-tools
    nvme-cli
    nvtop
    podman-compose
    podman-machine
    python3-pip
    p7zip
    p7zip-plugins
    pipx
    qemu
    qemu-char-spice
    qemu-device-display-virtio-gpu
    qemu-device-display-virtio-vga
    qemu-device-usb-redirect
    qemu-img
    qemu-system-x86-core
    qemu-user-binfmt
    qemu-user-static
    ripgrep
    swtpm-tools
    tmux
    vagrant
    virt-manager
    virt-v2v
    virt-viewer
    wireguard-tools
    wl-clipboard
)

# Install all Fedora packages (bulk - safe from COPR injection)
echo "Installing ${#FEDORA_PACKAGES[@]} packages from Fedora repos..."
dnf5 -y install "${FEDORA_PACKAGES[@]}"

# Example using COPR with isolated pattern:
# copr_install_isolated "ublue-os/staging" package-name

echo "Installing Nerd Fonts"
copr_install_isolated "che/nerd-fonts" "nerd-fonts"

echo "Installing uupd"
copr_install_isolated "ublue-os/packages" "uupd"

echo "Installing Ghostty"
copr_install_isolated "scottames/ghostty" "ghostty"

# Packages to exclude - common to all versions
EXCLUDED_PACKAGES=(
    dnf-data
    dracut-config-rescue
    fedora-bookmarks
    fedora-chromium-config
    fedora-chromium-config-gnome
    firefox
    firefox-langpacks
    gnome-extensions-app
    gnome-shell-extension-background-logo
    gnome-software
    gnome-software-rpm-ostree
    gnome-system-monitor
    mozilla-fira-mono-fonts
    iptables-services
    iptables-utils
    PackageKit-command-not-found
    podman-docker
    rsyslog
)

# Remove excluded packages if they are installed
if [[ "${#EXCLUDED_PACKAGES[@]}" -gt 0 ]]; then
    readarray -t INSTALLED_EXCLUDED < <(rpm -qa --queryformat='%{NAME}\n' "${EXCLUDED_PACKAGES[@]}" 2>/dev/null || true)
    if [[ "${#INSTALLED_EXCLUDED[@]}" -gt 0 ]]; then
        dnf5 -y remove "${INSTALLED_EXCLUDED[@]}"
    else
        echo "No excluded packages found to remove."
    fi
fi

if [[ "${VARIANT}" == nvidia ]]; then
    dnf5 remove -y \
        nvidia-gpu-firmware \
        rocm-hip \
        rocm-opencl \
        rocm-clinfo \
        rocm-smi
fi

echo "All packages installed"

echo "::endgroup::"

