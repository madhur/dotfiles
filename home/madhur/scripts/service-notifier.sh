#!/bin/bash
SERVICE_NAME="$1"
ACTION="$2"

# Extract just the service name without .service extension for cleaner display
CLEAN_NAME="${SERVICE_NAME%.service}"

# Configure ntfy topic - change this as needed
NTFY_TOPIC="systemd"

# Path to your Python script directory
SCRIPT_DIR="$(dirname "$0")"
PYTHON_SCRIPT="$SCRIPT_DIR/send_ntfy.py"

# Function to send both desktop and ntfy notifications
send_notifications() {
    local title="$1"
    local message="$2"
    local icon="$3"
    local ntfy_method="$4"
    
    # Send desktop notification
    #notify-send "$title" "$message" --icon="$icon"
    
    # Send ntfy notification if the Python script exists
    if [ -f "$PYTHON_SCRIPT" ]; then
        PYTHONPATH="$HOME/Desktop/python/email_reader:$PYTHONPATH" python3 "$PYTHON_SCRIPT" "$ntfy_method" "$CLEAN_NAME" "$message" "$NTFY_TOPIC"
    fi
}

case "$ACTION" in
    "start")
        send_notifications "Service Started" "$CLEAN_NAME is now running" "dialog-information" "info"
        ;;
    "stop") 
        send_notifications "Service Stopped" "$CLEAN_NAME has stopped" "dialog-warning" "warning"
        ;;
    "success")
        send_notifications "Service Complete" "$CLEAN_NAME finished successfully" "dialog-information" "success"
        ;;
    "fail")
        send_notifications "Service Failed" "$CLEAN_NAME encountered an error" "dialog-error" "error"
        ;;
esac