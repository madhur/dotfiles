#!/bin/bash

source /home/madhur/scripts/notify_wrapper.sh

{
    run_with_notification "cd /home/madhur/github/python-scripts/process-rewardable-events && /home/madhur/.virtualenvs/python-scripts-yxaz/bin/python /home/madhur/github/python-scripts/process-rewardable-events/reward_recon_v2_watch.py" "Reward Recon V2 Watch" "monitoring"
#    run_with_notification "cd /home/madhur/github/python-scripts/process-rewardable-events && /home/madhur/.virtualenvs/python-scripts-yxaz/bin/python /home/madhur/github/python-scripts/process-rewardable-events/reward_dup_watch.py" "Reward Dup Watch → Mailpit" "monitoring"
    run_with_notification "cd /home/madhur/github/python-scripts/temporal && /home/madhur/.virtualenvs/python-scripts-yxaz/bin/python /home/madhur/github/python-scripts/temporal/list_failed_workflows_watch.py" "Temporal Failed Workflows (prod)" "monitoring"
    run_with_notification "cd /home/madhur/github/python-scripts/temporal && /home/madhur/.virtualenvs/python-scripts-yxaz/bin/python /home/madhur/github/python-scripts/temporal/list_failed_workflows_watch.py --env-file .env_booster_prod --label booster-prod" "Temporal Failed Workflows (booster-prod)" "monitoring"
    run_with_notification "cd /home/madhur/github/python-scripts/problem-tickets-updates && /home/madhur/.virtualenvs/python-scripts-yxaz/bin/python /home/madhur/github/python-scripts/problem-tickets-updates/jira_cluster_monitor_watch.py" "Jira Cluster Monitor → Mailpit" "monitoring"
} 2>&1
