#!/usr/bin/bash

source /usr/lib/sivablue/setup-services/libsetup.sh

version-script vscode user 1 || exit 1

set -x

# Setup VSCode
if test ! -e "$HOME"/.config/Code/User/settings.json; then
	mkdir -p "$HOME"/.config/Code/User
	cp -f /etc/skel/.config/Code/User/settings.json "$HOME"/.config/Code/User/settings.json
fi

EXTENSIONS=(
    ms-vscode-remote.remote-containers
    ms-vscode-remote.remote-ssh
    ms-azuretools.vscode-containers
    ms-vscode.PowerShell
    ms-python.python
    yzhang.markdown-all-in-one
    redhat.vscode-yaml
    timonwong.shellcheck
    Postman.postman-for-vscode
    fabiospampinato.vscode-monokai-night
)

for e in "${EXTENSIONS[@]}"; do
    code --install-extension "$e" || true
done
