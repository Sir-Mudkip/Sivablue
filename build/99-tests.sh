#!/usr/bin/bash

echo "::group:: ===$(basename "$0")==="

set -eoux pipefail

# We need to have the ublue-os signing keys on the image!
# Published images without these keys won't be able to pull ghcr.io/ublue-os/*
# and can therefore not update!
# https://github.com/ublue-os/main/blob/963609eaf01f7c2bb1a76821fe6d0ec269d2df25/build_files/install.sh#L56
# https://github.com/ublue-os/packages/tree/1f77c7e7faa9ebad120609a10d79e0412376c3b7/packages/ublue-os-signing/src

KEY1=$(jq -r '.transports.docker."ghcr.io/ublue-os"[0].keyPaths[0]' /etc/containers/policy.json)
BACKUP_KEY=$(jq -r '.transports.docker."ghcr.io/ublue-os"[0].keyPaths[1]' /etc/containers/policy.json)
KEY1_SHA256="af78ecfda6eb21c35195af3739341715e9cfc3f2f5911dd9c10b0670547bf6e8"
BACKUP_KEY_SHA256="b723467015ba562d40b4645c98c51c65d8254bb59444f6e9962debcfe2315da0"

echo "${KEY1_SHA256}  ${KEY1}" | sha256sum -c -
echo "${BACKUP_KEY_SHA256}  ${BACKUP_KEY}" | sha256sum -c -

for i in bin/ujust share/sivablue/just/{apps.just,system.just,utils.just,fetch.just,utils.just,entry.just} ; do
   stat /usr/$i
done

# Waterfox is a tarball install, so rpm -q cannot vouch for it
test -x /usr/lib/waterfox/waterfox
test -x /usr/bin/waterfox
test -f /usr/share/applications/waterfox.desktop
test -f /usr/share/icons/hicolor/128x128/apps/waterfox.png
/usr/bin/waterfox --version

# Waterfox decodes avc1 through the system ffmpeg, and rpm -q cannot tell a real
# decoder from the noopenh264 stub that satisfies the same soname. Assert the
# native h264 decoder actually resolves, or avc1 video silently fails to play.
test -s /usr/lib64/ffmpeg/libavcodec.so.62
if ! ffmpeg -hide_banner -decoders 2>/dev/null | awk '$2 == "h264" { f = 1 } END { exit !f }'; then
    echo "No native h264 decoder: avc1 video will not play... Exiting"; exit 1
fi

# fastfetch config and its SIVA logo are staged from system/, so rpm -q cannot vouch for them
test -f /etc/fastfetch/config.jsonc
# The logo is a pre-rendered coloured-braille text file printed via file-raw (no
# image libraries involved); this is the actual asset the config renders.
test -f /usr/share/fastfetch/logos/sivablue.txt

# If this file is not on the image bazaar will automatically be removed from users systems :(
# See: https://docs.flatpak.org/en/latest/flatpak-command-reference.html#flatpak-preinstall
test -f /usr/share/flatpak/preinstall.d/default.preinstall

# Basic smoke test to check if the flatpak version is from our copr
flatpak preinstall --help

# Make sure this garbage nerer makes it to an image
test -f /usr/lib/systemd/system/flatpak-add-fedora-repos.service && false

IMPORTANT_PACKAGES=(
    distrobox
    flatpak
    libavcodec-freeworld
    openh264
    ptyxis
    gdm
    systemd
    tailscale
    uupd
    eddie-ui
)

for package in "${IMPORTANT_PACKAGES[@]}"; do
    rpm -q "${package}" >/dev/null || { echo "Missing package: ${package}... Exiting"; exit 1 ; }
done

# these packages are supposed to be removed
# and are considered footguns
UNWANTED_PACKAGES=(
    firefox
    gnome-software
    gnome-software-rpm-ostree
    noopenh264
    podman-docker
)

for package in "${UNWANTED_PACKAGES[@]}"; do
    if rpm -q "${package}" >/dev/null 2>&1; then
        echo "Unwanted package found: ${package}... Exiting"; exit 1
    fi
done

if [[ "${VARIANT}" =~ nvidia ]]; then
  NV_PACKAGES=(
      libnvidia-container-tools
      kmod-nvidia
      nvidia-driver-cuda
)
  for package in "${NV_PACKAGES[@]}"; do
      rpm -q "${package}" >/dev/null || { echo "Missing NVIDIA package: ${package}... Exiting"; exit 1 ; }
  done
fi

IMPORTANT_UNITS=(
    rpm-ostree-countme.timer
    uupd.timer
  )

for unit in "${IMPORTANT_UNITS[@]}"; do
    if ! systemctl is-enabled "$unit" 2>/dev/null | grep -q "^enabled$"; then
        echo "${unit} is not enabled"
        exit 1
    fi
done

echo "::endgroup::"
