###############################################################################
# Sivablue — see docs/ci.md for image identity and docs/build-stages.md for the
# build. Image name is set in build/00-image-info.sh.
###############################################################################

# Context stage - combine local and imported OCI container resources
ARG BASE_IMAGE="${BASE_IMAGE:-quay.io/fedora-ostree-desktops/silverblue:44}"
ARG BASE_IMAGE_NAME="silverblue"
FROM scratch AS ctx

COPY build /build
COPY system /system

# Copy from OCI containers to distinct subdirectories to avoid conflicts
# Base Image - GNOME included
FROM ${BASE_IMAGE} AS base

# Make /opt immutable
RUN rm /opt && mkdir /opt

### MODIFICATIONS
## make modifications desired in your image and install packages by modifying the build.sh script
## the following RUN directive does all the things required to run "build.sh" as recommended.

COPY --from=ghcr.io/ublue-os/brew:latest@sha256:bed056871da6edd8c6ee455a274283ae83bf269461dcad758a7729aaad018401 /system_files /
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /usr/bin/systemctl preset brew-setup.service && \
    /usr/bin/systemctl preset brew-update.timer && \
    /usr/bin/systemctl preset brew-upgrade.timer

FROM base AS final

ARG BASE_IMAGE_NAME="silverblue"
ARG IMAGE_NAME="sivablue"
ARG KERNEL_FLAVOR="${KERNEL_FLAVOR:-main}"
ARG FEDORA_VERSION="${FEDORA_VERSION:-44}"
ARG ARCHITECTURE="${ARCHITECTURE:-x86_64}"
ARG VARIANT="base"

# Set dnf options before build scripts (persists across subsequent RUN layers).
# Unlike the build.sh RUN below, this one has no /var/log cache mount, so dnf5's
# log would land in the image layer where 98-clean-stage.sh cannot reach it and
# `bootc container lint` flags it. Remove it in the same layer that creates it.
RUN dnf5 config-manager setopt keepcache=1 install_weak_deps=0 && \
    rm -f /var/log/dnf5.log

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build/build.sh

CMD ["/sbin/init"]

### LINTING
## Verify final image and contents are correct. --fatal-warnings promotes lint
## warnings (stray files in /run and /tmp, image hygiene) to build failures;
## 98-clean-stage.sh exists to keep the image clean enough to pass it.
RUN bootc container lint --fatal-warnings
