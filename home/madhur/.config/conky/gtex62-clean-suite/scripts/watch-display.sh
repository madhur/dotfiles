#!/usr/bin/env bash
# Watches xrandr for layout changes and restarts Conky after things are stable.

# CONFIG
QUIET_SECONDS=6                # how long the layout must be unchanged
CHECK_INTERVAL=0.5             # how often to check (seconds)
START_CONKY="$HOME/.config/conky/gtex62-clean-suite/scripts/start-conky.sh"

last_hash=""
last_change_time=0

get_layout_hash() {
  # Hash only connected outputs + geometry to ignore transient noise
  xrandr --current | awk '/ connected/{print}' | sha1sum | awk '{print $1}'
}

restart_conky() {
  # graceful restart of your Conky stack
  pkill -x conky 2>/dev/null
  sleep 1
  bash "$START_CONKY"
}

# Prime the state
last_hash="$(get_layout_hash)"
last_change_time="$(date +%s)"

while :; do
  sleep "$CHECK_INTERVAL"
  h="$(get_layout_hash)"
  now="$(date +%s)"

  if [[ "$h" != "$last_hash" ]]; then
    # Something changed (KVM switch or resolution re-probe)
    last_hash="$h"
    last_change_time="$now"
    continue
  fi

  # If stable long enough, restart conky and wait until next change
  if (( now - last_change_time >= QUIET_SECONDS )); then
    restart_conky
    # Avoid hammering: reset timer so we only restart once per stable period
    last_change_time=$(( now + 9999 ))
  fi
done
