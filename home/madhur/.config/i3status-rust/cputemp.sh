#!/usr/bin/zsh
temp=`sensors | grep Tccd1: | cut -c 16-19`
printf "\uf76b $temp °C"
