#!/bin/bash
if [[ -f "/tmp/screenshot-5min-mode" ]]; then
    echo "Current mode: 5-minute screenshots"
else
    echo "Current mode: 30-minute screenshots"
fi
