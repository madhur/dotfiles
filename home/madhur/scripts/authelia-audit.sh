#!/usr/bin/env bash
set -uo pipefail

WEBHOOK_URL="${WEBHOOK_URL:-https://n8n.desktop.madhur.co.in/webhook/authelia-audit}"
SINCE="${SINCE:-24h}"
CONTAINER="${CONTAINER:-authelia}"

LOGS=$(docker logs --since "$SINCE" "$CONTAINER" 2>&1 || true)

extract() { echo "$LOGS" | grep -E "$1" || true; }
count()   { if [ -z "$1" ]; then echo 0; else printf '%s\n' "$1" | awk 'NF{c++} END{print c+0}'; fi; }

successful_1fa=$(extract 'Successful 1FA authentication')
successful_2fa=$(extract 'Successful 2FA authentication')
unsuccessful_1fa=$(extract 'Unsuccessful 1FA authentication attempt')
unsuccessful_2fa=$(extract 'Unsuccessful 2FA authentication attempt')
banned=$(extract 'and they are banned until')
session_created=$(extract 'session.+(created|elevated)')
needs_2fa=$(extract 'requires 2FA, cannot be redirected')
errors=$(echo "$LOGS" | grep 'level=error' | grep -vE 'Unsuccessful 1FA|Unsuccessful 2FA|Request timeout occurred' || true)

# unique attacker IPs from failed logins
attacker_ips=$(echo "$unsuccessful_1fa$unsuccessful_2fa" | grep -oE 'remote_ip=[0-9.]+' | sort -u | sed 's/remote_ip=//')

cap() { head -c 8000; }

payload=$(jq -n \
  --arg date          "$(date -Iseconds)" \
  --arg since         "$SINCE" \
  --arg s1fa          "$(echo "$successful_1fa"   | cap)" \
  --arg s2fa          "$(echo "$successful_2fa"   | cap)" \
  --arg u1fa          "$(echo "$unsuccessful_1fa" | cap)" \
  --arg u2fa          "$(echo "$unsuccessful_2fa" | cap)" \
  --arg banned        "$(echo "$banned"           | cap)" \
  --arg session       "$(echo "$session_created"  | cap)" \
  --arg needs_2fa     "$(echo "$needs_2fa"        | cap)" \
  --arg errors        "$(echo "$errors"           | cap)" \
  --arg attacker_ips  "$attacker_ips" \
  --argjson totals "$(jq -n \
    --argjson s1 "$(count "$successful_1fa")" \
    --argjson s2 "$(count "$successful_2fa")" \
    --argjson u1 "$(count "$unsuccessful_1fa")" \
    --argjson u2 "$(count "$unsuccessful_2fa")" \
    --argjson bn "$(count "$banned")" \
    --argjson er "$(count "$errors")" \
    '{successful_1fa:$s1, successful_2fa:$s2, unsuccessful_1fa:$u1, unsuccessful_2fa:$u2, banned_events:$bn, errors:$er}')" \
  '{
     date: $date, since: $since, totals: $totals,
     attacker_ips: ($attacker_ips | split("\n") | map(select(length>0))),
     events: {
       successful_1fa: $s1fa, successful_2fa: $s2fa,
       unsuccessful_1fa: $u1fa, unsuccessful_2fa: $u2fa,
       banned: $banned, session: $session, needs_2fa: $needs_2fa, errors: $errors
     }
   }')

echo "$payload" | curl -fsS -X POST -H 'Content-Type: application/json' -d @- "$WEBHOOK_URL"
