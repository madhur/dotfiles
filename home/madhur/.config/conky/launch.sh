#!/bin/bash
cd $(dirname $0)

# Parse command line arguments
mode="main"
no_pause=false

show_usage() {
    echo "Usage: $0 [MODE] [OPTIONS]"
    echo ""
    echo "MODES:"
    echo "  -a, --all              Manage all conky instances (default)"
    echo "  -w, --wallpaper-only   Only manage wallpaper-related conky instances"
    echo "  -m, --main-only        Only manage main conky instances (exclude wallpaper)"
    echo ""
    echo "OPTIONS:"
    echo "  -n, --no-pause         Start without pause"
    echo "  -h, --help            Show this help message"
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -a|--all)
            mode="all"
            shift
            ;;
        -w|--wallpaper-only)
            mode="wallpaper"
            shift
            ;;
        -m|--main-only)
            mode="main"
            shift
            ;;
        -n|--no-pause)
            no_pause=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Set pause flag
if [ "$no_pause" = true ]; then
    pause_flag=""
else
    pause_flag="--pause=1"
    echo "Conky waiting 1 seconds to start..."
fi

# Function to start a conky config
start_conky() {
    local config_file="$1"
    local description="$2"
    
    if [ ! -f "$config_file" ]; then
        echo "Config file not found: $config_file"
        return 1
    fi

    local display_env=""
    if [ ! -z "$DISPLAY" ]; then
        display_env="--setenv=DISPLAY=$DISPLAY"
    else
        display_env="--setenv=DISPLAY=:0"
    fi
    
    # Use systemd-run with proper environment
    # systemd-run --user --scope  \
    #     --unit="conky-$(basename "$config_file" .conf)" \
    #     $display_env \
    #     conky --daemonize --config="$config_file"
    
    conky --daemonize --config="$config_file"
    # Use systemd-run --user --scope to escape the service cgroup
    # This prevents systemd from killing conky when the service ends
   
    # Don't wait for systemd-run to complete, just start it in background
    # Give it a moment to start
    
    
}

# Function to kill wallpaper-related conky instances
kill_wallpaper_conky() {
    echo "Stopping wallpaper-related conky instances..."
    pkill -f "wallpaper_monitor1.conf" 2>/dev/null
    pkill -f "wallpaper_monitor2.conf" 2>/dev/null
    sleep 0.5
}

# Function to kill main conky instances
kill_main_conky() {
    echo "Stopping main conky instances..."
    pkill -f "conky.conf" 2>/dev/null
    pkill -f "secondary_conky.conf" 2>/dev/null
    sleep 0.5
}

# Function to kill all conky instances
kill_all_conky() {
    echo "Stopping all conky instances..."
    killall conky 2>/dev/null
    sleep 0.5
}

# Function to start wallpaper conky instances
start_wallpaper_conky() {
    echo "Starting wallpaper-related conky instances..."
    
    if [ -f "/home/madhur/.config/conky/wallpaper_monitor1.conf" ]; then
        start_conky "/home/madhur/.config/conky/wallpaper_monitor1.conf" "wallpaper monitor 1"
    fi
    
    if [ -f "/home/madhur/.config/conky/wallpaper_monitor2.conf" ]; then
        start_conky "/home/madhur/.config/conky/wallpaper_monitor2.conf" "wallpaper monitor 2"
    fi
}

# Function to start main conky instances
start_main_conky() {
    echo "Starting main conky instances..."
    
    start_conky "/home/madhur/.config/conky/conky.conf" "main conky"
    start_conky "/home/madhur/.config/conky/secondary_conky.conf" "secondary conky"
}

# Main logic based on mode
case $mode in
    "all")
        echo "Managing all conky instances..."
        kill_all_conky
        start_main_conky
        start_wallpaper_conky
        ;;
    "wallpaper")
        echo "Managing wallpaper-related conky instances only..."
        kill_wallpaper_conky
        start_wallpaper_conky
        ;;
    "main")
        echo "Managing main conky instances only (excluding wallpaper)..."
        kill_main_conky
        start_main_conky
        ;;
esac

echo "Conky management completed for mode: $mode"