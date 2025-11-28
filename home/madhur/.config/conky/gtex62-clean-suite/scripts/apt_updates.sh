#!/usr/bin/env bash
apt-get -s -o Debug::NoLocking=true upgrade 2>/dev/null \
| awk '/^[0-9]+ upgraded/ {print $1; exit}'
