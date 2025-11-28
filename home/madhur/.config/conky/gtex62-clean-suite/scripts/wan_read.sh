#!/usr/bin/env bash
f="$HOME/.cache/conky/scripts/wan_ip"
v="$(tr -d '\r\n' < "$f" 2>/dev/null)"
[ -n "$v" ] && printf '%s\n' "$v" || printf '(resolving…)\n'
