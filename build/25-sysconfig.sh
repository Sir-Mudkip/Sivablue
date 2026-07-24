#!/usr/bin/bash

set -eoux pipefail

echo "::group:: ==$(basename "$0")=="

# Disable + mask a unit so nothing (not even a dep) can start it
mask_unit() {
    for unit in "$@"; do
        systemctl disable "$unit" || true
        systemctl mask "$unit" || true
    done
}

echo "Disabling unwanted services"
mask_unit \
    cups.socket cups.service cups-browsed.service \
    avahi-daemon.socket avahi-daemon.service \
    ModemManager.service \
    sssd.service sssd-kcm.service sssd-kcm.socket \
    geoclue.service

echo "Disabling superseded timers"
systemctl disable rpm-ostreed-automatic.timer

# Tailscale is opt-in: off at boot but not masked, so it can be started on demand
echo "Disabling opt-in daemons"
systemctl disable tailscaled.service

echo "Enabling system services"
systemctl enable \
    podman.socket \
    docker.socket \
    dconf-update.service \
    set-hostname.service \
    auto-groups.service \
    libvirtd \
    swtpm-workaround.service \
    libvirt-workaround.service \
    flatpak-nuke-fedora.service \
    brew-setup.service \
    uupd.timer \
    rpm-ostree-countme.timer \
    tailscale-operator.service

systemctl --global enable \
    podman-auto-update.timer \
    sivablue-user-setup.service

# Load swtpm SELinux policy modules so restorecon can label /usr/bin/swtpm correctly at boot
echo "Installing swtpm SELinux modules"
semodule -i \
    /usr/share/selinux/packages/swtpm.pp \
    /usr/share/selinux/packages/swtpm_libvirt.pp \
    /usr/share/selinux/packages/swtpm_svirt.pp

echo "::endgroup::"
