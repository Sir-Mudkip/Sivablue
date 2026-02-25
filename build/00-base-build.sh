#!usr/bin/bash

echo "Foundations"
echo "::group:: Copy Custom Files"

# Copy Brewfiles to standard location
mkdir -p /usr/share/ublue-os/homebrew/
cp /ctx/custom/brew/*.Brewfile /usr/share/ublue-os/homebrew/

# Consolidate Just Files
mkdir -p /usr/share/ublue-os/ujust/
find /ctx/custom/ujust -iname '*.just' -exec printf "\n\n" \; -exec cat {} \; >> /usr/share/ublue-os/just/60-custom.just

# Copy Flatpak Preinstall Service
cp /ctx/system/flatpak-preinstall.service /usr/lib/systemd/system/

# Copy Flatpak preinstall files
mkdir -p /etc/flatpak/preinstall.d/
cp /ctx/custom/flatpaks/*.preinstall /etc/flatpak/preinstall.d/

# Copy Aliases to standard location
mkdir -p /usr/share/ublue-os/aliases
cp /etc/custom/aliases/*.rc /usr/share/ublue-os/aliases

# Copy Motd / Setup
mkdir -p /etc/profile.d/
mkdir -p /etc/misc.d/
cp /ctx/custom/motd/welcome.sh /etc/profile.d/
cp /ctx/custom/motd/welcome.md /etc/misc.d/
chmod 644 /etc/misc.d/ript-welcome.md
chmod 755 /etc/profile.d/welcome.sh

# Copy Backgrounds
mkdir -p /usr/share/backgrounds/sivablue/
cp /ctx/custom/wallpapers/* /usr/share/backgrounds/sivablue/

# Copy Gnome Settings
mkdir -p /etc/dconf/db/distro.d/
cp /ctx/custom/gnome-settings/* /etc/dconf/db/distro.d/

echo "::endgroup::"

echo "::group:: Building Image..."

# Install Packages
/ctx/build/10-packages.sh

# Install Brave
/ctx/build/15-brave.sh

/ctx/build/20-sysconfig.sh

# Clean Scripts
/ctx/build/50-clean.sh

# Validate Repos
/ctx/build/55-validate-repos.sh

echo "::endgroup::"

echo "Finalising build"
