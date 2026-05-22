#!/bin/bash

source /home/madhur/scripts/notify_wrapper.sh

{
    run_with_notification "cd /home/madhur/Desktop/python/email_reader && /home/madhur/.virtualenvs/python-rsha/bin/python /home/madhur/Desktop/python/email_reader/gmail_reader_stateful.py" "Email PDF Generation" "daily"
    run_with_notification "cd /home/madhur/Desktop/python/email_reader && /home/madhur/.virtualenvs/python-rsha/bin/python /home/madhur/Desktop/python/email_reader/gmail_reader_stateful.py -c anjli.yaml" "Anjli Email PDF Generation" "daily"
    run_with_notification "cd /home/madhur/Desktop/python/family_inbox && DISPLAY=:98 /home/madhur/.virtualenvs/python-rsha/bin/python /home/madhur/Desktop/python/family_inbox/scrape_inbox.py -a Anjli" "Family Inbox Digest (Anjli)" "private"
    run_with_notification "cd /home/madhur/Desktop/python/family_inbox && DISPLAY=:98 /home/madhur/.virtualenvs/python-rsha/bin/python /home/madhur/Desktop/python/family_inbox/scrape_inbox.py -a Om" "Family Inbox Digest (Om)" "private"
    run_with_notification "cd /home/madhur/Desktop/python/email_reader && /home/madhur/.virtualenvs/python-rsha/bin/python /home/madhur/Desktop/python/email_reader/transaction_uploader_actual.py --commit" "Actual: alert sync" "private"
    run_with_notification "cd /home/madhur/Desktop/python/email_reader && /home/madhur/.virtualenvs/python-rsha/bin/python /home/madhur/Desktop/python/email_reader/transaction_uploader_actual.py -c anjli.yaml --commit" "Actual: alert sync (Anjli)" "private"
} 2>&1
