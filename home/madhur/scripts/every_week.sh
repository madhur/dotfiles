#!/bin/bash
#find /home/madhur/.cache/ -type f -atime +30 -print -delete
#docker system prune -af --volumes
cd /home/madhur/Desktop/python/email_reader && /home/madhur/.virtualenvs/python-rsha/bin/python /home/madhur/Desktop/python/email_reader/gmail_reader.py

cd /home/madhur/gitpersonal/dotfiles && node_modules/gulp-cli/bin/gulp.js backup-and-push