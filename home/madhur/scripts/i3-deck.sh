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

split_tabbed() {
  if [[ "$check" == "tabbed" ]] ; then
    i3-msg 'layout tabbed'
    exit 0
  elif [[ "$check" == "stacked" ]] ; then
    i3-msg 'layout tabbed'
    exit 0
  elif [[ "$check" == "splith" ]] ; then
    i3-msg 'split h, layout tabbed'
    exit 0
  elif [[ "$check" == "splitv" ]] ; then
    i3-msg 'split v, layout tabbed'
    exit 0
  else
    printf "Scratchpad or Invalid layout\n----------------------------------------------\n"
    exit 1
  fi
}

split_stacking() {
  if [[ "$check" == "tabbed" ]] ; then
    i3-msg 'layout stacking'
    exit 0
  elif [[ "$check" == "stacked" ]] ; then
    i3-msg 'layout stacking'
    exit 0
  elif [[ "$check" == "splith" ]] ; then
    i3-msg 'split h, layout stacking'
    exit 0
  elif [[ "$check" == "splitv" ]] ; then
    i3-msg 'split v, layout stacking'
    exit 0
  else
    printf "Scratchpad or Invalid layout\n----------------------------------------------\n"
    exit 1
  fi
}

case "${1}" in
  "tabbed")
    split_tabbed
    exit 0 ;;
  "stacking")
    split_stacking
    exit 0 ;;
  *)
    echo "Run 'i3-deck.sh [tabbed|stacking]' to create split container with tabbed or stacking layout"
    exit 1 ;;
esac

