#!/usr/bin/bash

echo "::group:: Copy Custom Files"

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

# Install Docker
/ctx/build/06-docker.sh

# Install Tailscale
/ctx/build/07-tailscale.sh

# Install VSCode
/ctx/build/08-vscode.sh

# Install Packages
/ctx/build/10-packages.sh

# Install Waterfox
/ctx/build/12-waterfox.sh

# Install AirVPN Eddie
/ctx/build/13-eddie.sh

# Install Extensions
/ctx/build/15-extensions.sh

# Content Cleanup
/ctx/build/20-content-cleanup.sh

# System Config
/ctx/build/25-sysconfig.sh

# Initramfs Regeneration
/ctx/build/30-initramfs.sh

# Overrides
/ctx/build/96-overrides.sh

# Validate Repos
/ctx/build/97-validate-repos.sh

# Clean Stage
/ctx/build/98-clean-stage.sh

# Tests
/ctx/build/99-tests.sh

echo "::endgroup::"

echo "Finalising build"
