#!/usr/bin/bash
# MOTD launcher. Real rendering lives in /usr/bin/sivablue-motd.
# Create ~/.hushlogin to suppress.

case $- in *i*) ;; *) return 0 ;; esac
[ -t 1 ] || return 0
[ -f "$HOME/.hushlogin" ] && return 0

command -v sivablue-motd >/dev/null 2>&1 && sivablue-motd
