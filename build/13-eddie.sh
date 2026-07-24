#!/usr/bin/bash

set -eoux pipefail

echo "::group:: ===$(basename "$0")==="

echo "Installing AirVPN Eddie"

# GitHub's "latest" release endpoint excludes prereleases, so experimental
# builds are skipped. The tag maps directly onto the eddie.website RPM path.
EDDIE_VERSION="$(/ctx/build/ghcurl \
    "https://api.github.com/repos/AirVPN/Eddie/releases/latest" \
    | jq -r '.tag_name')"
EDDIE_VERSION="${EDDIE_VERSION#v}"

# Refuse to build against a bad API response rather than silently shipping
# a broken or stale client.
if [[ ! "${EDDIE_VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "ERROR: unexpected Eddie version from GitHub API: '${EDDIE_VERSION}'"
    exit 1
fi

echo "Installing Eddie ${EDDIE_VERSION}"

EDDIE_URL="https://eddie.website/repository/eddie/${EDDIE_VERSION}/eddie-ui_${EDDIE_VERSION}_linux_x64_fedora.rpm"

EDDIE_RPM="$(mktemp -t eddie-XXXXXX.rpm)"
curl -fsSL --retry 3 --retry-delay 5 -o "${EDDIE_RPM}" "${EDDIE_URL}"

# Upstream ships the RPM outside any repo, so verify it is a real RPM here
# (a truncated download or HTML error page fails the build rather than dnf).
rpm -qp "${EDDIE_RPM}" >/dev/null

dnf5 -y install "${EDDIE_RPM}"
rm -f "${EDDIE_RPM}"

echo "::endgroup::"
