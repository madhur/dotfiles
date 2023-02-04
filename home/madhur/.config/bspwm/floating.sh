#!/usr/bin/zsh

 # change the desktop number here
 FLOATING_DESKTOP_ID=$(bspc query -D -d '^1')

 bspc subscribe node_add | while read -a msg ; do
    desk_id=${msg[2]}
    wid=${msg[4]}
    [ "$FLOATING_DESKTOP_ID" = "$desk_id" ] && bspc node "$wid" -t floating
 done
 
 bspc subscribe node_add | while read -a msg; do
    bspc query -D -d "${msg[2]}.!focused" > /dev/null \
        && xdotool set_window --urgency 1 "${msg[4]}"
done