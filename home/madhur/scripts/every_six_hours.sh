#!/bin/bash

source /home/madhur/scripts/notify_wrapper.sh

{
    run_with_notification "cd /home/madhur/github/python-scripts/process-rewardable-events && /home/madhur/.virtualenvs/python-scripts-yxaz/bin/python /home/madhur/github/python-scripts/process-rewardable-events/reward_recon_watch.py" "Reward Recon Watch" "every6h"
    run_with_notification "cd /home/madhur/github/python-scripts/temporal && /home/madhur/.virtualenvs/python-scripts-yxaz/bin/python /home/madhur/github/python-scripts/temporal/list_failed_workflows_watch.py" "Temporal Failed Workflows (prod)" "every6h"
} 2>&1
