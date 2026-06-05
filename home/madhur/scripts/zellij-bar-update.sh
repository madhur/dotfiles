#!/bin/bash
#
# zellij-bar-update.sh
# Dedicated zjstatus bar refresh: pushes load average + clock into the running
# zellij session via `zellij pipe`. Workaround for zjstatus #247 — the plugin's
# internal Timer events freeze under the WASMI runtime, so {datetime} and the
# command_* widgets go stale. Driving them externally via pipe_* keeps them live.
#
# Decoupled from idle tracking (idleon/idleoff own pipe_idle); this runs on its
# own zellij-bar.timer regardless of idle state.

export TZ="Asia/Kolkata"

# Runs from systemd --user, so ZELLIJ is unset — find the live session explicitly.
session="${ZELLIJ_SESSION_NAME:-}"
if [ -z "$session" ]; then
    session=$(zellij list-sessions --no-formatting 2>/dev/null | grep -v 'EXITED' | awk '{print $1; exit}')
fi
[ -z "$session" ] && exit 0

push() { zellij --session "$session" pipe "zjstatus::pipe::$1::$2" 2>/dev/null || true; }

# Load: reuse status-custom.sh (outputs "hostname | <1-min load>").
push pipe_load "$(/home/madhur/.config/zellij/status-custom.sh)"

# Clock: matches the old datetime_format "%a %d %b  %H:%M".
push pipe_clock "$(date '+%a %d %b  %H:%M')"

# Idle: idle-remaining-plain.sh returns the live shutdown countdown when
# idle-shutdown.timer is active, or "⏻ off" when it isn't — so this keeps the
# widget correct in both states without depending on idleon/idleoff.
idle="$(/home/madhur/scripts/idle-remaining-plain.sh 2>/dev/null)"
[ -n "$idle" ] && push pipe_idle "$idle"
