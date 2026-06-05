#!/bin/bash

source /home/madhur/scripts/notify_wrapper.sh

{
    run_with_notification "python /home/madhur/scripts/delete_old_screenshots.py /home/madhur/Screenshots/Timeline" "Screenshots Cleanup" "daily"
    run_with_notification "trash-empty 7 -f -v" "Empty Trash last 7 days" "daily"
    run_with_notification "/home/madhur/scripts/rednotebook-backup.sh" "Rednotebook Backup" "daily"
    run_with_notification "sudo pacman -Syu --noconfirm" "System Update" "daily"
    run_with_notification "/home/madhur/.virtualenvs/python-rsha/bin/python /home/madhur/Desktop/python/weather_monitor.py fetch" "Weather Data Fetch" "weather"
    run_with_notification "/home/madhur/.virtualenvs/python-rsha/bin/python /home/madhur/Desktop/python/weather_monitor.py graph --days 30" "Weather Graph Report" "weather"
    run_with_notification "cd /home/madhur/Desktop/python/email_reader && /home/madhur/.virtualenvs/python-rsha/bin/python /home/madhur/Desktop/python/email_reader/call_log_uploader.py --commit" "Call Log → Nextcloud Calendar" "backup"
    run_with_notification "cd /home/madhur/Desktop/python/email_reader && /home/madhur/.virtualenvs/python-rsha/bin/python /home/madhur/Desktop/python/email_reader/sms_calendar_uploader.py --commit" "SMS → Nextcloud Calendar" "backup"
    run_with_notification "cd /home/madhur/Desktop/python/google_photos_fetcher && DISPLAY=:98 /home/madhur/.virtualenvs/python-rsha/bin/python screenshot_homepage.py" "Dad Google Photos Screenshot" "private"
    run_with_notification "cd /home/madhur/Desktop/python/icici_reader && DISPLAY=:98 /home/madhur/.virtualenvs/python-rsha/bin/python ./icici_login.py --profile anjli" "ICICI Anjli Transactions Screenshot" "private"
    run_with_notification "/home/madhur/docker/n8n/scripts/authelia-audit.sh" "Authelia Login Audit → n8n" "monitoring"
    run_with_notification "/home/madhur/docker/n8n/scripts/container-restart-digest.sh" "Container Restart Digest → n8n" "monitoring"
    run_with_notification "/home/madhur/docker/n8n/scripts/pacman-summary.sh" "Pacman Activity Summary → n8n" "monitoring"
    run_with_notification "/home/madhur/docker/n8n/scripts/fail2ban-summary.sh" "Fail2ban Daily Summary → n8n" "monitoring"
    run_with_notification "/home/madhur/docker/n8n/scripts/journal-summary.sh" "Systemd Journal Digest → n8n" "monitoring"
    run_with_notification "/home/madhur/docker/bookstack/scripts/bookstack_digest.py" "BookStack Daily Digest → Mailpit" "monitoring"
} 2>&1
#find /home/madhur/.cache/ -type f -atime +30 -print -delete
#docker system prune -af --volumes
