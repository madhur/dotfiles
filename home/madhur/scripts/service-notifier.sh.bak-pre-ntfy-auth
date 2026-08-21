#!/bin/bash
SERVICE_NAME="$1"
ACTION="$2"

# Extract just the service name without .service extension for cleaner display
CLEAN_NAME="${SERVICE_NAME%.service}"

# Configure ntfy topic - change this as needed
NTFY_TOPIC="systemd"

# Instrumented ntfy bridge (homelab-ntfy console script → NtfyNotifier → metrics).
# Replaces the old send_ntfy.py duplicate; absolute venv path so it works from
# the minimal environment systemd hands a unit hook.
HOMELAB_NTFY="${HOMELAB_NTFY:-/home/madhur/.virtualenvs/python-rsha/bin/homelab-ntfy}"

# Function to send both desktop and ntfy notifications
send_notifications() {
    local title="$1"
    local message="$2"
    local icon="$3"
    local ntfy_method="$4"

    # Send desktop notification
    #notify-send "$title" "$message" --icon="$icon"

    # Map the logical method to ntfy tags + priority (mirrors what the old
    # NtfyNotifier.send_<method>_notification helpers used).
    local tags priority
    case "$ntfy_method" in
        error)   tags="x";                  priority="high" ;;
        warning) tags="warning";            priority="high" ;;
        success) tags="white_check_mark";   priority="default" ;;
        *)       tags="information_source"; priority="default" ;;
    esac

    if [ -x "$HOMELAB_NTFY" ]; then
        "$HOMELAB_NTFY" -t "$NTFY_TOPIC" \
            --title "systemd: $CLEAN_NAME" \
            --tags "$tags" --priority "$priority" \
            --source service-notifier \
            "$message" >/dev/null 2>&1 || true
    fi
}

case "$ACTION" in
    "start")
        #send_notifications "Service Started" "$CLEAN_NAME is now running" "dialog-information" "info"
        ;;
    "stop") 
        send_notifications "Service Stopped" "$CLEAN_NAME has stopped" "dialog-warning" "warning"
        ;;
    "success")
        #send_notifications "Service Complete" "$CLEAN_NAME finished successfully" "dialog-information" "success"
        ;;
    "fail")
        send_notifications "Service Failed" "$CLEAN_NAME encountered an error" "dialog-error" "error"
        ;;
esac