#!/bin/bash
#
# Idle Shutdown Script
# Checks if system has been idle for 30+ minutes and shuts down if so
#

# Set DISPLAY if not already set (default to :0)
export DISPLAY="${DISPLAY:-:0}"

# Set XAUTHORITY if not set (user's home directory)
if [ -z "$XAUTHORITY" ] && [ -f "$HOME/.Xauthority" ]; then
    export XAUTHORITY="$HOME/.Xauthority"
fi

# Create log directory if it doesn't exist
LOG_DIR="$HOME/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/idle-shutdown.log"

# Get idle time in milliseconds
IDLE_TIME_MS=$(xprintidle 2>/dev/null)

# Check if xprintidle returned a valid value
if [ -z "$IDLE_TIME_MS" ] || [ "$IDLE_TIME_MS" -lt 0 ]; then
    echo "$(date): ERROR - Could not get idle time from xprintidle" >> "$LOG_FILE"
    exit 1
fi

# 30 minutes in milliseconds (30 * 60 * 1000)
#THRESHOLD_MS=1800000
THRESHOLD_MS=900000

# Convert to minutes for logging
IDLE_MINUTES=$((IDLE_TIME_MS / 60000))

# Log the check
echo "$(date): Idle time: ${IDLE_MINUTES} minutes (${IDLE_TIME_MS} ms)" >> "$LOG_FILE"

# Check if idle time exceeds threshold
if [ "$IDLE_TIME_MS" -ge "$THRESHOLD_MS" ]; then
    echo "$(date): System idle for ${IDLE_MINUTES} minutes. Shutting down..." >> "$LOG_FILE"
    sudo /usr/bin/systemctl poweroff
else
    echo "$(date): System active (idle for ${IDLE_MINUTES} minutes). No action taken." >> "$LOG_FILE"
fi

exit 0

