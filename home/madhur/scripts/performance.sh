#!/bin/bash
sudo cpupower frequency-set -g performance
sudo sh -c "echo '1' > /sys/devices/system/cpu/cpufreq/boost"
notify-send "Switched to performance"
