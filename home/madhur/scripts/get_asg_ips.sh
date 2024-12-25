#!/bin/bash

if [ $# -ne 1 ]; then
    echo "Usage: $0 <asg-name>"
    exit 1
fi

ASG_NAME="$1"

aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-name "$ASG_NAME" \
    --query 'AutoScalingGroups[0].Instances[?LifecycleState==`InService`].InstanceId' \
    --output text | \
tr '\t' '\n' | \
while read -r instance_id; do
    [ -n "$instance_id" ] && aws ec2 describe-instances \
        --instance-ids "$instance_id" \
        --query 'Reservations[0].Instances[0].PrivateIpAddress' \
        --output text
done | grep -v '^None$' | paste -sd "," -
