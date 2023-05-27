#!/bin/bash



# Add a fake tty to get the day highlight

# https://stackoverflow.com/a/32981392

faketty () {

script -qfec "$(printf "%q " "$@")"

}



# Get the max line width

width=$(ncal -3 | wc -L)



cal=$(faketty ncal -3 \

| sed 's|_\(.\)|<span background="white" foreground="black">\1</span>|g' \

| sed 's|\s*$||')

rofi -font "mono 9" -markup -width -"${width}" -lines 8 -location 3 -e "${cal}"
