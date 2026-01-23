#!/bin/bash

source /home/madhur/scripts/notify_wrapper.sh

# Notification settings for uptime tracking
# Note: Screenshots are now handled by everyfiveminutes.timer with frequency toggle
NOTIFY_UPTIME=false

# Run uptime tracker update
# Parameters: cmd, description, topic, notify_start, notify_enabled
run_with_notification "cd ~/.config/conky && python uptime_tracker.py update" "Uptime Tracker Update" "halfhourly" "false" "$NOTIFY_UPTIME"