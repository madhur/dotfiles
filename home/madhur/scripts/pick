#!/usr/bin/env bash

read -r red green blue < <(zenity --color-selection \
  | awk --field-separator ',' '{
  gsub("rgb\\(","");
  gsub("\\)","");
  print $1" "$2" "$3
}')

printf '#%0X%0X%0X' "$red" "$green" "$blue" | xclip

# vim:ft=sh
