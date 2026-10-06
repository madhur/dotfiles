#!/usr/bin/env bash
# zjstatus runs commands with a minimal environment; systemd --user and xprintidle need these.
uid="$(id -u)"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$uid}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XDG_RUNTIME_DIR/bus}"
export DISPLAY="${DISPLAY:-:0}"
if [[ -f "${HOME}/.Xauthority" ]]; then
  export XAUTHORITY="${XAUTHORITY:-$HOME/.Xauthority}"
fi
exec /home/madhur/scripts/idle-remaining-plain.sh
