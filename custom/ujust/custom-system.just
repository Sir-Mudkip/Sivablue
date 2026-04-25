# vim: set ft=make :
#######################
### custom-system.just
#######################
## Example system configuration commands
## These are simplified examples adapted from Bluefin
# Run a system benchmark (requires stress-ng from Homebrew)

[group('System')]
toggle-passwordless:
    #!/usr/bin/env bash
    source /usr/lib/ujust/ujust.sh
    PASSWORDLESS="/etc/sudoers.d/wheel-nopasswd"
    if [ -f "$PASSWORDLESS" ]; then
        if ! gum confirm "Passwordless Sudo is currently enabled. Would you like to disable it?"; then
            echo "Cancelling Operation"
            exit 0
        fi
        sudo rm "$PASSWORDLESS"
        echo "Sudoless Passwordless Disbaled"
    else if ! gum confirm "WARNING: CONFIGURING THIS CAN BE A SECURITY RISK. IF AN ATTACKER CAN ACCESS YOUR USER, THEN CAN RUN ANYTHING AS ROOT. Are you sure you want to continue?"; then
            echo "Cancelling Operation"
            exit 0
        fi
        echo "You will need to enter a password for this"
        sudo echo '%wheel ALL=(ALL) NOPASSWD: ALL' | sudo tee "$PASSWORDLESS" > /dev/null
        sudo chmod 0440 "$PASSWORDLESS"
        sudo visudo -c -f "$PASSWORDLESS"
        echo "Passwordless Sudo Enabled. ENSURE YOU'RE UPDATED AND HAVE A STRONG PASSWORD"
    fi

[group('System')]
benchmark:
    #!/usr/bin/env bash
    source /usr/lib/ujust/ujust.sh
    if ! type -P "stress-ng" &>/dev/null ; then
        echo "stress-ng is not installed."
        if command -v brew &>/dev/null; then
            if gum confirm "Install stress-ng via Homebrew?" ; then
                brew install stress-ng
                brew link stress-ng
            else
                exit 0
            fi
        else
            echo "Please install stress-ng to run benchmarks."
            exit 1
        fi
    fi
    echo 'Running a 1 minute benchmark...'
    pushd $(mktemp -d) > /dev/null
    stress-ng --matrix 0 -t 1m --times
    popd > /dev/null

# Clean up container images and volumes
[group('Maintenance')]
clean-containers:
    #!/usr/bin/bash
    echo "Cleaning up Podman containers, images, and volumes..."
    podman system prune -af
    podman volume prune -f
    echo "Cleanup complete!"

# Update system and reboot if needed
[group('Maintenance')]
update-and-reboot:
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh
    echo "Updating system..."
    sudo bootc upgrade
    if gum confirm "Reboot now to apply updates?"; then
        systemctl reboot
    else
        echo "Reboot later to apply updates."
    fi
