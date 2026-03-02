#!/usr/bin/bash

set -eoux pipefail

###############################################################################
# Main Build Script
###############################################################################
# This script follows the @ublue-os/bluefin pattern for build scripts.
# It uses set -eoux pipefail for strict error handling and debugging.
###############################################################################

# Source helper functions
# shellcheck source=/dev/null
source /ctx/build/copr-helpers.sh

# Enable nullglob for all glob operations to prevent failures on empty matches
shopt -s nullglob

echo "Installing Tailscale"
# Enable and install tailscale
dnf config-manager addrepo --from-repofile=https://pkgs.tailscale.com/stable/fedora/tailscale.repo
dnf config-manager setopt tailscale-stable.enabled=0
dnf -y install --enablerepo='tailscale-stable' tailscale

echo "::group:: Install Packages"

# Install packages using dnf5
# Example: dnf5 install -y tmux

FEDORA_PACKAGES=(
    adwaita-fonts-all
    bash-color-prompt
    bootc
    ddcutil
    edk2-ovmf
    fastfetch
    gcc
    git-credential-libsecret
    gnome-tweaks
    gocryptfs
    igt-gpu-tools
    iwd
    just
    libvirt
    libvirt-nss
    lm_sensors
    make
    mesa-libGLU
    podman-compose
    podman-machine
    pulseaudio-utils
    python3-pip
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
    setools-console
    syncthing
    udica
    virt-manager
    virt-v2v
    virt-viewer
    wireguard-tools
    wl-clipboard
)

# Install all Fedora packages (bulk - safe from COPR injection)
echo "Installing ${#FEDORA_PACKAGES[@]} packages from Fedora repos..."
dnf -y install "${FEDORA_PACKAGES[@]}"

# Example using COPR with isolated pattern:
# copr_install_isolated "ublue-os/staging" package-name

echo "Installing Starship prompt"
copr_install_isolated "atim/starship" starship

echo "Back patching of flatpak"
dnf5 install -y dbus-x11
dnf -y copr enable ublue-os/flatpak-test
dnf -y copr disable ublue-os/flatpak-test
dnf -y --repo=copr:copr.fedorainfracloud.org:ublue-os:flatpak-test swap flatpak flatpak
dnf -y --repo=copr:copr.fedorainfracloud.org:ublue-os:flatpak-test swap flatpak-libs flatpak-libs
dnf -y --repo=copr:copr.fedorainfracloud.org:ublue-os:flatpak-test swap flatpak-session-helper flatpak-session-helper
dnf -y --repo=copr:copr.fedorainfracloud.org:ublue-os:flatpak-test install flatpak-debuginfo flatpak-libs-debuginfo flatpak-session-helper-debuginfo

# Packages to exclude - common to all versions
EXCLUDED_PACKAGES=(
    fedora-bookmarks
    fedora-chromium-config
    fedora-chromium-config-gnome
    firefox
    firefox-langpacks
    gnome-software
    gnome-system-monitor
    gnome-software-rpm-ostree
    podman-docker
)

# Remove excluded packages if they are installed
if [[ "${#EXCLUDED_PACKAGES[@]}" -gt 0 ]]; then
    readarray -t INSTALLED_EXCLUDED < <(rpm -qa --queryformat='%{NAME}\n' "${EXCLUDED_PACKAGES[@]}" 2>/dev/null || true)
    if [[ "${#INSTALLED_EXCLUDED[@]}" -gt 0 ]]; then
        dnf -y remove "${INSTALLED_EXCLUDED[@]}"
    else
        echo "No excluded packages found to remove."
    fi
fi

echo "::endgroup::"

echo "Custom build complete!"
