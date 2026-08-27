#!/usr/bin/bash

set -eoux pipefail

echo "::group:: ===$(basename "$0")==="

echo "Building Ghostty from source"

# Ghostty publishes a rolling "tip" prerelease, so no release is ever marked
# latest and the releases/latest endpoint 404s. Resolve from tags instead.
GHOSTTY_VERSION="$(/ctx/build/ghcurl \
    "https://api.github.com/repos/ghostty-org/ghostty/tags?per_page=100" \
    | jq -r '.[].name' \
    | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' \
    | sed 's/^v//' \
    | sort -V \
    | tail -n1 || true)"

# Refuse to build against a bad API response rather than silently shipping
# a stale or wrong terminal.
if [[ ! "${GHOSTTY_VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "ERROR: unexpected Ghostty version from GitHub API: '${GHOSTTY_VERSION}'"
    exit 1
fi

echo "Building Ghostty ${GHOSTTY_VERSION}"

# /tmp is a tmpfs mount in the build RUN, and the Zig cache runs to several GB.
BUILD_DIR="/var/tmp/ghostty-build"
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

BUILD_DEPS=(
    gettext
    gtk4-devel
    gtk4-layer-shell-devel
    libadwaita-devel
    minisign
    ncurses
    pkgconf-pkg-config
)

# Only remove what this stage actually added; anything the base image already
# carried stays put.
readarray -t PREINSTALLED < <(rpm -qa --queryformat='%{NAME}\n' "${BUILD_DEPS[@]}" 2>/dev/null || true)
dnf5 -y install "${BUILD_DEPS[@]}"

GHOSTTY_TARBALL="${BUILD_DIR}/ghostty-${GHOSTTY_VERSION}.tar.gz"
GHOSTTY_BASE_URL="https://release.files.ghostty.org/${GHOSTTY_VERSION}/ghostty-${GHOSTTY_VERSION}.tar.gz"

curl -fsSL --retry 3 --retry-delay 5 -o "${GHOSTTY_TARBALL}" "${GHOSTTY_BASE_URL}"
curl -fsSL --retry 3 --retry-delay 5 -o "${GHOSTTY_TARBALL}.minisig" "${GHOSTTY_BASE_URL}.minisig"

# https://ghostty.org/docs/install/build - upstream's minisign signing key.
GHOSTTY_MINISIGN_KEY="RWQlAjJC23149WL2sEpT/l0QKy7hMIFhYdQOFy0Z7z7PbneUgvlsnYcV"
minisign -V -P "${GHOSTTY_MINISIGN_KEY}" \
    -m "${GHOSTTY_TARBALL}" \
    -x "${GHOSTTY_TARBALL}.minisig"

tar -xf "${GHOSTTY_TARBALL}" -C "${BUILD_DIR}"
GHOSTTY_SRC="${BUILD_DIR}/ghostty-${GHOSTTY_VERSION}"

# Each Ghostty release builds with exactly one Zig version and Fedora ships a
# different one, so the toolchain comes from ziglang.org. Reading the required
# version out of the source keeps the Zig side rolling too.
ZIG_VERSION="$(grep -oE '\.minimum_zig_version[[:space:]]*=[[:space:]]*"[0-9]+\.[0-9]+\.[0-9]+"' \
    "${GHOSTTY_SRC}/build.zig.zon" \
    | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"

if [[ ! "${ZIG_VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "ERROR: could not read minimum_zig_version from build.zig.zon"
    exit 1
fi

echo "Ghostty ${GHOSTTY_VERSION} requires Zig ${ZIG_VERSION}"

ZIG_INDEX="${BUILD_DIR}/zig-index.json"
curl -fsSL --retry 3 --retry-delay 5 -o "${ZIG_INDEX}" "https://ziglang.org/download/index.json"

ZIG_TARGET="$(uname -m)-linux"
ZIG_URL="$(jq -r --arg v "${ZIG_VERSION}" --arg t "${ZIG_TARGET}" '.[$v][$t].tarball // empty' "${ZIG_INDEX}")"
ZIG_SHA="$(jq -r --arg v "${ZIG_VERSION}" --arg t "${ZIG_TARGET}" '.[$v][$t].shasum // empty' "${ZIG_INDEX}")"

if [[ -z "${ZIG_URL}" || -z "${ZIG_SHA}" ]]; then
    echo "ERROR: no Zig ${ZIG_VERSION} build for ${ZIG_TARGET}"
    exit 1
fi

ZIG_TARBALL="${BUILD_DIR}/zig.tar.xz"
curl -fsSL --retry 3 --retry-delay 5 -o "${ZIG_TARBALL}" "${ZIG_URL}"
echo "${ZIG_SHA}  ${ZIG_TARBALL}" | sha256sum -c -

ZIG_DIR="${BUILD_DIR}/zig"
mkdir -p "${ZIG_DIR}"
tar -xf "${ZIG_TARBALL}" -C "${ZIG_DIR}" --strip-components=1

# Keep both Zig caches inside the scratch dir; the default lands in /root/.cache
# and would be committed to the image.
export ZIG_GLOBAL_CACHE_DIR="${BUILD_DIR}/zig-global-cache"
export ZIG_LOCAL_CACHE_DIR="${BUILD_DIR}/zig-local-cache"
export PATH="${ZIG_DIR}:${PATH}"

zig version

# -p /usr lays out the full FHS install: binary, terminfo, shell integration,
# icons and GTK shortcuts. See docs/filesystem-layout.md.
#
# -Dversion-string is not optional here: the build derives its version from git,
# and a release tarball is not a repository, so without it Ghostty reports
# itself as a "-dev" build on the tip channel rather than the stable release
# it actually is.
#
# -Dcpu pins the ISA floor to Fedora's own baseline. Zig otherwise detects the
# builder's CPU and bakes those features in. See docs/build-stages.md.
cd "${GHOSTTY_SRC}"
zig build -p /usr \
    -Doptimize=ReleaseFast \
    -Dcpu=x86_64_v2 \
    -Dversion-string="${GHOSTTY_VERSION}" \
    --summary all
cd /

# The toolchain and headers must not reach the image, so drop them before this
# layer closes.
TO_REMOVE=()
for package in "${BUILD_DEPS[@]}"; do
    if ! printf '%s\n' "${PREINSTALLED[@]:-}" | grep -qx "${package}"; then
        TO_REMOVE+=("${package}")
    fi
done

if [[ "${#TO_REMOVE[@]}" -gt 0 ]]; then
    dnf5 -y remove "${TO_REMOVE[@]}"
fi

rm -rf "${BUILD_DIR}"

echo "::endgroup::"
