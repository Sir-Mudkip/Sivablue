# vim: set ft=make :
####################
### custom-apps.just
####################
## Example application installation commands
## These are simplified examples adapted from Bluefin

# Install all Brewfiles at once
[group('Apps')]
install-brew-tools:
    #!/usr/bin/env bash
    echo "Installing all applications from Brewfiles..."
    brew bundle --file /usr/share/sivablue/homebrew/default.Brewfile
    brew bundle --file /usr/share/sivablue/homebrew/development.Brewfile
    brew bundle --file /usr/share/sivablue/homebrew/fonts.Brewfile
    brew bundle --file /usr/share/sivablue/homebrew/gui.Brewfile

# Install a Flatpak application from Flathub
[group('Apps')]
install-flatpak APP_ID:
    #!/usr/bin/bash
    echo "Installing {{ APP_ID }} from Flathub..."
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    flatpak install -y flathub {{ APP_ID }}

# Example: Install VSCode via Flatpak
[group('Apps')]
install-vscodium:
    brew tap ublue-os/tap
    brew install --cask vscodium-linux
