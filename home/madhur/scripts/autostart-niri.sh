#!/bin/sh

# Niri/Wayland autostart script
# Adapted from autostart.sh for Wayland compatibility

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

# Background services
run_without_pcheck "WatchYourLAN"

# Wallpaper - use swaybg or swww for Wayland
# run_without_pcheck "swaybg -i /path/to/wallpaper.jpg -m fill"

# Tray applets
run "nm-applet"
run "indicator-sound-switcher"

# Redshift alternative for Wayland
(sleep 5 && run "wlsunset") &

# Background services
run "systemd-timer-notify"
run "aw-qt"

# Clipboard manager
flatpak run com.github.hluk.copyq

# Idle/lock daemon (alternative to xscreensaver)
# run "swayidle -w timeout 300 'swaylock -f' timeout 600 'niri msg action power-off-monitors' resume 'niri msg action power-on-monitors'"
