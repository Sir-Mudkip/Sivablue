#!/usr/bin/bash

echo "::group:: System Configuration"

# Enable/disable systemd services
# systemctl enable podman.socket
# Example: systemctl mask unwanted-service
systemctl --global enable podman-auto-update.timer

echo "Disabling print services"
systemctl disable cups.socket
systemctl mask cups.socket
systemctl disable cups.service
systemctl mask cups.service
systemctl disable cups-browsed.service
systemctl mask cups-browsed.service

echo "Disabling avahi-daemon"
systemctl disable avahi-daemon.socket
systemctl mask avahi-daemon.socket
systemctl disable avahi-daemon.service
systemctl mask avahi-daemon.service

echo "Disabling the modem manager"
systemctl disable ModemManager.service
systemctl mask ModemManager.service

echo "Disabling the sssd daemons"
systemctl disable sssd.service
systemctl mask sssd.service
systemctl disable sssd-kcm.service
systemctl mask sssd-kcm.service
systemctl disable sssd-kcm.socket
systemctl mask sssd-kcm.socket

echo "Disabling the location service"
systemctl disable geoclue.service
systemctl mask geoclue.service

echo "Enabling Flatpak"
systemctl enable flatpak-preinstall.service

echo "Enabling dconf update on boot"
systemctl enable dconf-update.service

echo "Enabling first-boot hostname service"
systemctl enable set-hostname.service

echo "Enabling Tailscale"
systemctl enable --now tailscaled

echo "Enabling Tailscale operator setup"
systemctl enable tailscale-operator.service

echo "Enabling auto-groups"
systemctl enable auto-groups.service

echo "Enable Libvirt"
systemctl enable libvirtd

echo "Enable workarounds"
systemctl enable swtpm-workaround.service
systemctl enable libvirt-workaround.service
systemctl enable flatpak-nuke-fedora.service

# Load swtpm SELinux policy modules so restorecon can label /usr/bin/swtpm correctly at boot
semodule -i /usr/share/selinux/packages/swtpm.pp /usr/share/selinux/packages/swtpm_libvirt.pp /usr/share/selinux/packages/swtpm_svirt.pp

echo "::endgroup::"
