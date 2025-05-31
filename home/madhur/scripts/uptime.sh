#!/bin/bash

# Read uptime from /proc/uptime (first value is total uptime in seconds)
uptime_data=$(cat /proc/uptime 2>/dev/null)

if [[ -z "$uptime_data" ]]; then
    echo "Error: Failed to read uptime data"
    exit 1
fi

# Extract seconds (before the decimal point)
total_seconds=$(echo "$uptime_data" | cut -d'.' -f1)

# Validate that we got a number
if ! [[ "$total_seconds" =~ ^[0-9]+$ ]]; then
    echo "Error: Invalid uptime data"
    exit 1
fi

# Calculate time units
weeks=$((total_seconds / 604800))
remaining=$((total_seconds % 604800))

days=$((remaining / 86400))
remaining=$((remaining % 86400))

hours=$((remaining / 3600))
remaining=$((remaining % 3600))

minutes=$((remaining / 60))

# Format result based on largest time unit
if [[ $weeks -ge 1 ]]; then
    result="${weeks}w ${days}d"
elif [[ $days -ge 1 ]]; then
    result="${days}d ${hours}h"
elif [[ $hours -ge 1 ]]; then
    result="${hours}h ${minutes}m"
else
    result="${hours}h ${minutes}m"
fi

echo "$result"
