#!/bin/bash

# Get current year
year=$(date +%Y)

# Get current day of year (1-366)
current_day=$(date +%j)

# Get total days in current year
total_days=$(date -d "31 Dec $year" +%j)

# Calculate percentage, rounding to nearest integer
percentage=$(echo "($current_day / $total_days) * 100" | bc -l | xargs printf "%.0f")

# Print result in requested format
echo "$year is $percentage% complete."