#!/bin/sh

base_folder="/home/madhur/Pictures/wallpapers"
vertical="vertical"
script_dir="/home/madhur/Desktop/python"  
python_script="$script_dir/location_embosser.py"
venv_file="$script_dir/.venv"  

# Enable/disable AI processing (set to 0 to disable, 1 to enable)
use_ai=0

cd $base_folder || exit 1

# Check for date-specific folder first
folder=$(date +%d_%m)
bg_mode="center"

if [ -d "$folder" ]; then
    echo "Using date-specific folder: $base_folder/$folder"
    feh --randomize --bg-center "$base_folder/$folder"
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
filename=$(ls $base_folder/$folder | shuf -n 1)
horizontal_path="$base_folder/$folder/$filename"
echo "Selected horizontal: $filename"

vertical_filename=$(ls $base_folder/$vertical/$folder | shuf -n 1)
vertical_path="$base_folder/$vertical/$folder/$vertical_filename"
echo "Selected vertical: $vertical_filename"

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

# Function to process image with AI
process_with_ai() {
    input_path="$1"
    if [ "$use_ai" -eq 1 ] && [ -f "$python_script" ]; then
        echo "Processing with AI: $(basename "$input_path")" >&2
        
        # Get virtual environment path
        venv_path=$(get_venv_path)
        
        if [ -n "$venv_path" ] && [ -f "$venv_path/bin/python" ]; then
            echo "Using virtual environment: $(basename "$venv_path")" >&2
            python_exe="$venv_path/bin/python"
            
            # Debug: Show the command being run
            echo "Debug: Running command: $python_exe $python_script $input_path" >&2
            
            # Run with error output to see what's happening
            processed_path=$("$python_exe" "$python_script" "$input_path" 2>&1)
            exit_code=$?
            
            # Debug: Show the result
            echo "Debug: Exit code: $exit_code" >&2
            echo "Debug: Output: $processed_path" >&2
            
        else
            echo "Virtual environment not found, falling back to system Python" >&2
            echo "Debug: Running command: python3 $python_script $input_path" >&2
            processed_path=$(python3 "$python_script" "$input_path" 2>&1)
            exit_code=$?
            echo "Debug: Exit code: $exit_code" >&2
            echo "Debug: Output: $processed_path" >&2
        fi
        
        if [ $exit_code -eq 0 ] && [ -n "$processed_path" ] && [ -f "$processed_path" ]; then
            echo "$processed_path"
        else
            echo "AI processing failed, using original: $(basename "$input_path")" >&2
            echo "$input_path"
        fi
    else
        echo "$input_path"
    fi
}

# Process wallpapers
processed_horizontal=$(process_with_ai "$horizontal_path")
processed_vertical=""

if [ -n "$vertical_path" ] && [ -f "$vertical_path" ]; then
    processed_vertical=$(process_with_ai "$vertical_path")
fi

# Set wallpaper using feh
if [ "$bg_mode" = "center" ]; then
    feh_cmd="feh --bg-center"
else
    feh_cmd="feh --bg-fill"
fi

# Build the complete feh command
if [ -n "$processed_vertical" ] && [ -f "$processed_vertical" ]; then
    # Both horizontal and vertical wallpapers
    echo "Setting wallpapers: $(basename "$processed_horizontal") + $(basename "$processed_vertical")"
    $feh_cmd "$processed_horizontal" "$processed_vertical"
    notify-send "Wallpaper Updated" "Set: $(basename "$horizontal_path") + $(basename "$vertical_path")"
else
    # Only horizontal wallpaper
    echo "Setting wallpaper: $(basename "$processed_horizontal")"
    $feh_cmd "$processed_horizontal"
    notify-send "Wallpaper Updated" "Set: $(basename "$horizontal_path")"
fi

echo "Wallpaper set successfully!"

# Optional: Clean up old processed images (older than 1 hour)
if [ "$use_ai" -eq 1 ]; then
    find /tmp -name "embossed_*.jpg" -mtime +0.04 -delete 2>/dev/null || true
fi