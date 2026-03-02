#!/usr/bin/bash

set -eoux pipefail

echo "::group:: ===$(basename "$0")==="

# Install tooling
dnf5 -y install glib2-devel meson sassc cmake dbus-devel

# Dash to Dock
make -C /usr/share/gnome-shell/extensions/dash-to-dock@micxgx.gmail.com
glib-compile-schemas --strict /usr/share/gnome-shell/extensions/dash-to-dock@micxgx.gmail.com/schemas

# Logo Menu
install -Dpm0755 -t /usr/bin /usr/share/gnome-shell/extensions/logomenu@aryan_k/distroshelf-helper
install -Dpm0755 -t /usr/bin /usr/share/gnome-shell/extensions/logomenu@aryan_k/missioncenter-helper
glib-compile-schemas --strict /usr/share/gnome-shell/extensions/logomenu@aryan_k/schemas

# Compile Gschemas
rm /usr/share/glib-2.0/schemas/gschemas.compiled
glib-compile-schemas /usr/share/glib-2.0/schemas

# Cleanup
dnf5 -y remove glib2-devel meson sassc cmake dbus-devel
rm -rf /usr/share/gnome-shell/extensions/tmp
