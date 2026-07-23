#!/usr/bin/bash

source /usr/lib/sivablue/setup-services/libsetup.sh

version-script waterfox user 1 || exit 0

set -x

# Waterfox moved from a Flatpak to a system binary, but the Flatpak kept its
# profile inside its sandboxed HOME, so the system build starts on an empty
# ~/.waterfox and the user appears to have lost everything.

FLATPAK_PROFILE="$HOME/.var/app/net.waterfox.waterfox/.waterfox"
SYSTEM_PROFILE="$HOME/.waterfox"

# Nothing to migrate on a fresh install, or for anyone who never had the Flatpak
if test ! -d "$FLATPAK_PROFILE"; then
    echo "No Flatpak Waterfox profile found, nothing to migrate"
    exit 0
fi

# Never clobber a profile the user has already built up on the system binary
if test -d "$SYSTEM_PROFILE" && test -n "$(ls -A "$SYSTEM_PROFILE" 2>/dev/null)"; then
    echo "$SYSTEM_PROFILE already exists and is not empty, leaving it alone"
    echo "The old Flatpak profile is still at $FLATPAK_PROFILE if you want it"
    exit 0
fi

echo "Migrating Waterfox profile from the Flatpak sandbox to $SYSTEM_PROFILE"

# Copy rather than move: if this goes wrong, or the user rolls the image back to
# a build that still had the Flatpak, the original is untouched.
mkdir -p "$SYSTEM_PROFILE"
cp -a "$FLATPAK_PROFILE/." "$SYSTEM_PROFILE/"

# A running Waterfox leaves these behind and they confuse a fresh start
rm -f "$SYSTEM_PROFILE"/*/.parentlock "$SYSTEM_PROFILE"/*/lock

echo "Migrated Waterfox profile to $SYSTEM_PROFILE"
echo "The Flatpak copy has been left at $FLATPAK_PROFILE and can be removed with:"
echo "  flatpak uninstall --delete-data net.waterfox.waterfox"
