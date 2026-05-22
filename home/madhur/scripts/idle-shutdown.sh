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

# Get idle time in milliseconds (supports X11 and text mode)
source ~/scripts/idle-lib.sh
if ! get_idle_ms; then
    echo "$(date): ERROR - Could not get idle time (no DISPLAY and no TTY found)" >> "$LOG_FILE"
    exit 1
fi
IDLE_TIME_MS="$IDLE_MS"

# 30 minutes in milliseconds (30 * 60 * 1000)
#THRESHOLD_MS=1800000
#THRESHOLD_MS=900000
THRESHOLD_MS=3600000 #one hour

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

# Push bar value into zellij — workaround for zjstatus #247 (command widget panics on WASMI).
if command -v zellij >/dev/null 2>&1; then
    VALUE=$("$HOME/scripts/idle-remaining-plain.sh" 2>/dev/null)
    if [ -n "$VALUE" ]; then
        zellij pipe "zjstatus::pipe::pipe_idle::${VALUE}" 2>/dev/null || true
    fi
fi

exit 0

