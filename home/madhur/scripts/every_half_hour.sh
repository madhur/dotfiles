#!/bin/bash
source /home/madhur/scripts/notify_wrapper.sh

run_with_notification "/home/madhur/.local/bin/take-screenshot.sh" "Take screenshot" "halfhourly"
run_with_notification "cd ~/.config/conky && python uptime_tracker.py update" "Uptime Tracker Update" "halfhourly"