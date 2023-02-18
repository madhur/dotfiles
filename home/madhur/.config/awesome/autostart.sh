#!/bin/sh

run() {
  if ! pgrep -f "$1" ;
  then
    echo "`date` Executing $@\n" >> ~/logs/log.txt
    "$@" >>~/logs/log.txt 2>&1 &
    echo "Return code: $?" >> ~/logs/log.txt
  else
    echo "`date` Not Executing $@\n" >> ~/logs/log.txt
  fi
}

#sleep 5
run feh --randomize --bg-fill /home/madhur/Pictures/wallpapers/
run sxhkd
run conky --daemonize --quiet --config=/home/madhur/.config/conky/conky.conf
#run picom --config ~/.config/picom/picom.conf -b
run "/usr/libexec/xfce-polkit"
#run "dunst"

#sleep 10
run "nm-applet"
run "indicator-sound-switcher"
run "guake"
run "xsettingsd"
run "/opt/paloaltonetworks/globalprotect/PanGPUI"
run "xscreensaver"
flatpak run com.github.hluk.copyq
