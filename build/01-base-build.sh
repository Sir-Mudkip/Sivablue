#!/usr/bin/bash

echo "Foundations"

# Image Identity
/ctx/build/00-image-info.sh

echo "::group:: Copy Custom Files"

# Copy Brewfiles to standard location
echo "Copying Brewfiles"
mkdir -p /usr/share/ublue-os/homebrew/
cp /ctx/custom/brew/*.Brewfile /usr/share/ublue-os/homebrew/

# Consolidate Just Files
echo "Consolidating Just files"
find /ctx/custom/ujust -iname '*.just' -exec printf "\n\n" \; -exec cat {} \; >> /usr/share/ublue-os/just/60-custom.just

# Mirror system tree into the image
echo "Mirroring system tree"
cp -rT /ctx/system/usr/ /usr/
cp -rT /ctx/system/etc/ /etc/

echo "::endgroup::"

echo "::group:: Building Image..."

# Install Packages
/ctx/build/10-packages.sh

# Install Extensions
/ctx/build/11-extensions.sh

# Overrides
/ctx/build/12-overrides-install.sh

# System Config
/ctx/build/20-sysconfig.sh

# Clean Scripts
/ctx/build/50-clean.sh

# Validate Repos
/ctx/build/55-validate-repos.sh

echo "::endgroup::"

echo "Finalising build"
