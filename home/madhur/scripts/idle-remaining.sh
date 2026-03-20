#!/bin/bash
#
# Outputs ANSI-colored remaining time until idle shutdown
# Used by starship custom module (text mode only)
#

THRESHOLD_MS=3600000  # 1 hour, must match idle-shutdown.sh

source ~/scripts/idle-lib.sh

get_idle_ms || exit 1

REMAINING_MS=$(( THRESHOLD_MS - IDLE_MS ))
REMAINING_MIN=$(( REMAINING_MS / 60000 ))

if [ "$REMAINING_MIN" -ge 30 ]; then
    COLOR="\033[32m"       # green
elif [ "$REMAINING_MIN" -ge 15 ]; then
    COLOR="\033[33m"       # yellow
else
    COLOR="\033[1;31m"     # bold red
fi

RESET="\033[0m"

printf "${COLOR}[⏻ ${REMAINING_MIN}m]${RESET}"
