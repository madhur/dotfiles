#!/usr/bin/zsh
 desktop=`bspc query -T -d | jq -r .layout`
 node=`bspc query -T -n | jq -r .client.state`
 printf "${desktop}, ${node}"