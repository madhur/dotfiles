#!/bin/bash
# Start desktop recording with keylogging
# For use with OliveTin

set -e

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
STATE_FILE="/tmp/desktop_recording.state"
LOG_FILE="/tmp/desktop_recording.log"

# Check if already running
if [ -f "$STATE_FILE" ]; then
    echo "Recording is already in progress."
    echo "Use stop_recording.sh to stop the current recording."
    exit 1
fi

# Set DISPLAY for X11 recording (if running via OliveTin/systemd)
export DISPLAY="${DISPLAY:-:0}"

# Start recording controller in background
nohup python3 "$SCRIPT_DIR/recording_controller.py" > "$LOG_FILE" 2>&1 &

# Wait a moment to check if it started successfully
sleep 2

if [ -f "$STATE_FILE" ]; then
    echo "Recording started successfully."
    echo "Log file: $LOG_FILE"
    cat "$STATE_FILE"
else
    echo "Failed to start recording. Check log:"
    cat "$LOG_FILE"
    exit 1
fi
