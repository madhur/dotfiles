#!/bin/bash
sudo cpupower frequency-set -g powersave
sudo sh -c "echo '0' > /sys/devices/system/cpu/cpufreq/boost"
notify-send "Switched to powersave"
