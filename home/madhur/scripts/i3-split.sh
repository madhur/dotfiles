#!/usr/bin/env bash

# Author: RayZ0rr (github.com/RayZ0rr)
#
# Dependencies:
# - jq     : To get container layout

current_layout() {
  info=$(i3-msg -t get_tree | jq -r 'recurse(.nodes[];.nodes!=null)|select(.nodes[].focused).layout')
  echo "${info}"
}

check=$(current_layout)

split_vertical() {
  if [[ "$check" == "tabbed" ]] ; then
    i3-msg focus parent, split vertical
    exit 0
  elif [[ "$check" == "stacked" ]] ; then
    i3-msg focus parent, split vertical
    exit 0
  elif [[ "$check" == "splith" ]] ; then
    i3-msg split vertical
    exit 0
  elif [[ "$check" == "splitv" ]] ; then
    i3-msg split vertical
    exit 0
  else
    printf "Scratchpad or Invalid layout\n----------------------------------------------\n"
    exit 1
  fi
}

split_horizontal() {
  if [[ "$check" == "tabbed" ]] ; then
    i3-msg focus parent, split horizontal
    exit 0
  elif [[ "$check" == "stacked" ]] ; then
    i3-msg focus parent, split horizontal
    exit 0
  elif [[ "$check" == "splith" ]] ; then
    i3-msg split horizontal
    exit 0
  elif [[ "$check" == "splitv" ]] ; then
    i3-msg split horizontal
    exit 0
  else
    printf "Scratchpad or Invalid layout\n----------------------------------------------\n"
    exit 1
  fi
}

case "${1}" in
  "vertical")
    split_vertical
    exit 0 ;;
  "horizontal")
    split_horizontal
    exit 0 ;;
  *)
    echo "Run 'i3-split.sh [vertical|horizontal]' to change split orientation for whole container"
    exit 1 ;;
esac
