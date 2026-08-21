#!/bin/bash
#find /home/madhur/.cache/ -type f -atime +30 -print -delete
#docker system prune -af --volumes

source /home/madhur/scripts/notify_wrapper.sh
export NOTIFY_ON_SUCCESS=true


# include_output=false on these four: each sync job pushes its own ntfy
# notification with just the LLM commit message (see homelab.clients.git),
# so the wrapper's success ping doesn't also need to dump the raw
# staging/git log noise.
run_with_notification "/home/madhur/scripts/star_history_digest.py" "Star History Chart" "weekly"
run_with_notification "cd /home/madhur/gitpersonal/dotfiles && node_modules/gulp-cli/bin/gulp.js backup-and-push" "Dotfiles update and push" "weekly" "false" "true" "false"
run_with_notification "/home/madhur/scripts/git-automate.sh /home/madhur/docker" "Sync docker repo" "weekly" "false" "true" "false"
run_with_notification "/home/madhur/scripts/docker-private-backup.sh" "Sync docker private repo" "weekly" "false" "true" "false"
run_with_notification "/home/madhur/scripts/git-automate.sh /home/madhur/Desktop/python" "Sync Python repo" "weekly" "false" "true" "false"
run_with_notification "sudo bash -c 'cd /home/madhur/Desktop/python/disk_monitor && /home/madhur/.virtualenvs/python-rsha/bin/python /home/madhur/Desktop/python/disk_monitor/monitor_disk.py'" "Disk Monitor" "monitoring"
run_with_notification "/usr/bin/paccache -r -k 1" "Pacman cache cleanup" "weekly"
run_with_notification "docker image prune -f" "Docker image cleanup" "weekly"
run_with_notification "/home/madhur/scripts/firefly_digest.py weekly" "Firefly Weekly Digest → Mailpit" "monitoring"
run_with_notification "/home/madhur/scripts/loan_prepayment_digest.py" "Loan Prepayment Digest → Mailpit" "monitoring"
run_with_notification "cd /home/madhur/Desktop/python && DISPLAY=:98 /home/madhur/.virtualenvs/python-rsha/bin/python /home/madhur/Desktop/python/hdtorrents_login.py" "HD-Torrents Login Screenshot" "weekly"
run_with_notification "/home/madhur/scripts/fail2ban-summary.sh" "Fail2ban Daily Summary → n8n" "monitoring"
run_with_notification "/home/madhur/scripts/docker_digest.py" "Docker Homelab Digest → Mailpit" "monitoring"
run_with_notification "/home/madhur/.virtualenvs/python-rsha/bin/python /home/madhur/Desktop/python/aws_cost_explorer/aws_cost_digest.py" "AWS Cost Daily Digest → Mailpit" "monitoring"