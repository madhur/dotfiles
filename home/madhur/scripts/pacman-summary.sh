#!/usr/bin/env bash
set -uo pipefail

WEBHOOK_URL="${WEBHOOK_URL:-https://n8n.desktop.madhur.co.in/webhook/pacman-summary}"
SINCE="${SINCE:-24h}"
LOG="${PACMAN_LOG:-/var/log/pacman.log}"

# cutoff as YYYY-MM-DDTHH:MM:SS+TZ matching pacman log timestamps
case "$SINCE" in
  *h) cutoff=$(date -Iseconds -d "${SINCE%h} hours ago") ;;
  *d) cutoff=$(date -Iseconds -d "${SINCE%d} days ago")  ;;
  *)  cutoff=$(date -Iseconds -d '24 hours ago') ;;
esac

# Filter pacman log lines newer than cutoff. Lines look like:
#   [2026-05-09T20:20:06+0530] [ALPM] installed firefox (139.0-1)
#   [2026-05-09T20:20:06+0530] [ALPM] upgraded linux (6.14.4.arch1-2 -> 6.14.5.arch1-1)
#   [2026-05-09T20:20:06+0530] [ALPM] removed gimp (3.0.4-1)
#   [2026-05-09T20:20:06+0530] [PACMAN] Running 'pacman -Syu'
recent=$(awk -v cutoff="$cutoff" '
  match($0, /^\[([0-9T:+-]+)\]/, m) {
    ts = m[1]
    # pacman uses YYYY-MM-DDTHH:MM:SS+ZZZZ (4-digit tz, no colon). Normalize for compare.
    gsub(/\+([0-9]{2})([0-9]{2})$/, "+\\1:\\2", ts)
    if (ts >= cutoff) print
  }
' "$LOG" || true)

extract_pkgs() { echo "$recent" | grep -E "\[ALPM\] $1 " | sed -E "s/.*\[ALPM\] $1 //" || true; }
count()        { if [ -z "$1" ]; then echo 0; else printf '%s\n' "$1" | awk 'NF{c++} END{print c+0}'; fi; }

installed=$(extract_pkgs installed)
upgraded=$(extract_pkgs upgraded)
removed=$(extract_pkgs removed)
reinstalled=$(extract_pkgs reinstalled)
downgraded=$(extract_pkgs downgraded)
commands=$(echo "$recent" | grep -E '\[PACMAN\] Running' | sed -E "s/.*Running '?([^']*)'?.*/\\1/")

# Flag kernel upgrade (needs reboot)
kernel_upgraded=false
if echo "$upgraded" | grep -qE '^(linux|linux-lts|linux-zen|linux-hardened) '; then
  kernel_upgraded=true
fi

# Flag containers/critical services that may need restart
critical_upgraded=$(echo "$upgraded" | grep -E '^(docker|systemd|nvidia|glibc|openssl|linux-firmware|wireguard|nftables|iptables) ' || true)

cap() { head -c 6000; }

payload=$(jq -n \
  --arg date           "$(date -Iseconds)" \
  --arg since          "$SINCE" \
  --arg installed      "$(echo "$installed"   | cap)" \
  --arg upgraded       "$(echo "$upgraded"    | cap)" \
  --arg removed        "$(echo "$removed"     | cap)" \
  --arg reinstalled    "$(echo "$reinstalled" | cap)" \
  --arg downgraded     "$(echo "$downgraded"  | cap)" \
  --arg commands       "$(echo "$commands"    | cap)" \
  --arg critical       "$(echo "$critical_upgraded" | cap)" \
  --argjson kernel_up  "$kernel_upgraded" \
  --argjson totals "$(jq -n \
    --argjson i  "$(count "$installed")" \
    --argjson u  "$(count "$upgraded")" \
    --argjson r  "$(count "$removed")" \
    --argjson re "$(count "$reinstalled")" \
    --argjson d  "$(count "$downgraded")" \
    '{installed:$i, upgraded:$u, removed:$r, reinstalled:$re, downgraded:$d}')" \
  '{
     date: $date, since: $since, totals: $totals,
     kernel_upgraded: $kernel_up,
     critical_upgraded: $critical,
     installed: $installed, upgraded: $upgraded, removed: $removed,
     reinstalled: $reinstalled, downgraded: $downgraded,
     commands: $commands
   }')

echo "$payload" | curl -fsS -X POST -H 'Content-Type: application/json' -d @- "$WEBHOOK_URL"
