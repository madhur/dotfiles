#!/bin/bash
SERVICE_NAME="$1"
ACTION="$2"

# Extract just the service name without .service extension for cleaner display
CLEAN_NAME="${SERVICE_NAME%.service}"

case "$ACTION" in
    "start")
        notify-send "Service Started" "$CLEAN_NAME is now running" --icon=dialog-information
        ;;
    "stop") 
        notify-send "Service Stopped" "$CLEAN_NAME has stopped" --icon=dialog-warning
        ;;
    "success")
        notify-send "Service Complete" "$CLEAN_NAME finished successfully" --icon=dialog-information
        ;;
    "fail")
        notify-send "Service Failed" "$CLEAN_NAME encountered an error" --icon=dialog-error
        ;;
esac
