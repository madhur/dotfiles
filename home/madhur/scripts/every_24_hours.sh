#!/bin/bash

source /home/madhur/scripts/notify_wrapper.sh

{
    run_with_notification "python /home/madhur/scripts/delete_old_screenshots.py /home/madhur/Screenshots/Timeline" "Screenshots Cleanup" "daily"
    run_with_notification "trash-empty 7 -f -v" "Empty Trash last 7 days" "daily"
    run_with_notification "/home/madhur/scripts/rednotebook-backup.sh" "Rednotebook Backup" "daily"
    run_with_notification "sudo pacman -Syu --noconfirm" "System Update" "daily"
    run_with_notification "/home/madhur/.virtualenvs/python-rsha/bin/python /home/madhur/Desktop/python/weather_monitor.py fetch" "Weather Data Fetch" "daily"
    run_with_notification "/home/madhur/.virtualenvs/python-rsha/bin/python /home/madhur/Desktop/python/weather_monitor.py graph --days 30" "Weather Graph Report" "daily"
    run_with_notification "cd /home/madhur/Desktop/python/google_photos_fetcher && DISPLAY=:98 /home/madhur/.virtualenvs/python-rsha/bin/python screenshot_homepage.py" "Dad Google Photos Screenshot" "private"
    run_with_notification "cd /home/madhur/Desktop/python/icici_reader && set -a && . ./.env && set +a && DISPLAY=:98 /home/madhur/.virtualenvs/python-rsha/bin/python ./icici_login.py" "ICICI Transactions Screenshot" "private"
} 2>&1
#find /home/madhur/.cache/ -type f -atime +30 -print -delete
#docker system prune -af --volumes
