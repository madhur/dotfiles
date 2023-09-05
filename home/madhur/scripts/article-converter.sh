#!/bin/sh
date=$(date "+%F")
uuid=$(uuidgen)
filename="$date $uuid"
pandoc /tmp/article.html -o /tmp/article.md &&  cat /tmp/article.md >> "$HOME/docs/articles/$filename.md" && rm /tmp/article.*
kitty --hold glow "$HOME/docs/articles/$filename.md" &

#echo $'\n------------------------------------------------------------------------ \n' >> $HOME/docs/articles/$date.md
#date=$(date "+%F")
