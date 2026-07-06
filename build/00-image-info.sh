#!/usr/bin/bash

echo "::group:: ===$(basename "$0")==="

set -euox pipefail

# Constants
IMAGE_LIKE="fedora"
IMAGE_VENDOR="sir-mudkip"
IMAGE_TAG="stable"
BASE_IMAGE_NAME="silverblue"
HOME_URL="https://github.com/Sir-Mudkip/Sivablue"
DOCUMENTATION_URL="https://github.com/Sir-Mudkip/Sivablue"
SUPPORT_URL="https://github.com/Sir-Mudkip/Sivablue/issues/"
BUG_REPORT_URL="https://github.com/Sir-Mudkip/Sivablue/issues/"

# Version is always the date the image was built
VERSION="${VERSION:-$(date -u +%Y-%m-%d)}"

# From Containerfile ARGs: VARIANT, FEDORA_VERSION
FEDORA_VERSION="${FEDORA_VERSION:-}"

# Derive image name and pretty name from variant.
# IMAGE_NAME is the human-facing name; IMAGE_REPO is the lowercase registry path
# (OCI/GHCR repository names must be lowercase).
IMAGE_NAME="Sivablue"
IMAGE_PRETTY_NAME="Sivablue"
IMAGE_REPO="sivablue"
image_flavor="main"
if [[ "${VARIANT:-}" == "nvidia" ]]; then
  IMAGE_NAME="Sivablue-nvidia"
  IMAGE_PRETTY_NAME="Sivablue-nvidia"
  IMAGE_REPO="sivablue-nvidia"
  image_flavor="nvidia"
fi

IMAGE_INFO="/usr/share/ublue-os/image-info.json"
OS_RELEASE="/usr/lib/os-release"
IMAGE_REF="ostree-image-signed:docker://ghcr.io/${IMAGE_VENDOR}/${IMAGE_REPO}"

touch $IMAGE_INFO
cat >$IMAGE_INFO <<EOF
{
  "image-name": "$IMAGE_REPO",
  "image-flavor": "$image_flavor",
  "image-vendor": "$IMAGE_VENDOR",
  "image-ref": "$IMAGE_REF",
  "image-tag": "$IMAGE_TAG",
  "base-image-name": "$BASE_IMAGE_NAME",
  "fedora-version": "$FEDORA_VERSION"
}
EOF

if [[ -f "${OS_RELEASE}" ]] && ! grep -q "^VARIANT_ID=" "${OS_RELEASE}"; then
    # Version is always the build date
    OS_VERSION="${VERSION}"

    # Append our identity
    cat >>"${OS_RELEASE}" <<EOF

# ${IMAGE_NAME} image identity
VARIANT_ID="${image_flavor}"
PRETTY_NAME="${IMAGE_PRETTY_NAME}"
NAME="${IMAGE_NAME}"
IMAGE_ID="${IMAGE_NAME}"
IMAGE_VERSION="${OS_VERSION}"
ID_LIKE="${IMAGE_LIKE}"
HOME_URL="${HOME_URL}"
DOCUMENTATION_URL="${DOCUMENTATION_URL}"
SUPPORT_URL="${SUPPORT_URL}"
BUG_REPORT_URL="${BUG_REPORT_URL}"
EOF

fi

echo "::endgroup::"
