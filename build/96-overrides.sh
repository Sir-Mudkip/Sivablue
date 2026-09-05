#!/usr/bin/bash

echo "::group:: ===$(basename "$0")==="

set -eoux pipefail

# Prevent Distrobox containers from being updated via the background service.
# uupd ships /etc/uupd/config.json as %config(noreplace), so setting the flag
# there is the supported route and survives a package update; the previous
# approach patched ExecStart in a unit file whose own comment says not to.
uupd_config=$(mktemp)
jq '.modules.distrobox.disable = true' /etc/uupd/config.json >"${uupd_config}"
mv "${uupd_config}" /etc/uupd/config.json

# Hide Desktop Files. Hidden removes mime associations
for file in fish htop nvtop; do
    if [[ -f "/usr/share/applications/$file.desktop" ]]; then
        sed -i 's@\[Desktop Entry\]@\[Desktop Entry\]\nHidden=true@g' /usr/share/applications/"$file".desktop
    fi
done

#Add the Flathub Flatpak remote and remove the Fedora Flatpak remote
flatpak remote-add --system --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
systemctl disable flatpak-add-fedora-repos.service

# NOTE: With isolated COPR installation, most repos are never enabled globally.
# We only need to clean up repos that were enabled during the build process.

# Disable third-party repos
for repo in tailscale fedora-cisco-openh264; do
    if [[ -f "/etc/yum.repos.d/${repo}.repo" ]]; then
        sed -i 's@enabled=1@enabled=0@g' "/etc/yum.repos.d/${repo}.repo"
    fi
done

# dnf5 saves the BrowserWorks repo under the upstream file name, which carries
# a colon; glob for it rather than depending on the exact spelling.
for i in /etc/yum.repos.d/*BrowserWorks*.repo; do
    if [[ -f "$i" ]]; then
        sed -i 's@enabled=1@enabled=0@g' "$i"
    fi
done

# Disable all COPR repos (should already be disabled by helpers, but ensure)
for i in /etc/yum.repos.d/_copr:*.repo; do
    if [[ -f "$i" ]]; then
        sed -i 's@enabled=1@enabled=0@g' "$i"
    fi
done

# NOTE: we won't use dnf5 copr plugin for ublue-os/akmods until our upstream provides the COPR standard naming
if [[ -f "/etc/yum.repos.d/_copr_ublue-os-akmods.repo" ]]; then
    sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/_copr_ublue-os-akmods.repo
fi

# Disable RPM Fusion repos
for i in /etc/yum.repos.d/rpmfusion-*.repo; do
    if [[ -f "$i" ]]; then
        sed -i 's@enabled=1@enabled=0@g' "$i"
    fi
done

# Disable fedora-coreos-pool if it exists
if [ -f /etc/yum.repos.d/fedora-coreos-pool.repo ]; then
    sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/fedora-coreos-pool.repo
fi

echo "::endgroup::"
