#!/usr/bin/bash

set -eoux pipefail

echo "::group:: ===$(basename "$0")==="

echo "Installing Waterfox"

# BrowserWorks publish for a specific Fedora release; follow the base image
# rather than pinning, so a rebase fails loudly here instead of silently
# installing against the wrong release.
WATERFOX_REPO="https://download.opensuse.org/repositories/isv:/BrowserWorks/Fedora_$(rpm -E %fedora)/isv:BrowserWorks.repo"

dnf5 config-manager addrepo --from-repofile="${WATERFOX_REPO}"
dnf5 config-manager setopt isv_BrowserWorks.enabled=0
dnf5 -y install --enablerepo=isv_BrowserWorks waterfox

# The package disables its own updater (app.update.enabled in package-prefs.js)
# but still probes for the default browser on every start.
mkdir -p /usr/lib/waterfox/distribution
tee /usr/lib/waterfox/distribution/policies.json <<'EOF'
{
    "policies": {
        "DontCheckDefaultBrowser": true
    }
}
EOF

# The package carries no scriptlets, so nothing refreshes the caches the base
# image already shipped; do it by hand or the icon and MIME associations do
# not resolve.
gtk-update-icon-cache -f /usr/share/icons/hicolor
update-desktop-database /usr/share/applications

# Waterfox bundles decoders for VP8/VP9/AV1 only; H.264 (avc1) and AAC come from
# the system ffmpeg, which on stock Fedora cannot decode H.264 at all. Without
# both installs below, avc1 video silently fails to play while av01 works.
echo "Installing H.264 codec support"

# Cisco's licensed build; obsoletes the noopenh264 stub that satisfies the same
# soname with a decoder whose WelsCreateDecoder() only ever returns an error.
dnf5 -y install --enablerepo=fedora-cisco-openh264 openh264 mozilla-openh264

# libavcodec-freeworld shadows libavcodec-free via ld.so.conf.d and carries the
# native H.264/HEVC decoders — the only ones that support VA-API hardware decode.
# The release RPM carries the key used to verify everything after it, so it alone
# cannot be signature-checked.
dnf5 -y install --nogpgcheck \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm"
for repo in /etc/yum.repos.d/rpmfusion-free*.repo; do
    if [[ -f "${repo}" ]]; then
        sed -i 's@^enabled=1@enabled=0@g' "${repo}"
    fi
done
dnf5 -y install \
    --enablerepo=rpmfusion-free --enablerepo=rpmfusion-free-updates \
    libavcodec-freeworld

# The loader cache is what decides libavcodec-free vs -freeworld at dlopen time.
ldconfig

echo "::endgroup::"
