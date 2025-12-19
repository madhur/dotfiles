#!/bin/bash

# Directories to monitor (add all your wallpaper directories)
WATCH_DIRS=(
    "/home/madhur/Pictures/wallpapers/vertical/night"
    "/home/madhur/Pictures/wallpapers/vertical/morning"
     "/home/madhur/Pictures/wallpapers/vertical/evening"
    "/home/madhur/Pictures/wallpapers/vertical/day"
    "/home/madhur/Pictures/wallpapers/day"
     "/home/madhur/Pictures/wallpapers/morning"
     "/home/madhur/Pictures/wallpapers/evening"
    "/home/madhur/Pictures/wallpapers/night"
    # Add more directories as needed
)

# Path to your Python script
PYTHON_SCRIPT="/home/madhur/Desktop/python/bedrock_image_location.py"

# Python interpreter (use your venv if applicable)
PYTHON="/usr/bin/python3"

# Log file
LOG_FILE="/var/log/wallpaper-monitor.log"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Kill any existing instances of this script and their inotifywait processes
kill_existing_instances() {
    local script_name=$(basename "$0")
    local script_path=$(readlink -f "$0")
    
    # Find all processes running this script (excluding current one)
    pids=$(pgrep -f "$script_name" | grep -v $$)
    
    if [ -n "$pids" ]; then
        log_message "Found existing instances (PIDs: $pids), terminating..."
        for pid in $pids; do
            # Kill the main script process
            kill -TERM "$pid" 2>/dev/null
            # Also kill any inotifywait processes spawned by it
            pkill -P "$pid" inotifywait 2>/dev/null
        done
        
        # Wait a moment for graceful termination
        sleep 1
        
        # Force kill if still running
        for pid in $pids; do
            if ps -p "$pid" > /dev/null 2>&1; then
                log_message "Force killing PID: $pid"
                kill -KILL "$pid" 2>/dev/null
                pkill -9 -P "$pid" inotifywait 2>/dev/null
            fi
        done
        
        log_message "Existing instances terminated"
    fi
}

process_directory() {
    local dir="$1"
    log_message "Processing directory: $dir"
    
    # Modify your Python script to accept directory as argument
    # Or call it with the directory hardcoded
    cd "$(dirname "$PYTHON_SCRIPT")"
    $PYTHON "$PYTHON_SCRIPT" "$dir" 2>&1 | tee -a "$LOG_FILE"
}

log_message "Starting wallpaper monitor service"

# Kill any existing instances before starting
kill_existing_instances

# Monitor all directories for new files
inotifywait -m -r -e close_write -e moved_to --format '%w%f' "${WATCH_DIRS[@]}" | while read filepath
do
    # Check if it's an image file
    if [[ "$filepath" =~ \.(jpg|jpeg|png|gif|bmp|tiff|webp)$ ]]; then
        log_message "New image detected: $filepath"
        
        # Extract directory
        dir=$(dirname "$filepath")
        
        # Wait a bit to ensure file is fully written
        sleep 2
        
        # Process the directory
        process_directory "$dir"
    fi
done