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

# A kernel-tools version bump can arrive without the matching kernel-core,
# leaving a /usr/lib/modules/<kver>/ tree with no kernel behind it.
# akmods-ostree-post iterates every entry in that directory and fails on those,
# so drop any tree whose kernel-core is not installed. Runs before
# 30-initramfs.sh, which resolves the kernel version from the rpm database.
for kver_dir in /usr/lib/modules/*/; do
    kver="$(basename "${kver_dir}")"
    if ! rpm -q "kernel-core-${kver}" >/dev/null 2>&1; then
        echo "Removing orphan /usr/lib/modules/${kver} (no matching kernel-core)"
        rm -rf "${kver_dir}"
    fi
done

# Wallpaper Configs
rm /usr/share/glib-2.0/schemas/gschemas.compiled
glib-compile-schemas /usr/share/glib-2.0/schemas

echo "::endgroup::"
