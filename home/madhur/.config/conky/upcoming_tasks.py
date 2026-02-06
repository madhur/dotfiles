#!/usr/bin/env python3
"""
Taskwarrior Display Script for Conky
Formats any taskwarrior filter with relative time display and overdue coloring.
Auto-detects recurring tasks and applies next-instance filtering when needed.
"""

import argparse
import json
import subprocess
import sys
from datetime import datetime, timedelta
from collections import defaultdict

def parse_arguments():
    """Parse command-line arguments for taskwarrior filters"""
    parser = argparse.ArgumentParser(description='Format taskwarrior output for Conky')
    parser.add_argument('filter_args', nargs='*',
                       help='Taskwarrior filter arguments (e.g., status:pending +work)')
    parser.add_argument('--no-auto-filter', action='store_true',
                       help='Disable automatic next-instance filtering for recurring tasks')
    parser.add_argument('--max-width', type=int, default=30,
                       help='Maximum description width (default: 30)')
    parser.add_argument('--show-id', dest='show_id', action='store_true', default=True,
                       help='Show task ID column (default: true)')
    parser.add_argument('--no-show-id', dest='show_id', action='store_false',
                       help='Hide task ID column')
    return parser.parse_args()

def get_tasks(filter_args):
    """Fetch tasks from Taskwarrior using provided filter arguments"""
    try:
        # Build command: task [filter_args...] export
        cmd = ['task', 'rc.gc=0', 'rc.recurrence=0', 'rc.readonly=true'] + list(filter_args) + ['export']

        # Get tasks in JSON format
        result = subprocess.run(
            cmd,
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
    """Format due date as relative time with compact notation (1d, 2w, 1y, etc.)"""
    from datetime import timezone
    now = datetime.now(timezone.utc)
    diff = due_date - now

    if diff.total_seconds() < 0:
        # Overdue tasks
        days = abs(diff.days)
        if days == 0:
            return "overdue"
        elif days < 7:
            return f"{days}d overdue"
        elif days < 30:
            weeks = days // 7
            return f"{weeks}w overdue"
        elif days < 365:
            months = days // 30
            return f"{months}mo overdue"
        else:
            years = days // 365
            return f"{years}y overdue"
    else:
        # Upcoming tasks
        days = diff.days
        if days == 0:
            hours = diff.seconds // 3600
            if hours == 0:
                return "now"
            else:
                return f"{hours}h"
        elif days < 7:
            return f"{days}d"
        elif days < 30:
            weeks = days // 7
            return f"{weeks}w"
        elif days < 365:
            months = days // 30
            return f"{months}mo"
        else:
            years = days // 365
            return f"{years}y"

def has_recurring_instances(tasks):
    """Check if any tasks have parent field (indicating recurring instances)"""
    return any('parent' in task for task in tasks)

def sort_tasks(tasks):
    """Sort tasks by due date (overdue tasks first), then by urgency"""
    def sort_key(task):
        if 'due' in task:
            return (0, parse_due_date(task['due']))
        else:
            return (1, -task.get('urgency', 0))

    tasks.sort(key=sort_key)
    return tasks

def filter_next_instances(tasks):
    """
    Filter to show only the next pending instance for each recurring task.
    Non-recurring tasks are passed through unchanged.
    """
    # Separate recurring from non-recurring tasks
    recurring_tasks = []
    non_recurring_tasks = []

    for task in tasks:
        if 'parent' in task:
            recurring_tasks.append(task)
        else:
            non_recurring_tasks.append(task)

    # Group recurring tasks by parent (recurring task template)
    by_parent = defaultdict(list)
    for task in recurring_tasks:
        parent_uuid = task['parent']
        by_parent[parent_uuid].append(task)

    # For each parent, keep only the task with earliest due date
    next_instances = []
    for parent_uuid, parent_tasks in by_parent.items():
        # Sort by due date if present
        if all('due' in t for t in parent_tasks):
            parent_tasks.sort(key=lambda t: parse_due_date(t['due']))
            next_instances.append(parent_tasks[0])
        else:
            # If no due date, just take first
            next_instances.append(parent_tasks[0])

    # Combine non-recurring tasks with filtered recurring tasks
    all_tasks = non_recurring_tasks + next_instances

    return all_tasks

def display_tasks(tasks, show_id=True, max_width=30):
    """Display tasks in Conky format: id, description followed by due"""
    for task in tasks:
        task_id = task.get('id', 0)
        description = task.get('description', 'No description')

        # Truncate description if needed
        if len(description) > max_width:
            description = description[:max_width-3] + '...'

        # Handle tasks with due dates
        if 'due' in task:
            due_date = parse_due_date(task['due'])
            relative_due = format_relative_due(due_date)

            # Check if task is overdue
            from datetime import timezone
            now = datetime.now(timezone.utc)
            is_overdue = due_date < now

            # Add Conky color codes for overdue tasks
            if is_overdue:
                if show_id:
                    print(f"${{color orange}}{task_id:<4} {description:<{max_width}} {relative_due}${{color}}")
                else:
                    print(f"${{color orange}}{description:<{max_width}} {relative_due}${{color}}")
            else:
                if show_id:
                    print(f"${{color0}}{task_id:<4} {description:<{max_width}} {relative_due}")
                else:
                    print(f"${{color0}}{description:<{max_width}} {relative_due}")
        else:
            # Tasks without due dates (no overdue coloring)
            if show_id:
                print(f"${{color0}}{task_id:<4} {description}")
            else:
                print(f"${{color0}}{description}")


def main():
    # Parse command-line arguments
    args = parse_arguments()

    # Fetch tasks from Taskwarrior
    tasks = get_tasks(args.filter_args)

    # Exit gracefully if no tasks
    if not tasks:
        sys.exit(0)

    # Check if filter explicitly requests recurring tasks only
    only_recurring = 'recurrence:' in args.filter_args

    # Auto-detect and apply next-instance filtering if needed
    if not args.no_auto_filter and has_recurring_instances(tasks):
        tasks = filter_next_instances(tasks)

        # If filtering for recurring tasks only, exclude non-recurring tasks
        if only_recurring:
            tasks = [t for t in tasks if 'parent' in t]

    # Always sort tasks by due date (overdue first)
    tasks = sort_tasks(tasks)

    # Display results
    display_tasks(tasks, show_id=args.show_id, max_width=args.max_width)

if __name__ == "__main__":
    main()