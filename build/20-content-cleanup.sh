#!/usr/bin/bash

echo "::group:: ===$(basename "$0")==="

set -eoux pipefail

# We do not need anything here at all
rm -rf /usr/src
rm -rf /usr/share/doc
# Remove kernel-devel from rpmdb because all package files are removed from /usr/src.
# Only present on the nvidia variant (pulled in by the akmods); on base there is
# nothing to erase, and an unconditional erase would abort this stage under set -e.
if rpm -q kernel-devel >/dev/null 2>&1; then
    rpm --erase --nodeps kernel-devel
fi

# Wallpaper Configs
rm /usr/share/glib-2.0/schemas/gschemas.compiled
glib-compile-schemas /usr/share/glib-2.0/schemas

echo "::endgroup::"
