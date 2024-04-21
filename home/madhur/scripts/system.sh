#!/bin/bash

# Check if user provided an argument
if [ $# -ne 1 ]; then
    echo "Usage: $0 [reboot | poweroff | logoff]"
    exit 1
fi

# Check the argument provided
case $1 in
    "reboot")
        echo "Rebooting the system..."
        sudo reboot
        ;;
    "poweroff")
        echo "Shutting down the system..."
        sudo poweroff
        ;;
    "logoff")
        echo "Logging off the current user..."
        pkill -KILL -u $(whoami)
        ;;
    *)
        echo "Invalid argument. Please specify 'reboot', 'poweroff', or 'logoff'."
        exit 1
        ;;
esac

exit 0
