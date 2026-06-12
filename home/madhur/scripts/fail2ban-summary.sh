#!/usr/bin/env bash
set -uo pipefail

WEBHOOK_URL="${WEBHOOK_URL:-https://n8n.desktop.madhur.co.in/webhook/fail2ban-summary}"
SINCE="${SINCE:-24h}"

# Map SINCE (e.g. 24h, 7d) to a journalctl-friendly form
case "$SINCE" in
  *h) JOURNAL_SINCE="${SINCE%h} hours ago" ;;
  *d) JOURNAL_SINCE="${SINCE%d} days ago"  ;;
  *)  JOURNAL_SINCE="24 hours ago" ;;
esac

# Pull fail2ban events from journal for the period
LOGS=$(sudo journalctl -u fail2ban --since "$JOURNAL_SINCE" --no-pager 2>/dev/null || true)

extract() { echo "$LOGS" | grep -E "$1" || true; }
count()   { if [ -z "$1" ]; then echo 0; else printf '%s\n' "$1" | awk 'NF{c++} END{print c+0}'; fi; }

# Lines look like:
#   May 28 23:13:15 host fail2ban.actions [pid]: NOTICE  [traefik-botsearch] Ban 1.2.3.4
#   May 28 23:13:15 host fail2ban.actions [pid]: NOTICE  [traefik-auth] Unban 5.6.7.8
#   May 28 23:13:15 host fail2ban.filter  [pid]: INFO    [traefik-botsearch] Found 1.2.3.4
ban_events=$(extract '\] Ban ')
unban_events=$(extract '\] Unban ')
found_events=$(extract '\] Found ')
restart_events=$(extract 'Server (ready|shutdown|reload)')
errors=$(echo "$LOGS" | grep -E '\b(ERROR|CRITICAL|WARNING)\b' | grep -vE 'Found ' || true)

# Per-jail ban counts
ban_by_jail=$(echo "$ban_events" | grep -oE '\[[^]]+\] Ban' | sed 's/\] Ban//; s/\[//' | sort | uniq -c | awk '{printf "%s: %s\n", $2, $1}')

# Unique banned IPs over the period
banned_ips=$(echo "$ban_events" | grep -oE 'Ban [0-9a-fA-F:.]+' | awk '{print $2}' | sort -u)

# Top offenders (most "Found" hits per IP)
top_offenders=$(echo "$found_events" | grep -oE 'Found [0-9a-fA-F:.]+' | awk '{print $2}' | sort | uniq -c | sort -rn | head -10 | awk '{printf "%s (%s hits)\n", $2, $1}')

# Snapshot: currently active state per jail
jail_list=$(sudo fail2ban-client status 2>/dev/null | awk -F: '/Jail list/ {gsub(/^\s+|\s+$/, "", $2); print $2}' | tr ',' '\n' | sed 's/^ *//' | sort -u)
current_status=""
for j in $jail_list; do
  [ -z "$j" ] && continue
  s=$(sudo fail2ban-client status "$j" 2>/dev/null || true)
  cur_banned=$(echo "$s" | awk -F'\t' '/Currently banned/ {gsub(/[^0-9]/, "", $2); print $2}')
  tot_banned=$(echo "$s" | awk -F'\t' '/Total banned/    {gsub(/[^0-9]/, "", $2); print $2}')
  ip_list=$(echo "$s"   | awk -F'\t' '/Banned IP list/  {print $2}')
  current_status+="${j}: currently=${cur_banned:-0} total=${tot_banned:-0} ips=[${ip_list}]"$'\n'
done

cap() { head -c 6000; }

payload=$(jq -n \
  --arg date          "$(date -Iseconds)" \
  --arg since         "$SINCE" \
  --arg ban_events    "$(echo "$ban_events"     | cap)" \
  --arg unban_events  "$(echo "$unban_events"   | cap)" \
  --arg found_events  "$(echo "$found_events"   | cap)" \
  --arg restart_events "$(echo "$restart_events" | cap)" \
  --arg errors        "$(echo "$errors"         | cap)" \
  --arg ban_by_jail   "$(echo "$ban_by_jail"    | cap)" \
  --arg top_offenders "$(echo "$top_offenders"  | cap)" \
  --arg current_status "$(echo "$current_status" | cap)" \
  --arg banned_ips    "$banned_ips" \
  --argjson totals "$(jq -n \
    --argjson b  "$(count "$ban_events")" \
    --argjson u  "$(count "$unban_events")" \
    --argjson f  "$(count "$found_events")" \
    --argjson r  "$(count "$restart_events")" \
    --argjson e  "$(count "$errors")" \
    '{bans:$b, unbans:$u, found:$f, restarts:$r, errors:$e}')" \
  '{
     date: $date, since: $since, totals: $totals,
     banned_ips: ($banned_ips | split("\n") | map(select(length>0))),
     ban_by_jail: $ban_by_jail,
     top_offenders: $top_offenders,
     current_status: $current_status,
     events: {
       bans: $ban_events, unbans: $unban_events,
       found: $found_events, restarts: $restart_events, errors: $errors
     }
   }')

echo "$payload" | curl -fsS -X POST -H 'Content-Type: application/json' -d @- "$WEBHOOK_URL"
