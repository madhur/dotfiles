#!/bin/bash
# Stop desktop recording
# For use with OliveTin

STATE_FILE="/tmp/desktop_recording.state"

# Check if recording is running
if [ ! -f "$STATE_FILE" ]; then
    echo "No recording in progress."
    exit 0
fi

# Get PID from state file
PID=$(python3 -c "import json; print(json.load(open('$STATE_FILE'))['pid'])" 2>/dev/null)

if [ -z "$PID" ]; then
    echo "Could not read PID from state file."
    rm -f "$STATE_FILE"
    exit 1
fi

# Check if process is running
if ! kill -0 "$PID" 2>/dev/null; then
    echo "Recording process not running (stale state file)."
    rm -f "$STATE_FILE"
    exit 0
fi

# Send SIGTERM for graceful shutdown
echo "Stopping recording (PID: $PID)..."
kill -TERM "$PID"

# Wait for process to exit (max 30 seconds)
for i in {1..30}; do
    if ! kill -0 "$PID" 2>/dev/null; then
        echo "Recording stopped successfully."
        exit 0
    fi
    sleep 1
done

# Force kill if still running
echo "Process didn't stop gracefully, forcing..."
kill -KILL "$PID" 2>/dev/null || true
rm -f "$STATE_FILE"

echo "Recording stopped."
