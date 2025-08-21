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

run_without_pcheck() {
    echo "`date` Executing $@\n" >> ~/logs/log.txt
    "$@" >>~/logs/log.txt 2>&1 &
    echo "Return code: $?" >> ~/logs/log.txt
}




#autorandr --load two
run_without_pcheck "/home/madhur/scripts/set_wallpaper.sh"

run sxhkd
run_without_pcheck /home/madhur/.config/conky/launch.sh
#run conky --daemonize --quiet --config=/home/madhur/.config/conky/
run picom --config ~/.config/picom/picom.conf -b
#run "/usr/libexec/xfce-polkit"

run "nm-applet"
run "indicator-sound-switcher"
run "xsettingsd"
#run "/usr/bin/gpclient"
run "xscreensaver"
#run "eww daemon"
(sleep 5 && run "redshift") &
run "systemd-timer-notify"
flatpak run com.github.hluk.copyq


