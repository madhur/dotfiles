#!/bin/sh


hour=`date +%H`
folder=''
if [ $hour -lt 12 ] # if hour is less than 12
then
folder="morning"
elif [ $hour -le 18 ] # if hour is less than equal to 16
then
folder="day"
elif [ $hour -le 05 ] # if hour is less than equal to 20
then
folder="night"
else
folder="night"
fi

feh --randomize --bg-fill /home/madhur/Pictures/wallpapers/$folder
