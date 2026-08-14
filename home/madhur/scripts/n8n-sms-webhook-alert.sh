#!/bin/bash
# Tails the n8n container log and fires an ntfy alert whenever the
# sms-realtime webhook (MacroDroid SMS forwarder) fails to parse its
# request body — almost always an unescaped control character (raw
# newline) inside the JSON the phone sent. See
# /home/madhur/.claude/projects/-home-madhur-docker/memory/... for the
# root-cause writeup; n8n's body-parser calls a strict JSON.parse at the
# framework layer before any workflow node runs, so this can't be caught
# inside the workflow itself — has to be watched from outside.
set -uo pipefail

NTFY_URL="${NTFY_URL:-https://ntfy.madhur.co.in/monitoring}"
CONTAINER="${CONTAINER:-n8n}"
PATTERN='webhook request POST /webhook/sms-realtime: Failed to parse request body'

docker logs -f --since 0s "$CONTAINER" 2>&1 | while IFS= read -r line; do
    case "$line" in
        *"$PATTERN"*)
            curl -fsS -m 10 \
                -H "Title: SMS webhook: bad JSON from MacroDroid" \
                -H "Priority: high" \
                -H "Tags: warning,sms" \
                -d "n8n sms-realtime webhook rejected a request: Failed to parse request body.
Likely an unescaped newline/control char in the forwarded SMS text.
$(date '+%Y-%m-%d %H:%M:%S %Z')" \
                "$NTFY_URL" >/dev/null 2>&1 || true
            ;;
    esac
done
