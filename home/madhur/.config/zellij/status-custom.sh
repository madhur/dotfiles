#!/usr/bin/env bash
# Output one line (no trailing newline is best for zjstatus). Edit freely.
# Examples: git branch, battery, vpn status, kubectl context, etc.

printf '%s' "$(hostname -s)"
if [[ -r /proc/loadavg ]]; then
  read -r load _ </proc/loadavg
  printf ' | %s' "$load"
fi
