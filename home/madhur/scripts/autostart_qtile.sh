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


#autorandr --load two
#sleep 5
/home/madhur/scripts/set_wallpaper.sh

#feh --bg-max /home/madhur/Desktop/World\ Cup\ 2023\ Schedule.png 
run sxhkd
run conky --daemonize --quiet --config=/home/madhur/.config/conky/conky.conf
run /home/madhur/bin/picom --config ~/.config/picom/picom.conf -b
#run "/usr/libexec/xfce-polkit"
#run "dunst"

#sleep 10
run "nm-applet"
run "indicator-sound-switcher"
#run "guake"
run "xsettingsd"
#run "/opt/paloaltonetworks/globalprotect/PanGPUI"
run "/usr/bin/gpclient"
run "xscreensaver"
#run "eww daemon"
#currenttime=$(date +%H:%M)
# if [[ "$currenttime" > "18:00" ]] || [[ "$currenttime" < "06:30" ]]; then
#  echo "Executing redshift"
#  run "/home/madhur/scripts/start_redshift.sh"
#fi
run "redshift"
#flatpak run com.github.hluk.copyq
#run "mvp ~/Desktop/win95.mp3"


#run /usr/bin/xscreensaver-command -lock
