#!/usr/bin/bash
xsettingsd &

~/.config/picom/launch.sh

~/.config/conky/launch.sh

sxhkd &

feh  --randomize --bg-fill $HOME/Pictures/wallpapers/

dunst &

#exec --no-startup-id "killall copyq"

#exec --no-startup-id "copyq &"

flatpak run com.github.hluk.copyq

killall guake

guake &

#exec --no-startup-id "killall xfsettingsd"

#exec --no-startup-id "xfsettingsd --daemon &"

#killall xsettingsd

killall indicator-sound-switcher

indicator-sound-switcher &

#killall PanGPUI

#/opt/paloaltonetworks/globalprotect/PanGPUI &

killall nm-applet

nm-applet &

#/usr/libexec/xfce-polkit &


