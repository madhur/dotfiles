#!/bin/bash

source /home/madhur/scripts/notify_wrapper.sh

{
    run_with_notification "cd /home/madhur/Desktop/python/email_reader && /home/madhur/.virtualenvs/python-rsha/bin/python /home/madhur/Desktop/python/email_reader/gmail_reader.py" "Email PDF Generation" "daily"
    run_with_notification "cd /home/madhur/Desktop/python/email_reader && /home/madhur/.virtualenvs/python-rsha/bin/python /home/madhur/Desktop/python/email_reader/gmail_reader_v2.py -c anjli.yaml" "Anjli Email PDF Generation" "daily"
    run_with_notification "cd /home/madhur/Desktop/python/family_inbox && DISPLAY=:98 /home/madhur/.virtualenvs/python-rsha/bin/python /home/madhur/Desktop/python/family_inbox/scrape_inbox.py" "Family Inbox Digest" "private"
} 2>&1
