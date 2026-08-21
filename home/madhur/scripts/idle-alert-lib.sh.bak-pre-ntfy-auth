#!/bin/bash
#
# idle-alert-lib.sh
#
# Fires a one-time ntfy push when remaining idle time first drops to
# <= ALERT_THRESHOLD_MIN, deduped via a state file so it doesn't refire
# every minute while remaining stays low. The state file is cleared once
# remaining goes back above the threshold (real activity or a successful
# extend), re-arming the alert for the next idle streak.

ALERT_STATE_FILE="${ALERT_STATE_FILE:-$HOME/.local/state/idle-shutdown-alerted}"
ALERT_THRESHOLD_MIN="${ALERT_THRESHOLD_MIN:-5}"
NTFY_CMD="${NTFY_CMD:-/home/madhur/.virtualenvs/python-rsha/bin/homelab-ntfy}"
NTFY_CLICK_URL="${NTFY_CLICK_URL:-https://olivetin.desktop.madhur.co.in}"

maybe_send_idle_alert() {
    local remaining_min="$1"
    mkdir -p "$(dirname "$ALERT_STATE_FILE")"

    if [ "$remaining_min" -le "$ALERT_THRESHOLD_MIN" ]; then
        if [ ! -f "$ALERT_STATE_FILE" ]; then
            "$NTFY_CMD" --topic bootup --priority urgent \
                --click "$NTFY_CLICK_URL" \
                --title "Shutting down in ~${remaining_min} min (idle)" \
                "Idle timer will shut this machine down soon. Tap to open OliveTin and extend."
            touch "$ALERT_STATE_FILE"
        fi
    else
        rm -f "$ALERT_STATE_FILE"
    fi
}
