#!/usr/bin/env bash
set -euo pipefail

CACHE="$HOME/.cache/conky"
OUT="$CACHE/wan_ip"
STATE_FILE="$CACHE/vpn_state"
LAST_IP_FILE="$CACHE/wan_ip_last"
mkdir -p "$CACHE"

# --- settings ---
MIN_INTERVAL_ON=10     # seconds between refreshes when VPN is connected
MIN_INTERVAL_OFF=20    # seconds between refreshes when VPN is disconnected
TIMEOUT=2              # curl/wget timeout per endpoint (seconds)

now_epoch() { date +%s; }

get_vpn_state() {
  if command -v piactl >/dev/null 2>&1; then
    local s
    s="$(piactl get connectionstate 2>/dev/null || true)"
    case "$s" in
      Connected)  echo "ON"; return 0 ;;
      *)          echo "OFF"; return 0 ;;
    esac
  fi
  echo "UNKNOWN"
}

pick_iface() {
  # Prefer WireGuard, then OpenVPN
  if ip link show wg0 >/dev/null 2>&1 && ip addr show wg0 | grep -q "inet "; then
    echo "wg0"; return 0
  fi
  if ip link show tun0 >/dev/null 2>&1 && ip addr show tun0 | grep -q "inet "; then
    echo "tun0"; return 0
  fi
  echo ""   # let OS choose route
}

valid_ip() {
  [[ "${1:-}" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]
}

fetch_ip() {
  local IFACE url ip
IFACE="$(pick_iface)"

# Build curl args safely (fixes ShellCheck SC2086)
local -a CURL_ARGS=()
if [[ -n "$IFACE" ]]; then
  CURL_ARGS+=(--interface "$IFACE")
fi

  # curl first
  if command -v curl >/dev/null 2>&1; then
    for url in https://api.ipify.org https://ifconfig.me/ip https://icanhazip.com; do
      ip="$(curl -4fsS --max-time "$TIMEOUT" "${CURL_ARGS[@]}" "$url" 2>/dev/null | tr -d '\r' | head -n1 || true)"
      if valid_ip "$ip"; then
        printf '%s\n' "$ip"; return 0
      fi
    done
  fi

  # wget fallback (no --interface; routing decides)
  if command -v wget >/dev/null 2>&1; then
    for url in https://api.ipify.org https://ifconfig.me/ip https://icanhazip.com; do
      ip="$(wget -qO- --timeout="$TIMEOUT" "$url" 2>/dev/null | tr -d '\r' | head -n1 || true)"
      if valid_ip "$ip"; then
        printf '%s\n' "$ip"; return 0
      fi
    done
  fi

  # dig fallback (OpenDNS)
  if command -v dig >/dev/null 2>&1; then
    ip="$(dig +short -4 myip.opendns.com @resolver1.opendns.com 2>/dev/null | head -n1 || true)"
    if valid_ip "$ip"; then
      printf '%s\n' "$ip"; return 0
    fi
  fi
  return 1
}

should_refresh() {
  local vpn_state="$1" min_interval="$2" now mtime
  now="$(now_epoch)"
  if [[ ! -f "$OUT" ]]; then
    return 0
  fi
  mtime="$(date -r "$OUT" +%s 2>/dev/null || echo 0)"
  (( now - mtime >= min_interval ))
}

main() {
  local vpn_state old_state min_interval ip

  vpn_state="$(get_vpn_state)"
  old_state="$(cat "$STATE_FILE" 2>/dev/null || echo "UNKNOWN")"
  [[ "$vpn_state" != "$old_state" ]] && : > "$OUT"  # force refresh on state flip

  if [[ "$vpn_state" == "ON" ]]; then
    min_interval="$MIN_INTERVAL_ON"
  else
    min_interval="$MIN_INTERVAL_OFF"
  fi

  if should_refresh "$vpn_state" "$min_interval"; then
    if ip="$(fetch_ip)"; then
      
      printf '%s\n' "$ip" >"$OUT"
      printf '%s\n' "$ip" >"$LAST_IP_FILE"
    elif [[ -s "$LAST_IP_FILE" ]]; then
      # fallback to last known good IP if fetch fails
      cp -f "$LAST_IP_FILE" "$OUT"
    fi
  fi

  printf '%s\n' "$vpn_state" >"$STATE_FILE"
}

main
exit 0


