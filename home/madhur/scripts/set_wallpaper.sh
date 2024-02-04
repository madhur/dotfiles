#!/bin/sh

base_folder="/home/madhur/Pictures/wallpapers"
cd $base_folder || exit 1
folder=$(date +%d_%m)
if [ -d "$folder" ]; then
    feh --randomize --bg-center "$base_folder/$folder"
    exit 0
fi


hour=$(date +%H)
folder=''
if [ "$hour" -lt 05 ] # if hour is less than 05
then
folder="night"
elif [ "$hour" -lt 12 ] # if hour is less than  12
then
folder="morning"
elif [ "$hour" -lt 17 ] # if hour is less than  16
then
folder="day"
elif [ "$hour" -lt 20 ] # if hour is less then 20
then
folder="evening"
else
folder="night"
fi

feh --randomize --bg-fill $base_folder/$folder
notify-send "Updated wallpaper $folder"
