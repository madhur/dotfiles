#!/bin/bash
# Conky management script for wallpaper locations
# Save as ~/scripts/manage_wallpaper_conky.sh

CONKY_DIR="$HOME/.config/conky"
MONITOR1_CONFIG="$CONKY_DIR/wallpaper_monitor1.conf"
MONITOR2_CONFIG="$CONKY_DIR/wallpaper_monitor2.conf"

# Function to start conky instances
start_conky() {
    echo "Starting wallpaper location conky instances..."
    
    # Start monitor 1 conky
    if [ -f "$MONITOR1_CONFIG" ]; then
        conky -c "$MONITOR1_CONFIG" -d
        echo "Started conky for monitor 1"
    else
        echo "Warning: Monitor 1 config not found at $MONITOR1_CONFIG"
    fi
    
    # Start monitor 2 conky
    if [ -f "$MONITOR2_CONFIG" ]; then
        conky -c "$MONITOR2_CONFIG" -d
        echo "Started conky for monitor 2"
    else
        echo "Warning: Monitor 2 config not found at $MONITOR2_CONFIG"
    fi
}

# Function to stop conky instances
stop_conky() {
    echo "Stopping wallpaper location conky instances..."
    pkill -f "wallpaper_monitor1.conf"
    pkill -f "wallpaper_monitor2.conf"
    echo "Stopped conky instances"
}

# Function to restart conky instances
restart_conky() {
    echo "Restarting wallpaper location conky instances..."
    stop_conky
    sleep 1
    start_conky
}

# Function to check if conky is running
status_conky() {
    echo "Checking conky status..."
    
    if pgrep -f "wallpaper_monitor1.conf" > /dev/null; then
        echo "✅ Monitor 1 conky is running"
    else
        echo "❌ Monitor 1 conky is NOT running"
    fi
    
    if pgrep -f "wallpaper_monitor2.conf" > /dev/null; then
        echo "✅ Monitor 2 conky is running"
    else
        echo "❌ Monitor 2 conky is NOT running"
    fi
}

# Main script logic
case "$1" in
    start)
        start_conky
        ;;
    stop)
        stop_conky
        ;;
    restart)
        restart_conky
        ;;
    status)
        status_conky
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        echo
        echo "Commands:"
        echo "  start   - Start wallpaper location conky instances"
        echo "  stop    - Stop wallpaper location conky instances" 
        echo "  restart - Restart wallpaper location conky instances"
        echo "  status  - Check if conky instances are running"
        exit 1
        ;;
esac