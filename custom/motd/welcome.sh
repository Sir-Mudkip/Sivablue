#!/usr/bin/bash
# Welcome message for first boot
# Create ~/.hushlogin to suppress this message
[ -f "$HOME/.hushlogin" ] && return 0
cat /etc/misc.d/welcome.md
