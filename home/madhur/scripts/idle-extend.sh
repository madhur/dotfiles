#!/bin/bash
#
# Idle Extend Script
# Simulates a keypress on every logged-in tty to reset the idle clock,
# so the machine behaves exactly as if you'd typed something — no
# override flag, no snooze file. Text-mode only (no X11/GUI dependency):
# uses TIOCSTI to inject a byte into the tty's input queue, which is
# enough to bump the tty's atime (what idle-lib.sh's text-mode path
# reads to compute idleness).
#
# A NUL byte (\x00) is used because it's invisible to the shell — no
# visible character, no readline side effect — but it still counts as
# a real keypress at the kernel level.

LOG_FILE="$HOME/logs/idle-shutdown.log"
mkdir -p "$HOME/logs"

TTYS=$(who | grep "^${USER} " | awk '{print $2}')

if [ -z "$TTYS" ]; then
    echo "$(date): idle-extend: no logged-in ttys found, nothing to do" >> "$LOG_FILE"
    exit 1
fi

while read -r tty_dev; do
    [ -n "$tty_dev" ] && [ -e "/dev/$tty_dev" ] || continue
    doas python3 -c '
import fcntl, termios, os, sys
fd = os.open(sys.argv[1], os.O_RDWR | os.O_NOCTTY)
fcntl.ioctl(fd, termios.TIOCSTI, b"\x00")
os.close(fd)
' "/dev/$tty_dev"
done <<< "$TTYS"

echo "$(date): Simulated keypress to extend idle timer (ttys: $(echo "$TTYS" | tr '\n' ' '))" >> "$LOG_FILE"
exit 0
