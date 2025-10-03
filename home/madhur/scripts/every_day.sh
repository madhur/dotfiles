#!/bin/bash

source /home/madhur/scripts/notify_wrapper.sh

{
    run_with_notification "python /home/madhur/scripts/delete_old_screenshots.py /home/madhur/Screenshots/Timeline" "Screenshots Cleanup" "systemd"
    run_with_notification "/usr/bin/paccache -r -k 3" "Pacman cache cleanup" "systemd"
    run_with_notification "cd /home/madhur/Desktop/python/email_reader && /home/madhur/.virtualenvs/python-rsha/bin/python /home/madhur/Desktop/python/email_reader/gmail_reader.py" "Email PDF Generation" "systemd"
    run_with_notification "trash-empty 7 -f -v" "Empty Trash last 7 days" "systemd"
    run_with_notification "/home/madhur/scripts/rednotebook-backup.sh" "Rednotebook Backup" "systemd"
    run_with_notification "cd /home/madhur/Desktop/python/disk_monitor && /home/madhur/.virtualenvs/python-rsha/bin/python /home/madhur/Desktop/python/disk_monitor/monitor_disk.py" "Disk Monitor" "systemd"
} 2>&1
#find /home/madhur/.cache/ -type f -atime +30 -print -delete
#docker system prune -af --volumes
