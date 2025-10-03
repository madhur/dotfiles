#!/bin/bash
#find /home/madhur/.cache/ -type f -atime +30 -print -delete
#docker system prune -af --volumes

source /home/madhur/scripts/notify_wrapper.sh


run_with_notification "cd /home/madhur/gitpersonal/dotfiles && node_modules/gulp-cli/bin/gulp.js backup-and-push" "Dotfiles update and push" "systemd"
run_with_notification "/home/madhur/scripts/git-automate.sh /home/madhur/docker" "Sync docker repo" "systemd"
run_with_notification "/home/madhur/scripts/git-automate.sh /home/madhur/Desktop/python" "Sync Python repo" "systemd"