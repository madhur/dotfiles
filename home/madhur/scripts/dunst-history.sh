#!/bin/sh
count=$(dunstctl count history)
for i in $(seq 1 "$count"); do
    dunstctl history-pop
done
