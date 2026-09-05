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
# Fetch the release RPM ourselves rather than handing dnf5 a URL. dnf5 caches a
# URL install under its @commandline repo and *appends* to an existing cache
# entry instead of truncating it, so the file grows by one copy per build and
# every build after the first fails with "not a rpm". Observed sizes were exact
# multiples of the real 11753 bytes. Since /var/cache is a build cache mount,
# that entry survives between builds and the failure looks intermittent.
RPMFUSION_RELEASE="/var/tmp/rpmfusion-free-release.rpm"
curl -fsSL --retry 3 --retry-delay 2 -o "${RPMFUSION_RELEASE}" \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm"
# --nogpgcheck below means nothing else validates this file; assert it parses as
# an RPM before installing, so a truncated or redirected download fails loudly.
rpm -qp "${RPMFUSION_RELEASE}" >/dev/null
dnf5 -y install --nogpgcheck "${RPMFUSION_RELEASE}"
rm -f "${RPMFUSION_RELEASE}"
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
