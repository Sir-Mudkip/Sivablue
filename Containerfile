###############################################################################
# PROJECT NAME CONFIGURATION
###############################################################################
# Name: sivablue
#
# IMPORTANT: Change "finpilot" above to your desired project name.
# This name should be used consistently throughout the repository in:
#   - Justfile: export image_name := env("IMAGE_NAME", "your-name-here")
#   - README.md: # your-name-here (title)
#   - artifacthub-repo.yml: repositoryID: your-name-here
#   - custom/ujust/README.md: localhost/your-name-here:stable (in bootc switch example)
#
# The project name defined here is the single source of truth for your
# custom image's identity. When changing it, update all references above
# to maintain consistency.
###############################################################################

###############################################################################
# MULTI-STAGE BUILD ARCHITECTURE
###############################################################################
# This Containerfile follows the Bluefin architecture pattern as implemented in
# @projectbluefin/distroless. The architecture layers OCI containers together:
#
# 1. Context Stage (ctx) - Combines resources from:
#    - Local build scripts and custom files
#    - @projectbluefin/common - Desktop configuration shared with Aurora 
#    - @ublue-os/brew - Homebrew integration
#
# 2. Base Image Options:
#    - `ghcr.io/ublue-os/silverblue-main:latest` (Fedora and GNOME)
#    - `ghcr.io/ublue-os/base-main:latest` (Fedora and no desktop 
#    - `quay.io/centos-bootc/centos-bootc:stream10 (CentOS-based)` 
#
# See: https://docs.projectbluefin.io/contributing/ for architecture diagram
###############################################################################

# Context stage - combine local and imported OCI container resources
ARG BASE_IMAGE="${BASE_IMAGE:-ghcr.io/ublue-os/silverblue-main:latest}"
ARG KERNEL_FLAVOR="${KERNEL_FLAVOR:-main}"
ARG FEDORA_VERSION="${FEDORA_VERSION:-43}"
ARG ARCHITECTURE="${ARCHITECTURE:-x86_64}"
ARG VARIANT="base"

FROM scratch AS ctx

COPY build /build
COPY custom /custom
COPY system /system

# Import nvidia akmods prior to setting base stage
FROM ghcr.io/ublue-os/akmods-nvidia-open:${KERNEL_FLAVOR}-${FEDORA_VERSION}-${ARCHITECTURE} AS nvidia-akmods

# Copy from OCI containers to distinct subdirectories to avoid conflicts
# Base Image - GNOME included
FROM ghcr.io/ublue-os/silverblue-main:latest AS base
ARG VARIANT
ARG FEDORA_VERSION

# Make /opt immutable
RUN rm /opt && mkdir /opt

# Import nvidia akmods

### MODIFICATIONS
## make modifications desired in your image and install packages by modifying the build.sh script
## the following RUN directive does all the things required to run "build.sh" as recommended.

# Copy Homebrew files from the brew image
# And enable
COPY --from=ghcr.io/ublue-os/brew:latest /system_files /
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /usr/bin/systemctl preset brew-setup.service && \
    /usr/bin/systemctl preset brew-update.timer && \
    /usr/bin/systemctl preset brew-upgrade.timer

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build/01-base-build.sh

# Nvidia Stage
FROM base AS nvidia
# Remove conflicting packages
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    dnf5 -y remove \
        nvidia-gpu-firmware \
        rocm-hip \
        rocm-opencl \
        rocm-clinfo \
        rocm-smi || true

# Install Nvidia drivers
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=bind,from=nvidia-akmods,src=/rpms,dst=/tmp/akmods-rpms \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=secret,id=GITHUB_TOKEN \
    /ctx/build/ghcurl "https://raw.githubusercontent.com/ublue-os/main/refs/heads/main/build_files/nvidia-install.sh" --retry 3 -Lo /tmp/nvidia-install.sh && \
    chmod +x /tmp/nvidia-install.sh && \
    IMAGE_NAME="${IMAGE_NAME}" /tmp/nvidia-install.sh && \
    rm -f /usr/share/vulkan/icd.d/nouveau_icd.*.json && \
    ln -s libnvidia-ml.so.1 /usr/lib64/libnvidia-ml.so && \
    /ctx/build/50-clean.sh

FROM ${VARIANT} AS final

### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
