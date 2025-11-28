#!/usr/bin/env bash
# ~/.config/conky/gtex62-clean-suite/scripts/start-conky.sh

pkill -x conky 2>/dev/null || true

# Adjust gap_x for your monitor layout
# Example assumes Monitor #2 is on the right of primary display

# System info - left edge of 2nd monitor
conky -c ~/.config/conky/gtex62-clean-suite/widgets/sys-info.conky.conf &

# Network info below system info
conky -c ~/.config/conky/gtex62-clean-suite/widgets/net-sys.conky.conf &

# Weather center top
conky -c ~/.config/conky/gtex62-clean-suite/widgets/weather.conky.conf &

# Date & time below weather
conky -c ~/.config/conky/gtex62-clean-suite/widgets/date-time.conky.conf &

# Calendar on top right
conky -c ~/.config/conky/gtex62-clean-suite/widgets/calendar.conky.conf &

#Notes on right edge
conky -c ~/.config/conky/gtex62-clean-suite/widgets/notes.conky.conf &
