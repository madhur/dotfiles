#!/bin/bash
~/scripts/idle-remaining.sh 2>/dev/null | sed "s/$(printf '\033')\[[0-9;]*m//g"
