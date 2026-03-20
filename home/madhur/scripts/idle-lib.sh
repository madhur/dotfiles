#!/bin/bash
#
# Shared idle detection library
# Provides get_idle_ms() which sets IDLE_MS in the calling script
#

get_idle_ms() {
    # Priority 1: X11 via xprintidle
    if [ -n "$DISPLAY" ]; then
        local val
        val=$(xprintidle 2>/dev/null)
        if [[ "$val" =~ ^[0-9]+$ ]] && [ "$val" -ge 0 ]; then
            IDLE_MS="$val"
            return 0
        fi
    fi

    # Priority 2: Text mode — TTY last-access time
    local tty_dev
    tty_dev=$(who | grep "^${USER} " | awk '{print $2}' | head -1)
    if [ -n "$tty_dev" ] && [ -e "/dev/$tty_dev" ]; then
        local last_access
        last_access=$(stat -c %X "/dev/$tty_dev")
        IDLE_MS=$(( ( $(date +%s) - last_access ) * 1000 ))
        return 0
    fi

    return 1  # detection failed
}
