#!/bin/bash
FLAG_FILE="/tmp/screenshot-5min-mode"
if [[ -f "$FLAG_FILE" ]]; then
    rm "$FLAG_FILE"
    echo "Switched to 30-minute mode"
else
    touch "$FLAG_FILE"
    echo "Switched to 5-minute mode"
fi
