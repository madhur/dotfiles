#!/bin/bash

# rofi-process-killer.sh
# A rofi script to list and kill running processes

# Configuration
ROFI_PROMPT="Kill Process"
ROFI_MESSAGE="Select a process to kill (Ctrl+C to cancel)"

# Function to get formatted process list
get_processes() {
    # Get processes with full command line
    # Use -ww to avoid truncation, exclude kernel threads
    ps auxww --no-headers | awk '
    $11 !~ /^\[.*\]$/ {
        # Format: PID | CPU% | MEM% | USER | FULL_COMMAND
        printf "%s | %s%% | %s%% | %s | ", $2, $3, $4, $1
        # Reconstruct full command line from field 11 onwards
        for(i=11; i<=NF; i++) {
            if(i==11) printf "%s", $i
            else printf " %s", $i
        }
        printf "\n"
    }' | sort -k3 -nr  # Sort by CPU usage (descending)
}

# Function to kill process
kill_process() {
    local selection="$1"
    
    # Extract PID from selection (first field before |)
    local pid=$(echo "$selection" | awk -F' \\| ' '{print $1}')
    
    if [[ -z "$pid" || ! "$pid" =~ ^[0-9]+$ ]]; then
        notify-send "Error" "Invalid process ID: $pid"
        exit 1
    fi
    
    # Get process name for confirmation
    local process_name=$(echo "$selection" | awk -F' \\| ' '{print $5}')
    
    # Try graceful kill first (SIGTERM)
    if kill "$pid" 2>/dev/null; then
        notify-send "Process Killed" "Successfully terminated PID $pid ($process_name)"
        sleep 1
        
        # Check if process still exists
        if kill -0 "$pid" 2>/dev/null; then
            # Force kill if still running (SIGKILL)
            if kill -9 "$pid" 2>/dev/null; then
                notify-send "Process Force Killed" "Force killed PID $pid ($process_name)"
            else
                notify-send "Error" "Failed to kill PID $pid ($process_name)"
            fi
        fi
    else
        notify-send "Error" "Failed to kill PID $pid ($process_name). Check permissions."
    fi
}

# Main script logic
if [[ $# -eq 0 ]]; then
    # No arguments - show process list
    get_processes
elif [[ $# -eq 1 ]]; then
    # One argument - kill the selected process
    kill_process "$1"
else
    echo "Usage: $0 [selected_process]"
    exit 1
fi
