#!/bin/bash

source /home/madhur/scripts/notify_wrapper.sh

{
    run_with_notification "cd /home/madhur/Desktop/python/email_reader && /home/madhur/.virtualenvs/python-rsha/bin/python /home/madhur/Desktop/python/email_reader/gmail_reader_stateful.py" "Email PDF Generation" "backup"
    run_with_notification "cd /home/madhur/Desktop/python/email_reader && /home/madhur/.virtualenvs/python-rsha/bin/python /home/madhur/Desktop/python/email_reader/gmail_reader_stateful.py -c anjli.yaml" "Anjli Email PDF Generation" "backup"
    run_with_notification "cd /home/madhur/Desktop/python/family_inbox && DISPLAY=:98 /home/madhur/.virtualenvs/python-rsha/bin/python /home/madhur/Desktop/python/family_inbox/scrape_inbox.py -a Anjli" "Family Inbox Digest (Anjli)" "private"
    run_with_notification "cd /home/madhur/Desktop/python/family_inbox && DISPLAY=:98 /home/madhur/.virtualenvs/python-rsha/bin/python /home/madhur/Desktop/python/family_inbox/scrape_inbox.py -a Om" "Family Inbox Digest (Om)" "private"
    run_with_notification "cd /home/madhur/Desktop/python/email_reader && /home/madhur/.virtualenvs/python-rsha/bin/python /home/madhur/Desktop/python/email_reader/transaction_uploader_actual.py --commit" "Actual: alert sync" "transactions"
    run_with_notification "cd /home/madhur/Desktop/python/email_reader && /home/madhur/.virtualenvs/python-rsha/bin/python /home/madhur/Desktop/python/email_reader/transaction_uploader_actual.py -c anjli.yaml --commit" "Actual: alert sync (Anjli)" "transactions"
    run_with_notification "cd /home/madhur/Desktop/python && DISPLAY=:98 /home/madhur/.virtualenvs/python-rsha/bin/python /home/madhur/Desktop/python/desitorrents_login.py" "DesiTorrents Trending Screenshot" "daily"
    run_with_notification "cd /home/madhur/github/python-scripts/ach_monitoring && /home/madhur/.virtualenvs/python-scripts-yxaz/bin/python /home/madhur/github/python-scripts/ach_monitoring/monitor_watch.py" "ACH Monitor (prod) → Mailpit" "monitoring"
} 2>&1
