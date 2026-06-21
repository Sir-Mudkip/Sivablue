#!/usr/bin/bash

echo "::group:: ===$(basename "$0")==="

set -euox pipefail

# Nvidia AKMODS
if [[ "${VARIANT}" == nvidia ]]; then
    # Fetch Nvidia RPMs
    skopeo copy --retry-times 3 docker://ghcr.io/ublue-os/akmods-nvidia-open:"${KERNEL_FLAVOR}"-"${FEDORA_VERSION}"-"${ARCHITECTURE}" dir:/tmp/akmods-rpms
    NVIDIA_TARGZ=$(jq -r '.layers[].digest' </tmp/akmods-rpms/manifest.json | cut -d : -f 2)
    tar -xvzf /tmp/akmods-rpms/"$NVIDIA_TARGZ" -C /tmp/
    mv /tmp/rpms/* /tmp/akmods-rpms/

    # Exclude the Golang Nvidia Container Toolkit in Fedora Repo
    # Exclude for non-beta.... doesn't appear to exist for F42 yet?
    dnf5 config-manager setopt excludepkgs=golang-github-nvidia-container-toolkit

    # Install Nvidia RPMs
    IMAGE_NAME="${BASE_IMAGE_NAME}" AKMODNV_PATH="/tmp/akmods-rpms" MULTILIB=0 /tmp/akmods-rpms/ublue-os/nvidia-install.sh
    rm -f /usr/share/vulkan/icd.d/nouveau_icd.*.json
    ln -sf libnvidia-ml.so.1 /usr/lib64/libnvidia-ml.so
    tee /usr/lib/bootc/kargs.d/00-nvidia.toml <<EOF
kargs = ["rd.driver.blacklist=nouveau", "modprobe.blacklist=nouveau", "nvidia-drm.modeset=1", "initcall_blacklist=simpledrm_platform_driver_init"]
EOF

    # Install NVIDIA Container Toolkit for CDI-based GPU passthrough in Podman.
    # -base variant only: ships nvidia-ctk + nvidia-cdi-hook, no libnvidia-container,
    # no legacy OCI hook. CDI is the correct path for bootc/rootless containers.
    curl -fsSL https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo \
        | tee /etc/yum.repos.d/nvidia-container-toolkit.repo
    dnf5 -y install nvidia-container-toolkit-base
    # Configure for rootless Podman: no cgroup device delegation needed with CDI
    nvidia-ctk config --set nvidia-container-cli.no-cgroups --in-place
    # Remove the repo file from the final image
    rm -f /etc/yum.repos.d/nvidia-container-toolkit.repo
fi

echo "::endgroup::"
