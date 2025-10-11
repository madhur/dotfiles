#!/bin/bash
#find /home/madhur/.cache/ -type f -atime +30 -print -delete
#docker system prune -af --volumes

source /home/madhur/scripts/notify_wrapper.sh


run_with_notification "cd /home/madhur/gitpersonal/dotfiles && node_modules/gulp-cli/bin/gulp.js backup-and-push" "Dotfiles update and push" "weekly"
run_with_notification "/home/madhur/scripts/git-automate.sh /home/madhur/docker" "Sync docker repo" "weekly"
run_with_notification "/home/madhur/scripts/git-automate.sh /home/madhur/Desktop/python" "Sync Python repo" "weekly"
run_with_notification "sudo bash -c 'cd /home/madhur/Desktop/python/disk_monitor && /home/madhur/.virtualenvs/python-rsha/bin/python /home/madhur/Desktop/python/disk_monitor/monitor_disk.py'" "Disk Monitor" "weekly"
run_with_notification "/usr/bin/paccache -r -k 3" "Pacman cache cleanup" "weekly"