#!/bin/bash
 
if ping -c 1 -W 2 $1 > /dev/null; then
echo "Up"
else
echo "Down"
fi
