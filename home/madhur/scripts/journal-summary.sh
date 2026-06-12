#!/usr/bin/env bash
set -uo pipefail

# Daily systemd / journal health digest -> n8n.
# Sends PRE-AGGREGATED error+failure data (not raw logs) so the LLM summary
# stays cheap and signal-rich. Mirrors fail2ban-summary.sh in shape.

WEBHOOK_URL="${WEBHOOK_URL:-https://n8n.desktop.madhur.co.in/webhook/journal-summary}"
SINCE="${SINCE:-24h}"

# Map SINCE (e.g. 24h, 7d) to a journalctl-friendly form
case "$SINCE" in
  *h) JOURNAL_SINCE="${SINCE%h} hours ago" ;;
  *d) JOURNAL_SINCE="${SINCE%d} days ago"  ;;
  *)  JOURNAL_SINCE="24 hours ago" ;;
esac

cap() { head -c 6000; }
count() { if [ -z "$1" ]; then echo 0; else printf '%s\n' "$1" | awk 'NF{c++} END{print c+0}'; fi; }

# --- Failed units (current snapshot) -----------------------------------------
failed_system=$(systemctl --failed --no-legend --plain 2>/dev/null \
  | awk '{print $1}' || true)
failed_user=$(systemctl --user --failed --no-legend --plain 2>/dev/null \
  | awk '{print $1}' || true)

# --- Coredumps over the period, deduped by binary ----------------------------
# coredumpctl columns: DAY DATE TIME TZ PID UID GID SIG COREFILE EXE SIZE
core_raw=$(coredumpctl list --since "$JOURNAL_SINCE" --no-legend 2>/dev/null || true)
core_by_exe=$(echo "$core_raw" | awk 'NF{print $8, $10}' \
  | sort | uniq -c | sort -rn \
  | awk '{sig=$2; exe=$3; cnt=$1; printf "%s (%s) x%s\n", exe, sig, cnt}')

# --- Error-priority messages, normalized & counted ---------------------------
# -o cat strips timestamps/pids; sed collapses numbers+hex so near-identical
# lines (e.g. a crash-loop) fold into one counted entry instead of thousands.
normalize() { sed -E 's/0x[0-9a-fA-F]+/0xN/g; s/[0-9]+/N/g'; }

sys_err_raw=$(sudo -n journalctl -p err --since "$JOURNAL_SINCE" --no-pager -o cat 2>/dev/null || true)
usr_err_raw=$(journalctl --user -p err --since "$JOURNAL_SINCE" --no-pager -o cat 2>/dev/null || true)

sys_err_top=$(echo "$sys_err_raw" | grep -v '^$' | normalize | sort | uniq -c | sort -rn | head -25 \
  | awk '{cnt=$1; $1=""; sub(/^ /,""); printf "x%s  %s\n", cnt, $0}')
usr_err_top=$(echo "$usr_err_raw" | grep -v '^$' | normalize | sort | uniq -c | sort -rn | head -25 \
  | awk '{cnt=$1; $1=""; sub(/^ /,""); printf "x%s  %s\n", cnt, $0}')

# --- Units that logged errors (which services are noisy) ---------------------
noisy_units=$(sudo -n journalctl -p err --since "$JOURNAL_SINCE" --no-pager -o json 2>/dev/null \
  | jq -r '._SYSTEMD_UNIT // .SYSLOG_IDENTIFIER // "unknown"' 2>/dev/null \
  | sort | uniq -c | sort -rn | head -15 \
  | awk '{printf "%s: %s\n", $2, $1}' || true)

payload=$(jq -n \
  --arg date            "$(date -Iseconds)" \
  --arg host            "$(hostname)" \
  --arg since           "$SINCE" \
  --arg failed_system   "$failed_system" \
  --arg failed_user     "$failed_user" \
  --arg core_by_exe     "$(echo "$core_by_exe" | cap)" \
  --arg sys_err_top     "$(echo "$sys_err_top" | cap)" \
  --arg usr_err_top     "$(echo "$usr_err_top" | cap)" \
  --arg noisy_units     "$(echo "$noisy_units" | cap)" \
  --argjson totals "$(jq -n \
    --argjson fs "$(count "$failed_system")" \
    --argjson fu "$(count "$failed_user")" \
    --argjson co "$(count "$core_raw")" \
    --argjson se "$(count "$sys_err_raw")" \
    --argjson ue "$(count "$usr_err_raw")" \
    '{failed_system:$fs, failed_user:$fu, coredumps:$co, system_errors:$se, user_errors:$ue}')" \
  '{
     date: $date, host: $host, since: $since, totals: $totals,
     failed_units: {
       system: ($failed_system | split("\n") | map(select(length>0))),
       user:   ($failed_user   | split("\n") | map(select(length>0)))
     },
     coredumps_by_binary: $core_by_exe,
     top_system_errors:   $sys_err_top,
     top_user_errors:     $usr_err_top,
     noisiest_units:      $noisy_units
   }')

echo "$payload" | curl -fsS -X POST -H 'Content-Type: application/json' -d @- "$WEBHOOK_URL"
