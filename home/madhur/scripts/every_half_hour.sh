#!/bin/bash

source /home/madhur/scripts/notify_wrapper.sh

# Parse command line arguments to determine notification settings
# Usage: every_half_hour.sh [--no-notify-screenshot] [--no-notify-uptime]
NOTIFY_SCREENSHOT=false
NOTIFY_UPTIME=false



# Run commands with individual notification control
# Parameters: cmd, description, topic, notify_start, notify_enabled
run_with_notification "/home/madhur/.local/bin/take-screenshot.sh" "Take screenshot" "halfhourly" "false" "$NOTIFY_SCREENSHOT"
run_with_notification "cd ~/.config/conky && python uptime_tracker.py update" "Uptime Tracker Update" "halfhourly" "false" "$NOTIFY_UPTIME"