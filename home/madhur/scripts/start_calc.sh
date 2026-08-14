#!/bin/sh

PROJECT_DIR=/home/madhur/gitpersonal/popup_launcher

WID=$(xdotool search --name "^Calculator$" | head -1)

if [ -z "$WID" ]; then
    cd "$PROJECT_DIR"
    . .venv_run/bin/activate
    nohup python popup_launcher.py >> ~/logs/log.txt 2>&1 &
    # GTK's internal grab_focus() sets widget-level focus but can't force
    # WM-level input focus, and new-client auto-focus isn't reliable here
    # (e.g. focus-follows-mouse can keep focus wherever the pointer is).
    # Poll for the window to appear, then explicitly activate it.
    for i in $(seq 1 20); do
        NEWWID=$(xdotool search --name "^Calculator$" | head -1)
        [ -n "$NEWWID" ] && break
        sleep 0.1
    done
    [ -n "$NEWWID" ] && xdotool windowactivate "$NEWWID"
elif xdotool search --onlyvisible --name "^Calculator$" | grep -q "^$WID$"; then
    xdotool windowunmap "$WID"
else
    xdotool windowmap "$WID"
    xdotool windowactivate "$WID"
fi
