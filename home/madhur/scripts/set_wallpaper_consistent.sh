#!/bin/sh

base_folder="/home/madhur/Pictures/wallpapers"
vertical="vertical"
cd $base_folder || exit 1

folder=$(date +%d_%m)
if [ -d "$folder" ]; then
    # Use date as seed for consistent but date-dependent selection
    RANDOM=$(date +%Y%m%d)
    files=("$base_folder/$folder"/*)
    index=$((RANDOM % ${#files[@]}))
    feh --bg-center "${files[$index]}"
    notify-send "Updated wallpaper ${files[$index]##*/}"
    exit 0
fi

hour=$(date +%H)
folder=''
if [ "$hour" -lt 05 ]; then
    folder="midnight"
elif [ "$hour" -lt 12 ]; then
    folder="morning"
elif [ "$hour" -lt 17 ]; then
    folder="day"
elif [ "$hour" -lt 20 ]; then
    folder="evening"
else
    folder="night"
fi

# Use date as seed for consistent but date-dependent selection
RANDOM=$(date +%Y%m%d)

# Select main wallpaper
files=("$base_folder/$folder"/*)
index=$((RANDOM % ${#files[@]}))
filename="${files[$index]##*/}"

# Select vertical wallpaper
vertical_files=("$base_folder/$vertical/$folder"/*)
vertical_index=$((RANDOM % ${#vertical_files[@]}))
vertical_filename="${vertical_files[$vertical_index]##*/}"

feh --bg-fill "$base_folder/$folder/$filename" "$base_folder/$vertical/$folder/$vertical_filename"
notify-send "Updated wallpaper $filename"
