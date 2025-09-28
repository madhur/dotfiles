#!/bin/sh

base_folder="/home/madhur/Pictures/wallpapers"
vertical="vertical"


# swaybg configuration
bg_color="#000000"  # Background color (black by default)
# Get connected monitors for Hyprland/Sway
get_monitors() {
    if command -v hyprctl >/dev/null 2>&1; then
        # Hyprland
        hyprctl monitors -j | jq -r '.[].name' 2>/dev/null || \
        hyprctl monitors | grep "Monitor" | awk '{print $2}' 2>/dev/null
    elif command -v swaymsg >/dev/null 2>&1; then
        # Sway
        swaymsg -t get_outputs | jq -r '.[].name' 2>/dev/null || \
        swaymsg -t get_outputs | grep -o '"name":"[^"]*"' | cut -d'"' -f4 2>/dev/null
    else
        echo "default"
    fi
}

# Kill existing swaybg processes
kill_swaybg() {
    echo "Stopping existing swaybg processes..."
    pkill -f swaybg 2>/dev/null || true
    sleep 1
}

cd $base_folder || exit 1

# Kill existing swaybg processes
kill_swaybg

# Check for date-specific folder first
folder=$(date +%d_%m)
scaling_mode="stretch"  # swaybg scaling mode: stretch, fill, fit, center, tile

if [ -d "$folder" ]; then
    echo "Using date-specific folder: $base_folder/$folder"
    filename=$(ls $base_folder/$folder | shuf -n 1)
    wallpaper_path="$base_folder/$folder/$filename"
    
    # Set same wallpaper on all monitors
    for monitor in $(get_monitors); do
        if [ "$monitor" != "default" ]; then
            swaybg -o "$monitor" -i "$wallpaper_path" -m "$scaling_mode" -c "$bg_color" &
        else
            swaybg -i "$wallpaper_path" -m "$scaling_mode" -c "$bg_color" &
        fi
    done
    
    #notify-send "Wallpaper Updated" "Set: $(basename "$filename")"
    echo "Wallpaper set successfully!"
    exit 0
fi

# Time-based folder selection
hour=$(date +%H)
scaling_mode="stretch"  # swaybg scaling mode for time-based wallpapers

if [ "$hour" -lt 05 ]; then
    folder="midnight"
elif [ "$hour" -lt 12 ]; then
    folder="morning"
elif [ "$hour" -lt 17 ]; then
    folder="day"
elif [ "$hour" -lt 20 ]; then
    folder="evening"
elif [ "$hour" -le 23 ]; then
    folder="night"
else
    folder="night"
fi

echo "Using time-based folder: $folder (hour: $hour)"

# Select random wallpapers
filename=$(ls $base_folder/$folder   | grep -iE '\.(jpe?g|png|gif|bmp|webp|tiff)$' | shuf -n 1)
horizontal_path="$base_folder/$folder/$filename"
echo "Selected horizontal: $filename"

vertical_filename=""
vertical_path=""
if [ -d "$base_folder/$vertical/$folder" ]; then
    vertical_filename=$(ls $base_folder/$vertical/$folder  | grep -iE '\.(jpe?g|png|gif|bmp|webp|tiff)$'  | shuf -n 1)
    vertical_path="$base_folder/$vertical/$folder/$vertical_filename"
    echo "Selected vertical: $vertical_filename"
fi

# Function to get virtual environment path from .venv file
get_venv_path() {
    if [ -f "$venv_file" ]; then
        venv_name=$(cat "$venv_file" | tr -d '\n\r ')
        
        # Common locations where virtual environments are stored
        possible_paths=(
            "$HOME/.virtualenvs/$venv_name"
            "$HOME/venvs/$venv_name"
            "$HOME/.local/share/virtualenvs/$venv_name"
            "/opt/virtualenvs/$venv_name"
        )
        
        for path in "${possible_paths[@]}"; do
            if [ -d "$path" ] && [ -f "$path/bin/python" ]; then
                echo "$path"
                return 0
            fi
        done
    fi
    
    return 1
}

# Function to get monitor orientation
is_vertical_monitor() {
    monitor_name="$1"
    echo "Debug: Checking monitor $monitor_name" >&2
    
    # Get monitor info from hyprctl or swaymsg
    if command -v hyprctl >/dev/null 2>&1; then
        # Hyprland
        if command -v jq >/dev/null 2>&1; then
            monitor_info=$(hyprctl monitors -j | jq -r ".[] | select(.name == \"$monitor_name\")" 2>/dev/null)
            if [ -n "$monitor_info" ]; then
                width=$(echo "$monitor_info" | jq -r '.width' 2>/dev/null)
                height=$(echo "$monitor_info" | jq -r '.height' 2>/dev/null)
                transform=$(echo "$monitor_info" | jq -r '.transform // empty' 2>/dev/null)
                
                echo "Debug: Monitor $monitor_name - Width: $width, Height: $height, Transform: $transform" >&2
                
                # Check if monitor is rotated (transform 1 or 3 = 90° or 270°)
                if [ "$transform" = "1" ] || [ "$transform" = "3" ]; then
                    echo "Debug: Monitor $monitor_name is rotated (transform: $transform)" >&2
                    return 0  # true - it's vertical due to rotation
                fi
                
                # Also check if height > width (naturally vertical or rotated)
                if [ -n "$width" ] && [ -n "$height" ] && [ "$height" -gt "$width" ]; then
                    echo "Debug: Monitor $monitor_name is vertical (height > width)" >&2
                    return 0  # true
                fi
            fi
        else
            # Fallback to parsing text output if jq is not available
            monitor_section=$(hyprctl monitors | sed -n "/Monitor $monitor_name/,/^Monitor /p" | head -n -1)
            resolution=$(echo "$monitor_section" | grep -o '[0-9]\+x[0-9]\+' | head -1 2>/dev/null)
            transform=$(echo "$monitor_section" | grep "transform:" | awk '{print $2}' 2>/dev/null)
            
            echo "Debug: Monitor $monitor_name - Resolution: $resolution, Transform: $transform" >&2
            
            # Check rotation first
            if [ "$transform" = "1" ] || [ "$transform" = "3" ]; then
                echo "Debug: Monitor $monitor_name is rotated (transform: $transform)" >&2
                return 0  # true
            fi
            
            # Check resolution
            if [ -n "$resolution" ]; then
                width=$(echo "$resolution" | cut -d'x' -f1)
                height=$(echo "$resolution" | cut -d'x' -f2)
                
                if [ "$height" -gt "$width" ]; then
                    echo "Debug: Monitor $monitor_name is vertical (height > width)" >&2
                    return 0  # true
                fi
            fi
        fi
    elif command -v swaymsg >/dev/null 2>&1; then
        # Sway
        if command -v jq >/dev/null 2>&1; then
            monitor_info=$(swaymsg -t get_outputs | jq -r ".[] | select(.name == \"$monitor_name\")" 2>/dev/null)
            if [ -n "$monitor_info" ]; then
                width=$(echo "$monitor_info" | jq -r '.current_mode.width' 2>/dev/null)
                height=$(echo "$monitor_info" | jq -r '.current_mode.height' 2>/dev/null)
                transform=$(echo "$monitor_info" | jq -r '.transform // empty' 2>/dev/null)
                
                echo "Debug: Monitor $monitor_name - Width: $width, Height: $height, Transform: $transform" >&2
                
                # Check if monitor is rotated
                if [ "$transform" = "90" ] || [ "$transform" = "270" ]; then
                    echo "Debug: Monitor $monitor_name is rotated (transform: $transform)" >&2
                    return 0  # true
                fi
                
                # Check if height > width
                if [ -n "$width" ] && [ -n "$height" ] && [ "$height" -gt "$width" ]; then
                    echo "Debug: Monitor $monitor_name is vertical (height > width)" >&2
                    return 0  # true
                fi
            fi
        fi
    fi
    
    echo "Debug: Monitor $monitor_name is horizontal" >&2
    return 1  # false
}

# Process wallpapers
processed_horizontal=$horizontal_path
processed_vertical=""

if [ -n "$vertical_path" ] && [ -f "$vertical_path" ]; then
    processed_vertical=$vertical_path
fi

# Set wallpapers using swaybg
monitors=$(get_monitors)
wallpaper_set=false

echo "Available monitors: $monitors"
echo "Horizontal wallpaper: $(basename "$processed_horizontal")"
if [ -n "$processed_vertical" ] && [ -f "$processed_vertical" ]; then
    echo "Vertical wallpaper: $(basename "$processed_vertical")"
else
    echo "No vertical wallpaper available"
fi

for monitor in $monitors; do
    echo "Processing monitor: $monitor"
    if [ -n "$processed_vertical" ] && [ -f "$processed_vertical" ] && is_vertical_monitor "$monitor"; then
        # Use vertical wallpaper for vertical monitors
        echo "Setting vertical wallpaper on $monitor: $(basename "$processed_vertical")"
        if [ "$monitor" != "default" ]; then
            swaybg -o "$monitor" -i "$processed_vertical" -m "$scaling_mode" -c "$bg_color" &
        else
            swaybg -i "$processed_vertical" -m "$scaling_mode" -c "$bg_color" &
        fi
        wallpaper_set=true
    else
        # Use horizontal wallpaper for horizontal monitors or if no vertical available
        echo "Setting horizontal wallpaper on $monitor: $(basename "$processed_horizontal")"
        if [ "$monitor" != "default" ]; then
            swaybg -o "$monitor" -i "$processed_horizontal" -m "$scaling_mode" -c "$bg_color" &
        else
            swaybg -i "$processed_horizontal" -m "$scaling_mode" -c "$bg_color" &
        fi
        wallpaper_set=true
    fi
done

# Fallback: if no monitors detected or something went wrong, set on all
if [ "$wallpaper_set" = false ]; then
    echo "Fallback: Setting wallpaper on all monitors"
    if [ -n "$processed_vertical" ] && [ -f "$processed_vertical" ]; then
        swaybg -i "$processed_horizontal" -m "$scaling_mode" -c "$bg_color" &
        #notify-send "Wallpaper Updated" "Set: $(basename "$horizontal_path") + $(basename "$vertical_path")"
    else
        swaybg -i "$processed_horizontal" -m "$scaling_mode" -c "$bg_color" &
        #notify-send "Wallpaper Updated" "Set: $(basename "$horizontal_path")"
    fi
else
    # Send appropriate notification
    if [ -n "$processed_vertical" ] && [ -f "$processed_vertical" ]; then
        #notify-send "Wallpaper Updated" "Set: $(basename "$horizontal_path") + $(basename "$vertical_path")"
    else
        #notify-send "Wallpaper Updated" "Set: $(basename "$horizontal_path")"
    fi
fi

echo "Wallpaper set successfully!"

