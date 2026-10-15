# vim: set ft=make :
####################
### custom-apps.just
####################

# Install a Flatpak application from Flathub
[group('Apps')]
install-flatpak APP_ID:
    #!/usr/bin/env bash
    echo "Installing {{ APP_ID }} from Flathub..."
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    flatpak install -y flathub {{ APP_ID }}

# Install VSCodium via Brew
[group('Apps')]
install-vscodium:
    brew tap ublue-os/tap
    brew install --cask vscodium-linux

# Install Burp Suite to ~/BurpSuite (Community, or Pro with a licence key)
[group('Apps')]
install-burpsuite CHANNEL="":
    #!/usr/bin/env bash
    set -euo pipefail
    channel="{{ CHANNEL }}"
    if [[ -z "${channel}" ]]; then
        channel=$(gum choose --header "Burp Suite release channel" "Stable" "Early Adopter")
    fi
    case "${channel}" in
        "Stable" | "Early Adopter") ;;
        *) echo "Unknown channel '${channel}' (expected Stable or Early Adopter)"; exit 1 ;;
    esac

    install_dir="${HOME}/BurpSuite"
    if [[ -e "${install_dir}" ]] && ! gum confirm "Burp Suite is already in ${install_dir}. Reinstall over it?"; then
        exit 0
    fi

    release=$(curl -fsSL "https://portswigger.net/burp/releases/data?lastId=-1&pageSize=20" |
        jq -r --arg ch "${channel}" 'first(.ResultSet.Results[]
            | select(.buildCategory == "desktop" and (.releaseChannels | index($ch)))
            | .builds[] | select(.BuildCategoryPlatform == "Linux"))
            | "\(.Version) \(.Sha256Checksum)"')
    if [[ -z "${release}" ]]; then
        echo "No ${channel} Linux release found in the PortSwigger release feed"; exit 1
    fi
    read -r version sha256 <<<"${release}"

    cache_root="${XDG_CACHE_HOME:-${HOME}/.cache}"
    mkdir -p "${cache_root}"
    cache_dir=$(mktemp -d "${cache_root}/burpsuite.XXXXXX")
    trap 'rm -rf "${cache_dir}"' EXIT
    installer="${cache_dir}/burpsuite_linux_v${version//./_}.sh"

    echo "Downloading Burp Suite ${version} (${channel})..."
    curl -fL --retry 3 -o "${installer}" \
        "https://portswigger.net/burp/releases/download?product=desktop&version=${version}&type=Linux"
    echo "${sha256}  ${installer}" | sha256sum -c -

    sh "${installer}" -q -overwrite -dir "${install_dir}"
    echo "Burp Suite ${version} installed to ${install_dir}"
    echo "Community runs without a licence; activate Pro with your licence key on first launch."
