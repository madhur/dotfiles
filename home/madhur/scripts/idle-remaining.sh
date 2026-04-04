#!/bin/bash
#
# Outputs ANSI-colored remaining time until idle shutdown
# Used by starship custom module (text mode only)
#

THRESHOLD_MS=3600000  # 1 hour, must match idle-shutdown.sh

source ~/scripts/idle-lib.sh

# Show disabled icon if the idle-shutdown timer is not active
if ! systemctl --user is-active --quiet idle-shutdown.timer 2>/dev/null; then
    printf "\033[2m[⏻ off]\033[0m"
    exit 0
fi

# Do not exit non-zero: consumers like zjstatus treat that as a plugin error; show unknown instead.
if ! get_idle_ms; then
    printf "\033[2m[⏻ ?]\033[0m"
    exit 0
fi

REMAINING_MS=$(( THRESHOLD_MS - IDLE_MS ))
REMAINING_MIN=$(( REMAINING_MS / 60000 ))
# Past threshold before next timer run: show 0m instead of negative minutes
if [ "$REMAINING_MIN" -lt 0 ]; then
    REMAINING_MIN=0
fi

if [ "$REMAINING_MIN" -ge 30 ]; then
    COLOR="\033[32m"       # green
elif [ "$REMAINING_MIN" -ge 15 ]; then
    COLOR="\033[33m"       # yellow
else
    COLOR="\033[1;31m"     # bold red
fi

RESET="\033[0m"

printf "${COLOR}[⏻ ${REMAINING_MIN}m]${RESET}"
