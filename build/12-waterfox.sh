#!/usr/bin/bash

set -eoux pipefail

echo "::group:: ===$(basename "$0")==="

WATERFOX_PREFIX="/usr/lib/waterfox"

# GitHub's "latest" release endpoint excludes prereleases, so betas are skipped.
WATERFOX_VERSION="$(/ctx/build/ghcurl \
    "https://api.github.com/repos/BrowserWorks/Waterfox/releases/latest" \
    | jq -r '.tag_name')"

# Refuse to build against a bad API response rather than silently shipping
# a broken or stale browser.
if [[ ! "${WATERFOX_VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "ERROR: unexpected Waterfox version from GitHub API: '${WATERFOX_VERSION}'"
    exit 1
fi

echo "Installing Waterfox ${WATERFOX_VERSION}"

WATERFOX_URL="https://cdn.waterfox.com/waterfox/releases/${WATERFOX_VERSION}/Linux_x86_64/waterfox-${WATERFOX_VERSION}.tar.bz2"

# tar needs the bzip2 binary for -j; it is not guaranteed in the base image.
INSTALLED_BZIP2=0
if ! command -v bzip2 >/dev/null 2>&1; then
    dnf5 -y install bzip2
    INSTALLED_BZIP2=1
fi

WATERFOX_TARBALL="$(mktemp -t waterfox-XXXXXX.tar.bz2)"
curl -fsSL --retry 3 --retry-delay 5 -o "${WATERFOX_TARBALL}" "${WATERFOX_URL}"

# Upstream ships no checksums or signatures alongside the CDN artifacts, so
# there is nothing to verify against beyond HTTPS. Sanity-check the archive
# instead so a truncated or HTML error page fails the build here.
tar -tjf "${WATERFOX_TARBALL}" >/dev/null

rm -rf "${WATERFOX_PREFIX}"
mkdir -p "${WATERFOX_PREFIX}"
tar -xjf "${WATERFOX_TARBALL}" -C "${WATERFOX_PREFIX}" --strip-components=1
rm -f "${WATERFOX_TARBALL}"

test -x "${WATERFOX_PREFIX}/waterfox"

# Waterfox resolves its own libraries from the real path of the binary, so a
# plain symlink onto PATH is enough - no wrapper script needed.
ln -sf "${WATERFOX_PREFIX}/waterfox" /usr/bin/waterfox

# Disable the bundled updater: it cannot write to a read-only /usr, and leaving
# it on just nags the user about updates they cannot apply from inside the app.
mkdir -p "${WATERFOX_PREFIX}/distribution"
tee "${WATERFOX_PREFIX}/distribution/policies.json" <<'EOF'
{
    "policies": {
        "DisableAppUpdate": true,
        "DontCheckDefaultBrowser": true
    }
}
EOF

# Promote the bundled branding icons into hicolor so the desktop entry resolves.
for size in 16 22 24 32 48 64 128 256; do
    install -Dpm0644 \
        "${WATERFOX_PREFIX}/browser/chrome/icons/default/default${size}.png" \
        "/usr/share/icons/hicolor/${size}x${size}/apps/waterfox.png"
done

# GTK trusts the base image's hicolor icon-theme.cache and won't rescan for icons
# it predates, so Icon=waterfox stays invisible until the cache is rebuilt. rpm does
# this for packaged installs; a tarball must do it by hand.
gtk-update-icon-cache -f /usr/share/icons/hicolor
update-desktop-database /usr/share/applications

if [[ "${INSTALLED_BZIP2}" -eq 1 ]]; then
    dnf5 -y remove bzip2
fi

echo "Installed Waterfox ${WATERFOX_VERSION} to ${WATERFOX_PREFIX}"

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
