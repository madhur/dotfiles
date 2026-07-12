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

# Grace period (seconds): never poweroff if the timer was started very recently.
# Guards against starting the timer (idleon) on an already-idle machine and having
# the very first tick power it off instantly. Only positively-confirmed fresh starts
# are protected; if duration can't be determined, normal behavior proceeds.
GRACE_SECONDS=90

# Convert to minutes for logging
IDLE_MINUTES=$((IDLE_TIME_MS / 60000))

# Remaining time until shutdown, clamped to >= 0 (mirrors idle-remaining.sh)
REMAINING_MS=$(( THRESHOLD_MS - IDLE_TIME_MS ))
REMAINING_MINUTES=$(( REMAINING_MS / 60000 ))
if [ "$REMAINING_MINUTES" -lt 0 ]; then
    REMAINING_MINUTES=0
fi

# One-time alert when remaining time first drops to <= 5 minutes
source ~/scripts/idle-alert-lib.sh
maybe_send_idle_alert "$REMAINING_MINUTES"

# Publish live status for the glance/homepage dashboard widgets
STATUS_FILE="$HOME/docker/idle-status/html/status.json"
mkdir -p "$(dirname "$STATUS_FILE")"
cat > "$STATUS_FILE" <<EOF
{"idle_minutes": ${IDLE_MINUTES}, "remaining_minutes": ${REMAINING_MINUTES}, "updated_at": "$(date -Iseconds)"}
EOF

# Log the check
echo "$(date): Idle time: ${IDLE_MINUTES} minutes (${IDLE_TIME_MS} ms)" >> "$LOG_FILE"

# Check if idle time exceeds threshold
if [ "$IDLE_TIME_MS" -ge "$THRESHOLD_MS" ]; then
    # Grace guard: how long has the timer been active? (monotonic, survives wall-clock changes)
    ACTIVE_US=$(systemctl --user show idle-shutdown.timer -p ActiveEnterTimestampMonotonic --value 2>/dev/null)
    NOW_US=$(awk '{print int($1*1000000)}' /proc/uptime 2>/dev/null)
    if [[ "$ACTIVE_US" =~ ^[0-9]+$ ]] && [ "$ACTIVE_US" -gt 0 ] && [[ "$NOW_US" =~ ^[0-9]+$ ]]; then
        ACTIVE_SECONDS=$(( (NOW_US - ACTIVE_US) / 1000000 ))
        if [ "$ACTIVE_SECONDS" -lt "$GRACE_SECONDS" ]; then
            echo "$(date): System idle for ${IDLE_MINUTES} minutes, but timer only active ${ACTIVE_SECONDS}s (< ${GRACE_SECONDS}s grace). Skipping shutdown." >> "$LOG_FILE"
            ACTIVE_SECONDS=skip
        fi
    fi

    if [ "${ACTIVE_SECONDS:-}" != "skip" ]; then
        echo "$(date): System idle for ${IDLE_MINUTES} minutes. Shutting down..." >> "$LOG_FILE"
        sudo /usr/bin/systemctl poweroff
    fi
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

