#!/usr/bin/bash
# Welcome message for first boot
# Create ~/.hushlogin to suppress this message
[ -f "$HOME/.hushlogin" ] && return 0
glow /etc/profile.d/welcome.md
