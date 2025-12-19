#!/usr/bin/env python3
"""
Taskwarrior Upcoming Tasks Script
Shows only the next pending instance for each recurring task due in the next 2 days
"""

import json
import subprocess
import sys
from datetime import datetime, timedelta
from collections import defaultdict

def get_tasks():
    """Fetch pending recurring tasks due in next 2 days from Taskwarrior"""
    try:
        # Get tasks in JSON format
        result = subprocess.run(
            ['task', 'status:pending', 'due.before:2days', 'recurrence:', 'export'],
            capture_output=True,
            text=True,
            check=True
        )
        
        if not result.stdout.strip():
            return []
        
        tasks = json.loads(result.stdout)
        return tasks
    
    except subprocess.CalledProcessError as e:
        print(f"Error running task command: {e}", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"Error parsing task output: {e}", file=sys.stderr)
        sys.exit(1)

def parse_due_date(due_str):
    """Parse Taskwarrior date format to datetime"""
    from datetime import timezone
    dt = datetime.strptime(due_str, '%Y%m%dT%H%M%SZ')
    return dt.replace(tzinfo=timezone.utc)

def format_relative_due(due_date):
    """Format due date as relative time"""
    from datetime import timezone
    now = datetime.now(timezone.utc)
    diff = due_date - now
    
    if diff.total_seconds() < 0:
        days = abs(diff.days)
        if days == 0:
            return "overdue"
        elif days == 1:
            return "1 day overdue"
        else:
            return f"{days} days overdue"
    else:
        days = diff.days
        if days == 0:
            hours = diff.seconds // 3600
            if hours == 0:
                return "due soon"
            elif hours == 1:
                return "1 hour"
            else:
                return f"{hours} hours"
        elif days == 1:
            return "1 day"
        else:
            return f"{days} days"

def filter_next_instances(tasks):
    """Filter to show only the next pending instance for each recurring task"""
    # Group tasks by parent (recurring task template)
    by_parent = defaultdict(list)
    
    for task in tasks:
        if 'parent' in task:
            parent_uuid = task['parent']
            by_parent[parent_uuid].append(task)
    
    # For each parent, keep only the task with earliest due date
    next_instances = []
    for parent_uuid, parent_tasks in by_parent.items():
        # Sort by due date
        parent_tasks.sort(key=lambda t: parse_due_date(t['due']))
        # Take the first (earliest) one
        next_instances.append(parent_tasks[0])
    
    # Sort final list by due date
    next_instances.sort(key=lambda t: parse_due_date(t['due']))
    
    return next_instances

def display_tasks(tasks):
    """Display tasks in simple format: id, description followed by due"""
    for task in tasks:
        task_id = task.get('id', 0)
        description = task.get('description', 'No description')
        due_date = parse_due_date(task['due'])
        relative_due = format_relative_due(due_date)
        
        # Check if task is overdue
        from datetime import timezone
        now = datetime.now(timezone.utc)
        is_overdue = due_date < now
        
        # Add Conky color codes for overdue tasks
        if is_overdue:
            print(f"${{color orange}}{task_id:<4} {description:<50} {relative_due}${{color}}")
        else:
            print(f"${{color0}}{task_id:<4} {description:<50} {relative_due}")


def main():
    # Fetch tasks from Taskwarrior
    tasks = get_tasks()
    
    # Filter to next instance only
    next_instances = filter_next_instances(tasks)
    
    # Display results
    display_tasks(next_instances)

if __name__ == "__main__":
    main()