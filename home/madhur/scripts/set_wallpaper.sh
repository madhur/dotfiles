#!/bin/sh

# Check if we're running under Wayland
if [ "$XDG_SESSION_TYPE" = "wayland" ]; then
    echo "Detected Wayland session, using Wayland-specific wallpaper setter"
    /home/madhur/scripts/set_wallpaper_wayland.sh
    exit 0
fi

base_folder="/home/madhur/Pictures/wallpapers"
vertical="vertical"
script_dir="/home/madhur/Desktop/python"  

# Location cache files for osd_cat
location_cache_dir="$HOME/.cache/wallpaper_locations"
horizontal_location_file="$location_cache_dir/monitor1_location"
vertical_location_file="$location_cache_dir/monitor2_location"

# Create cache directory if it doesn't exist
mkdir -p "$location_cache_dir"

# Function to get location from text file
get_location() {
    local image_path="$1"
    local base_name=$(basename "$image_path")
    local name_without_ext="${base_name%.*}"
    local dir_path=$(dirname "$image_path")
    local text_file="$dir_path/$name_without_ext.txt"
    
    if [ -f "$text_file" ]; then
        cat "$text_file"
    else
        echo "Location: Unknown"
    fi
}

cd $base_folder || exit 1

# Check for date-specific folder first
folder=$(date +%d_%m)


if [ -d "$folder" ]; then
    echo "Using date-specific folder: $base_folder/$folder"
    
    # Select random image for date-specific folder
    filename=$(ls "$base_folder/$folder" | shuf -n 1)
    horizontal_path="$base_folder/$folder/$filename"
    
    # Get and cache location
    location=$(get_location "$horizontal_path")
    echo "$location" > "$horizontal_location_file"
    echo "Location for horizontal: $location"
    
    # Set wallpaper
    feh --randomize --bg-center "$base_folder/$folder"
    
    # Update OSD display
    #update_osd_display "$location" "left"
    
    # Clear vertical location since we're only using one wallpaper
    echo "" > "$vertical_location_file"
    
    exit 0
fi

# Time-based folder selection
hour=$(date +%H)
bg_mode="fill"

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
filename=$(ls $base_folder/$folder | grep -iE '\.(jpe?g|png|gif|bmp|webp|tiff)$' | shuf -n 1)
#filename="fg88wims2ugf1.jpeg"

horizontal_path="$base_folder/$folder/$filename"
echo "Selected horizontal: $filename"

vertical_filename=$(ls $base_folder/$vertical/$folder | grep -iE '\.(jpe?g|png|gif|bmp|webp|tiff)$' | shuf -n 1)
vertical_path="$base_folder/$vertical/$folder/$vertical_filename"
echo "Selected vertical: $vertical_filename"

# Get locations for both wallpapers
horizontal_location=$(get_location "$horizontal_path")
echo "$horizontal_location" > "$horizontal_location_file"
echo "Location for horizontal: $horizontal_location"

vertical_location=""
if [ -n "$vertical_path" ] && [ -f "$vertical_path" ]; then
    vertical_location=$(get_location "$vertical_path")
    echo "$vertical_location" > "$vertical_location_file"
    echo "Location for vertical: $vertical_location"
else
    echo "" > "$vertical_location_file"
fi

# Process wallpapers
processed_horizontal=$horizontal_path
processed_vertical=""

if [ -n "$vertical_path" ] && [ -f "$vertical_path" ]; then
    processed_vertical=$vertical_path
fi

# Set wallpaper using feh
if [ "$bg_mode" = "center" ]; then
    feh_cmd="feh --bg-center"
else
    feh_cmd="feh --bg-fill"
fi

# Build the complete feh command and update OSD displays
if [ -n "$processed_vertical" ] && [ -f "$processed_vertical" ]; then
    # Both horizontal and vertical wallpapers
    echo "Setting wallpapers: $(basename "$processed_horizontal") + $(basename "$processed_vertical")"
    $feh_cmd "$processed_horizontal" "$processed_vertical"
    #notify-send "Wallpaper Updated" "Set: $(basename "$horizontal_path") + $(basename "$vertical_path")"
    
else
    # Only horizontal wallpaper
    echo "Setting wallpaper: $(basename "$processed_horizontal")"
    $feh_cmd "$processed_horizontal"
    #notify-send "Wallpaper Updated" "Set: $(basename "$horizontal_path")"
    
fi

echo "Wallpaper set successfully!"
echo "Location files updated:"
echo "  Monitor 1: $horizontal_location_file"
echo "  Monitor 2: $vertical_location_file"

# Refresh wallpaper conky displays
setsid /home/madhur/.config/conky/launch.sh --wallpaper-only --no-pause &
                                                                                                                                                                                            