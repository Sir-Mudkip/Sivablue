#   Welcome to Sivablue!

The whole point of this OS to remove the massive headache of dealing with drivers, and reconfiguring a system when stuff goes south. The image comes with VM support, podman, and docker out the box. The following will get you setup quickly:

|  Command             |  Description |
|-----------------------|---------------------------------------|
| `ujust get-dotfiles`  | Pulls Creator Dotfiles|
| `ujust setup-gnome`   | Extra Gnome Windows |
| `ujust pull-seclists` | Pulls Seclists to `~/toolkit`|
| `ujust pull-hashcat`| Pulls Hashcat Container (Nvidia Images)|
| `ujust --choose`| Lists commands available |

Grab Kali and Metasploit:
`sudo podman pull ghcr.io/sir-mudkip/kali-base:latest`
`sudo podman pull ghcr.io/sir-mudkip/metasploit:latest`

Hide this message with:
`touch ~/.hushlogin`
