#!/usr/bin/bash

echo "::group:: Copy Custom Files"

# Copy Brewfiles to standard location
echo "Copying Brewfiles"
mkdir -p /usr/share/ublue-os/homebrew/
cp /ctx/custom/brew/*.Brewfile /usr/share/sivablue/homebrew/

# Consolidate Just Files
echo "Consolidating Just files"
find /ctx/custom/ujust -iname '*.just' -exec printf "\n\n" \; -exec cat {} \; >> /usr/share/ublue-os/just/60-custom.just

# Mirror system tree into the image
echo "Mirroring system tree"
cp -rT /ctx/system/usr/ /usr/
cp -rT /ctx/system/etc/ /etc/

echo "::endgroup::"

echo "::group:: Building Image..."

# Image Identity
/ctx/build/00-image-info.sh

# Nvidia Akmods
/ctx/build/05-kernel-akmods.sh

# Install Packages
/ctx/build/10-packages.sh

# Install Extensions
/ctx/build/15-extensions.sh

# Overrides
/ctx/build/20-overrides-install.sh

# System Config
/ctx/build/25-sysconfig.sh

# Initramfs Regeneration
/ctx/build/30-initramfs.sh

# Clean Scripts
/ctx/build/35-clean.sh

# Validate Repos
/ctx/build/40-validate-repos.sh

# Clean Stage
/ctx/build/45-clean-stage.sh

# Tests
/ctx/build/50-tests.sh

echo "::endgroup::"

echo "Finalising build"
