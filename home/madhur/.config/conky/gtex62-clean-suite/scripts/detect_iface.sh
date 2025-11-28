#!/usr/bin/env bash
set -euo pipefail

CACHE="$HOME/.cache/conky"
OUT="$CACHE/iface"
mkdir -p "$CACHE"

iface=""

# Prefer the interface used to reach the internet
if cmd=$(ip route get 1.1.1.1 2>/dev/null); then
  iface=$(awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}' <<<"$cmd")
fi

# Fallbacks
if [ -z "${iface}" ]; then
  iface=$(ip route show default 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}' | head -n1)
fi
if [ -z "${iface}" ]; then
  iface=$(ip -o link show up 2>/dev/null | awk -F': ' '$2!="lo"{print $2; exit}')
fi

# Write cache (empty allowed)
printf '%s\n' "${iface}" > "$OUT"
# No stdout (Conky won't try to print anything)
exit 0


