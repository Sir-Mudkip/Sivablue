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
    dbus-x11
    ddcutil
    edk2-ovmf
    fastfetch
    flatpak-builder
    gcc
    git-credential-libsecret
    glow
    gnome-tweaks
    gocryptfs
    igt-gpu-tools
    iwd
    libvirt
    libvirt-nss
    lm_sensors
    make
    podman-compose
    podman-machine
    python3-pip
    p7zip
    p7zip-plugins
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
    swtpm-tools
    syncthing
    udica
    virt-manager
    virt-v2v
    virt-viewer
)

# Install all Fedora packages (bulk - safe from COPR injection)
echo "Installing ${#FEDORA_PACKAGES[@]} packages from Fedora repos..."
dnf -y install "${FEDORA_PACKAGES[@]}"

# Docker
# Apply IP Forwarding before installing Docker to prevent messing with LXC networking
sysctl -p
# Load iptable_nat module for docker-in-docker.
# See:
#   - https://github.com/ublue-os/bluefin/issues/2365
#   - https://github.com/devcontainers/features/issues/1235
mkdir -p /etc/modules-load.d
tee /etc/modules-load.d/ip_tables.conf <<EOF
iptable_nat
EOF

dnf config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo
sed -i "s/enabled=.*/enabled=0/g" /etc/yum.repos.d/docker-ce.repo
dnf -y install --enablerepo=docker-ce-stable \
    containerd.io \
    docker-buildx-plugin \
    docker-ce \
    docker-ce-cli \
    docker-compose-plugin \
    docker-model-plugin

# Flatpak
echo "Back patching of flatpak"
dnf -y copr enable ublue-os/flatpak-test
dnf -y copr disable ublue-os/flatpak-test
dnf -y --repo=copr:copr.fedorainfracloud.org:ublue-os:flatpak-test swap flatpak flatpak
dnf -y --repo=copr:copr.fedorainfracloud.org:ublue-os:flatpak-test swap flatpak-libs flatpak-libs
dnf -y --repo=copr:copr.fedorainfracloud.org:ublue-os:flatpak-test swap flatpak-session-helper flatpak-session-helper
dnf -y --repo=copr:copr.fedorainfracloud.org:ublue-os:flatpak-test install flatpak-debuginfo flatpak-libs-debuginfo flatpak-session-helper-debuginfo

# Example using COPR with isolated pattern:
# copr_install_isolated "ublue-os/staging" package-name

echo "Installing Nerd Fonts"
copr_install_isolated "che/nerd-fonts" "nerd-fonts"

echo "Installing uupd"
copr_install_isolated "ublue-os/packages" "uupd"

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
        dnf -y remove "${INSTALLED_EXCLUDED[@]}"
    else
        echo "No excluded packages found to remove."
    fi
fi

if [[ "${VARIANT}" == nvidia ]]; then
    dnf5 -remove -y \
        nvidia-gpu-firmware \
        rocm-hip \
        rocm-opencl \
        rocm-clinfo \
        rocm-smi
fi

echo "All packages installed"

echo "::endgroup::"

