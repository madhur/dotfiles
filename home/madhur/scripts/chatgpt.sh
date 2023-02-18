#!/bin/bash
INPUT=$(rofi -dmenu -p "")
if [[ -z $INPUT ]]; then
    exit 1
fi

zenity --progress --text="Waiting for an answer" --pulsate &

if [[ $? -eq 1 ]]; then
    exit 1
fi

PID=$!
source ~/pyenv3/bin/activate
ANSWER=$(sgpt "$INPUT" --no-animation --no-spinner)
kill $PID
zenity --info --text="$ANSWER"
