#!/usr/bin/bash
# Starship prompt initialisation
if command -v starship &>/dev/null; then
    eval "$(starship init bash)"
fi
