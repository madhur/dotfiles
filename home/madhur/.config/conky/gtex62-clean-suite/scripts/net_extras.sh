#!/usr/bin/env bash
# ~/.config/conky/gtex62-clean-suite/scripts/net_extras.sh
# Helper for Conky: WAN/LAN status, VLAN gateway RTTs, default GW, DNS, subnet mask, NIC alias.

set -euo pipefail

# --- CONFIG ------------------------------------------------------------------
IFACE="${2:-eno1}"                # default interface if not provided
CACHE="$HOME/.cache/conky/wan_ip"

# Max characters for the friendly NIC alias (to fit your layout)
MAX_ALIAS_LEN=23

# VLANs: "Name|CIDR|Gateway"
# Adjust the network ranges/gateways here to match your LAN/VLAN setup.
VLAN_LIST=(
  "VLAN10(Home)|192.168.10.0/24|192.168.10.1"
  "VLAN20(IoT)|192.168.20.0/24|192.168.20.1"
  "VLAN30(Guest)|192.168.30.0/24|192.168.30.1"
  "VLAN40(Infra)|192.168.40.0/24|192.168.40.1"
)

# Conky color markup (keep literal tokens so Conky parses them)
YELLOW_OPEN="\${color #FFD54A}"
COLOR_RESET="\${color}"
COLOR_LABEL="\${color1}"

# --- PCI-ID → Friendly alias map --------------------------------------------
# Use vendor:device lowercase hex, e.g. 8086:15f3 (Intel I225-V)
# Get yours with:   ~/.config/conky/scripts/net_extras.sh nic_pci eno1
alias_by_pci() {
  case "$1" in
    # Intel i219-V families (examples, add your exact id if different)
    8086:15b8|8086:15b7|8086:15b9|8086:15fa|8086:0d4f) echo "Intel I219-V"; return ;;
    # Intel 2.5 GbE I225-V (common IDs)
    8086:15f3|8086:3100) echo "Intel I225-V"; return ;;
    # Intel I226-V (examples)
    8086:125b|8086:125c) echo "Intel I226-V"; return ;;
    # Intel I210 / I350
    8086:1533) echo "Intel I210"; return ;;
    8086:1521|8086:1523) echo "Intel I350"; return ;;
    # Realtek
    10ec:8125) echo "Realtek 2.5GbE (RTL8125)"; return ;;
    10ec:8168) echo "Realtek GbE (RTL8111/8168)"; return ;;
  esac
  return 1
}

# --- Helpers -----------------------------------------------------------------
mask_from_cidr() {
  local cidr
  cidr="${1##*/}"

  local m
  m=$(( 0xffffffff << (32 - cidr) & 0xffffffff ))

  printf "%d.%d.%d.%d\n" $(( (m>>24) & 255 )) $(( (m>>16) & 255 )) $(( (m>>8) & 255 )) $(( m & 255 ))
}


cidr_for_iface() {
  ip -o -f inet addr show dev "$1" 2>/dev/null | awk '{print $4}' | head -n1
}

dns_primary() {
  # Prefer upstream DNS (avoid systemd-resolved stub 127.0.0.53)
  local dns
  dns="$(awk '/^nameserver/{print $2; exit}' /etc/resolv.conf 2>/dev/null || true)"
  if [ "$dns" = "127.0.0.53" ] && command -v resolvectl >/dev/null 2>&1; then
    # Try link-specific first: extract the first IPv4 address on that line
    dns="$(resolvectl dns "$IFACE" 2>/dev/null | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -n1)"
    if [ -z "$dns" ]; then
      # Look inside the IFACE block in `resolvectl status`
      dns="$(resolvectl status 2>/dev/null \
        | sed -n "/Link .*($IFACE)/,/^$/p" \
        | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' \
        | head -n1)"
    fi
    # Fallback: first global DNS server
    [ -z "$dns" ] && dns="$(resolvectl status 2>/dev/null \
      | awk '/DNS Servers:/ {print; exit}' \
      | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' \
      | head -n1)"
  fi
  [ -n "$dns" ] && echo "$dns" || echo "—"
}

wan_status() {
  local gw_iface now mtime age

  # Find the interface used by the default route
  gw_iface="$(
    ip route show default 2>/dev/null \
      | awk '/default/ {for (i=1; i<=NF; i++) if ($i=="dev") {print $(i+1); exit}}'
  )"

  now=$(date +%s)

  if [ -s "$CACHE" ]; then
    mtime=$(stat -c %Y "$CACHE" 2>/dev/null || echo 0)
  else
    mtime=0
  fi

  age=$(( now - mtime ))

  # If the default route is via VPN (tun*/wg*), show a short
  # "...reconnecting" phase while the WAN cache is stale, then "Online".
  if [ -n "$gw_iface" ] && [[ "$gw_iface" == tun* || "$gw_iface" == wg* ]]; then
    if [ ! -s "$CACHE" ] || [ "$age" -gt 20 ]; then
      echo "...reconnecting"
    else
      echo "Online"
    fi
    return
  fi

  # Non-VPN default route: if we *have* a default route but the WAN cache
  # hasn’t been refreshed recently, show "...scanning".
  if [ -n "$gw_iface" ] && { [ ! -s "$CACHE" ] || [ "$age" -gt 30 ]; }; then
    echo "...scanning"
    return
  fi

  # Fallback to simple Online/Offline check
  if [ -s "$CACHE" ] && grep -Eq '^[0-9]{1,3}(\.[0-9]{1,3}){3}$' "$CACHE"; then
    echo "Online"
  else
    echo "Offline"
  fi
}


wan_ip() {
  if [ -s "$CACHE" ]; then tr -d '\r\n' < "$CACHE"; else echo "—"; fi
}

wan_ip_label() {
  local state_file="$HOME/.cache/conky/vpn_state"
  local raw state

  # Read raw VPN state (may be "On", "Off", "ON", "Off ", etc.)
  if [ -s "$state_file" ]; then
    raw="$(tr -d '\r\n' < "$state_file")"
  else
    raw=""
  fi

  # Normalize: trim spaces and lowercase
  state="$(printf '%s' "$raw" | tr -d ' \t' | tr '[:upper:]' '[:lower:]')"

  if [ "$state" = "on" ]; then
    echo "WAN IP Address (VPN):"
  else
    echo "WAN IP Address:"
  fi
}



lan_status() {
  ip link show "$1" 2>/dev/null | grep -q "state UP" && echo "Online" || echo "Offline"
}

default_gw() {
  ip route show default 2>/dev/null | awk '/default/ {print $3; exit}'
}

pci_id_for_iface() {
  # Prefer sysfs (no root needed)
  local path vendor device
  path="$(readlink -f "/sys/class/net/$1/device" 2>/dev/null || true)"
  [ -n "$path" ] || return 1
  vendor="$(tr -d '\n' < "$path/vendor" 2>/dev/null | sed 's/^0x//')"
  device="$(tr -d '\n' < "$path/device" 2>/dev/null | sed 's/^0x//')"
  [ -n "$vendor" ] && [ -n "$device" ] || return 1
  echo "${vendor}:${device}" | tr '[:upper:]' '[:lower:]'
}

nic_model() {
  # Keep your existing model resolver (long form)
  local devpath pci modaline
  devpath="$(readlink -f "/sys/class/net/$1/device" 2>/dev/null || true)"
  if [ -n "$devpath" ]; then
    pci="${devpath##*/}"
    modaline="$(lspci -s "$pci" 2>/dev/null | sed -E 's/^[0-9a-f:.]+[[:space:]]+[^:]+:[[:space:]]+//')"
    if [ -n "$modaline" ]; then
      echo "$modaline"
      return
    fi
  fi
  # Fallback to driver
  ethtool -i "$1" 2>/dev/null | awk -F': ' '/driver:/{print "Driver: "$2; exit}' || echo "$1"
}

nic_alias_from_model() {
  local model
  model="$1"

  # Normalize a bit
  model="$(echo "$model" \
    | sed -E 's/^[Ii]ntel [Cc]orporation /Intel /; s/[Ee]thernet (C|c)ontroller:?[[:space:]]*//; s/^[[:space:]]+//')"

  # Prefer concise Intel I-series tag if present (e.g., "Intel I219-V", "Intel I225-V")
  if echo "$model" | grep -Eqi 'I[0-9]{3}(-[A-Z])?'; then
  local short 
  short="Intel $(echo "$model" | grep -Eio 'I[0-9]{3}(-[A-Z])?' | head -n1)"

    echo "$short"
    return
  fi

  # Realtek quick mappings
  if echo "$model" | grep -qi 'RTL8125'; then echo "Realtek 2.5GbE (RTL8125)"; return; fi
  if echo "$model" | grep -qi 'RTL8111'; then echo "Realtek GbE (RTL8111)";   return; fi

  # Fallback to the cleaned model string
  echo "$model"
}

nic_friendly() {
  local pci model alias

  # 1) Try PCI-ID -> alias map first
  pci="$(pci_id_for_iface "$1" 2>/dev/null || true)"
  if [ -n "$pci" ]; then
    if alias_by_pci "$pci" >/dev/null 2>&1; then
      alias="$(alias_by_pci "$pci")"
    fi
  fi

  # 2) If no PCI alias, derive a short name from the model
  if [ -z "${alias:-}" ]; then
    model="$(nic_model "$1")"
    alias="$(nic_alias_from_model "$model")"
  fi

  # 3) Final fallback: driver name or iface
  if [ -z "$alias" ]; then
    alias="$(ethtool -i "$1" 2>/dev/null | awk -F': ' '/driver:/{print "Driver: "$2; exit}')"
    [ -z "$alias" ] && alias="$1"
  fi

  # 4) Enforce a maximum width so it never overruns your layout
  alias="${alias:0:${MAX_ALIAS_LEN}}"
  echo "$alias"
}

ping_ms() {
  local host t
  host="$1"
  t="$(ping -n -c1 -W1 "$host" 2>/dev/null | grep -o 'time=[0-9.]*' | head -n1 | cut -d= -f2)"
  if [ -n "$t" ]; then echo "${t} ms"; else echo "down"; fi
}


vlan_lines() {
  local line name cidr gw rtt label
  for line in "${VLAN_LIST[@]}"; do
    name="${line%%|*}"
    cidr="${line#*|}"; cidr="${cidr%%|*}"
    gw="${line##*|}"
    rtt="$(ping_ms "$gw")"
    # Pad label so "Gateway:" aligns; tweak width to taste
    label="$(printf '%-13s' "$name")"
    if echo "$name" | grep -q '^VLAN10'; then
      echo "${COLOR_LABEL}${label} Gateway:${COLOR_RESET} ${YELLOW_OPEN}${gw}${COLOR_RESET} (${rtt})"
    else
      echo "${COLOR_LABEL}${label} Gateway:${COLOR_RESET} ${gw} (${rtt})"
    fi
  done
}

subnet_mask() {
  local ipcidr
  ipcidr="$(cidr_for_iface "$1")"
  if [ -n "$ipcidr" ]; then
    mask_from_cidr "$ipcidr"
  else
    echo "—"
  fi
}

usage() {
  echo "usage: $0 {wan_status|wan_ip|lan_status|default_gw|dns1|subnet_mask|nic_model|nic_alias|nic_pci|vlan_lines} [iface]" >&2
  exit 1
}

case "${1:-}" in
  wan_status)     wan_status ;;
  wan_ip)         wan_ip ;;
  wan_ip_label)   wan_ip_label ;;
  lan_status)     lan_status "$IFACE" ;;
  default_gw)     default_gw ;;
  dns1)           dns_primary ;;
  subnet_mask)    subnet_mask "$IFACE" ;;
  nic_model)      nic_model "$IFACE" ;;
  nic_alias)      nic_friendly "$IFACE" ;;
  nic_pci)        pci_id_for_iface "$IFACE" ;;
  vlan_lines)     vlan_lines ;;
  *)              usage ;;
esac
