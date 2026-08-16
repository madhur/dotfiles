#!/bin/bash
#find /home/madhur/.cache/ -type f -atime +30 -print -delete
#docker system prune -af --volumes
#cd /home/madhur/Desktop/python/email_reader && /home/madhur/.virtualenvs/python-rsha/bin/python /home/madhur/Desktop/python/email_reader/gmail_reader.py

source /home/madhur/scripts/notify_wrapper.sh
export NOTIFY_ON_SUCCESS=true

# Blog moved from Jekyll to Hugo (2026-08). scripts/deploy.sh builds and
# pushes to master in one step, so there's no separate build command here
# anymore -- no Ruby/rvm needed either, Hugo is a single binary on PATH.
run_with_notification "cd /home/madhur/gitpersonal/madhur.github.com && bash scripts/deploy.sh" "madhur.co.in blog publish" "monthly"
run_with_notification "/home/madhur/scripts/firefly_digest.py monthly" "Firefly Monthly Digest → Mailpit" "monitoring"