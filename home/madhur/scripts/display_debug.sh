#!/bin/bash

echo "=== Display Debug Info ==="
echo "Date: $(date)"
echo

echo "=== XRandR Configuration ==="
xrandr --query
echo

echo "=== Virtual Screen Dimensions ==="
xdpyinfo | grep dimensions
echo

echo "=== AwesomeWM Variables (if accessible) ==="
echo "awful.util.expanded: Check in AwesomeWM"
echo "awful.util.vertical_expanded: Check in AwesomeWM"
echo

echo "=== Screen Padding Check ==="
echo "Run this in AwesomeWM Lua prompt (Mod4+x):"
echo "for s in screen do print('Screen '..s.index..': padding='..s.padding.left..','..s.padding.right..','..s.padding.top..','..s.padding.bottom) end"
echo

echo "=== Monitor Positions ==="
xrandr --listmonitors
echo

echo "=== Active X11 Processes ==="
ps aux | grep -E "(picom|compton|xorg|awesome)" | grep -v grep
echo

echo "=== Recent X11 Logs ==="
journalctl --since "10 minutes ago" | grep -i "xorg\|display\|monitor" | tail -10
echo

echo "=== To fix the issue, run your script: ==="
echo "~/path/to/your/display-fix-script.sh"
