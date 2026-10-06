
#!/bin/bash

# Get current day of year (1-366)
current_day=$(date +%j)

# Get total days in current year
total_days=$(date -d "31 Dec $(date +%Y)" +%j)

# Calculate percentage, rounding to nearest integer
percentage=$(echo "($current_day / $total_days) * 100" | bc -l | xargs printf "%.0f")

echo "$percentage"
