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

    # Priority 2: Text mode — TTY last-access time.
    # The user may have several sessions open (e.g. tty1, tty2, an ssh pts);
    # idleness is the time since *any* of them was last active, so take the
    # most recently accessed (minimum idle), not just the first who(1) lists.
    local tty_dev newest_access=""
    while read -r tty_dev; do
        [ -n "$tty_dev" ] && [ -e "/dev/$tty_dev" ] || continue
        local last_access
        last_access=$(stat -c %X "/dev/$tty_dev") || continue
        if [ -z "$newest_access" ] || [ "$last_access" -gt "$newest_access" ]; then
            newest_access="$last_access"
        fi
    done < <(who | grep "^${USER} " | awk '{print $2}')

    if [ -n "$newest_access" ]; then
        IDLE_MS=$(( ( $(date +%s) - newest_access ) * 1000 ))
        return 0
    fi

    return 1  # detection failed
}
