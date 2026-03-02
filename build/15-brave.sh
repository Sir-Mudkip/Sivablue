#!/usr/bin/bash

set -eoux pipefail

echo "Installing Brave"

dnf5 -y install dnf-plugins-core

dnf5 config-manager addrepo --from-repofile=https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo

ls -l /etc/yum.repos.d/

dnf5 -y install brave-browser
