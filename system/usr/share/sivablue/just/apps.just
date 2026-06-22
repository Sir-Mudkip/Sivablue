# vim: set ft=make :
####################
### custom-apps.just
####################

# Install a Flatpak application from Flathub
[group('Apps')]
install-flatpak APP_ID:
    #!/usr/bin/env bash
    echo "Installing {{ APP_ID }} from Flathub..."
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    flatpak install -y flathub {{ APP_ID }}

# Install VSCodium via Brew
[group('Apps')]
install-vscodium:
    brew tap ublue-os/tap
    brew install --cask vscodium-linux
