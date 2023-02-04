#!/usr/bin/env bash

i3-msg "split h, layout tabbed"
i3-msg "exec i3 open"
clear
sleep 1
# case "$@" in
#   "vertical")
#     i3-msg "split h, layout tabbed"
#     i3-msg "exec i3 open"
#     clear
#     sleep 1
#     ;;
#   "horizontal")
#     i3-msg "split v, layout tabbed"
#     i3-msg "exec i3 open"
#     clear
#     sleep 1
#     ;;
#   *)
#     echo "Invalid argument. Use either $0 'vertical' or 'horizontal'"
#     ;;
# esac

# OLD
# i3-msg "split h, layout tabbed"
# # i3-msg "exec alacritty -t i3-msg"
# i3-msg "exec i3 open"
# sleep 1
# clear
# # clear
# # alacritty -t background &
# # # alacritty
# # alacritty -t second
# # $SHELL

