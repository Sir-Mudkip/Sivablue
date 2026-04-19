#!/usr/bin/bash

echo "::group:: System Configuration"

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

echo "Enabling system services"
systemctl enable \
    podman.socket \
    docker.socket \
    podman-auto-update.timer \
    flatpak-preinstall.service \
    dconf-update.service \
    set-hostname.service \
    tailscaled \
    tailscale-operator.service \
    auto-groups.service \
    libvirtd \
    swtpm-workaround.service \
    libvirt-workaround.service \
    flatpak-nuke-fedora.service \
    brew-setup.service \
    input-remapper.service \
    rpm-ostree-countme.service \
    ublue-system-setup.service \
    uupd.timer

echo "Enabling per-user services"
systemctl --global enable \
    podman-auto-update.timer \
    ublue-user-setup.service

# Load swtpm SELinux policy modules so restorecon can label /usr/bin/swtpm correctly at boot
echo "Installing swtpm SELinux modules"
semodule -i \
    /usr/share/selinux/packages/swtpm.pp \
    /usr/share/selinux/packages/swtpm_libvirt.pp \
    /usr/share/selinux/packages/swtpm_svirt.pp

echo "::endgroup::"
