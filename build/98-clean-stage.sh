#!/usr/bin/bash

echo "::group:: ===$(basename "$0")==="

set -eoux pipefail

# Revert back to upstream defaults
dnf5 config-manager setopt keepcache=0
dnf5 versionlock clear

systemctl mask flatpak-add-fedora-repos.service
rm -f /usr/lib/systemd/system/flatpak-add-fedora-repos.service

rm -rf /.gitkeep
find /var/* -maxdepth 0 -type d \! -name cache -exec rm -fr {} \;
find /var/cache/* -maxdepth 0 -type d \! -name libdnf5 \! -name rpm-ostree -exec rm -fr {} \;
rm -rf /tmp && mkdir -p /tmp
# /run is a tmpfs at runtime, so anything baked into the image here is junk.
# podman bind-mounts .containerenv, secrets and systemd into /run for the
# duration of the build RUN; those cannot be removed and are not part of the
# committed layer. Clear what can be cleared and tolerate the rest, rather than
# letting a busy mount fail the stage.
find /run -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
# /boot is repopulated by the bootc install; emptying it here is deliberate.
# shellcheck disable=SC2114
rm -rf /boot && mkdir -p /boot

echo "::endgroup::"
