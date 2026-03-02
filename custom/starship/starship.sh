#!/usr/bin/bash
# Starship prompt initialisation
export STARSHIP_CONFIG=/etc/starship.toml
if command -v starship &>/dev/null; then
    eval "$(starship init bash)"
fi
