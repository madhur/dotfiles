#!/bin/bash
#find /home/madhur/.cache/ -type f -atime +30 -print -delete
#docker system prune -af --volumes
#cd /home/madhur/Desktop/python/email_reader && /home/madhur/.virtualenvs/python-rsha/bin/python /home/madhur/Desktop/python/email_reader/gmail_reader.py

cd /home/madhur/gitpersonal/madhur.github.com 
source /home/madhur/.rvm/scripts/rvm
rvm use 2.7.3
/home/madhur/.rvm/gems/ruby-2.7.3/bin/bundle exec jekyll build
cd /home/madhur/gitpersonal/madhur.github.com && node_modules/gulp-cli/bin/gulp.js deploywithoutbuild