#!/usr/bin/bash

echo "::group:: ===$(basename "$0")==="

set -eoux pipefail

# We do not need anything here at all
rm -rf /usr/src
rm -rf /usr/share/doc
# Remove kernel-devel from rpmdb because all package files are removed from /usr/src
rpm --erase --nodeps kernel-devel

# Wallpaper Configs
rm /usr/share/glib-2.0/schemas/gschemas.compiled
glib-compile-schemas /usr/share/glib-2.0/schemas
