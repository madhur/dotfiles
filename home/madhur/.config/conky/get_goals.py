#!/usr/bin/env python3
"""
Script to read short-term goals from CSV and display them in tabular format for Conky
"""

import csv
import os
from datetime import datetime, timedelta
from typing import List, Tuple

def parse_target_date(target_str: str) -> datetime:
    """Parse target date string (e.g., 'Dec 2025', '2025-12', 'December 2025')"""
    target_str = target_str.strip()
    
    try:
        # Try different date formats
        formats = [
            '%b %Y',        # Dec 2025
            '%B %Y',        # December 2025
            '%Y-%m',        # 2025-12
            '%m/%Y',        # 12/2025
            '%Y',           # Just year (assumes December)
        ]
        
        for fmt in formats:
            try:
                if fmt == '%Y':
                    # For year only, assume end of year
                    return datetime.strptime(f"{target_str}-12", '%Y-%m')
                else:
                    return datetime.strptime(target_str, fmt)
            except ValueError:
                continue
        
        # If no format matches, return a far future date
        return datetime(2030, 12, 31)
        
    except Exception:
        return datetime(2030, 12, 31)

def format_time_left(target_date: datetime) -> str:
    """Format time left until target date"""
    now = datetime.now()
    diff = target_date - now
    
    if diff.days < 0:
        return "OVERDUE"
    elif diff.days == 0:
        return "TODAY"
    elif diff.days == 1:
        return "1 day"
    elif diff.days < 30:
        return f"{diff.days} days"
    elif diff.days < 365:
        months = diff.days // 30
        return f"{months} month{'s' if months > 1 else ''}"
    else:
        years = diff.days // 365
        return f"{years} year{'s' if years > 1 else ''}"

def read_goals(csv_file: str) -> List[Tuple[str, str, str, datetime]]:
    """Read goals from CSV file"""
    goals = []
    
    if not os.path.exists(csv_file):
        return goals
    
    try:
        with open(csv_file, 'r', encoding='utf-8') as file:
            reader = csv.DictReader(file)
            
            for row in reader:
                if not all(key in row for key in ['goal', 'target_date']):
                    continue
                
                goal_text = row['goal'].strip()
                target_str = row['target_date'].strip()
                
                if not goal_text or not target_str:
                    continue
                
                try:
                    target_date = parse_target_date(target_str)
                    time_left = format_time_left(target_date)
                    
                    goals.append((goal_text, time_left, target_str, target_date))
                    
                except Exception:
                    continue
    
    except Exception:
        return []
    
    # Sort by target date (most urgent first)
    goals.sort(key=lambda x: x[3])
    
    return goals

def format_goals_table(goals: List[Tuple[str, str, str, datetime]]) -> str:
    """Format goals as a table for display"""
    if not goals:
        return "No goals set"
    
    # Calculate column widths
    max_goal_width = max(len(goal[0]) for goal in goals)
    max_time_width = max(len(goal[1]) for goal in goals)
    
    # Set minimum widths and add padding
    goal_width = max(max_goal_width, 20) + 2
    time_width = max(max_time_width, 10) + 2
    
    # Create header
    header = f"{'Goal':<{goal_width}} | {'Time Left':<{time_width}}"
    separator = f"{'-' * goal_width}-+-{'-' * time_width}"
    
    # Format rows
    formatted_lines = [header, separator]
    
    for goal_text, time_left, _, _ in goals:
        # Truncate goal text if it's too long for display
        display_goal = goal_text[:goal_width-2] + ".." if len(goal_text) > goal_width-2 else goal_text
        row = f"{display_goal:<{goal_width}} | {time_left:<{time_width}}"
        formatted_lines.append(row)
    
    return "\n".join(formatted_lines)

def format_goals_simple_table(goals: List[Tuple[str, str, str, datetime]]) -> str:
    """Format goals as a simple aligned table (better for Conky)"""
    if not goals:
        return "No goals set"
    
    # Calculate maximum goal text width for alignment
    max_goal_width = max(len(goal[0]) for goal in goals) if goals else 0
    max_goal_width = min(max_goal_width, 40)  # Limit width for Conky display
    
    formatted_lines = []
    
    for goal_text, time_left, _, _ in goals:
        # Truncate goal text if too long
        display_goal = goal_text[:max_goal_width-2] + ".." if len(goal_text) > max_goal_width else goal_text
        
        # Right-pad goal text and add time left
        line = f"* {display_goal:<{max_goal_width}} {time_left:>12}"
        formatted_lines.append(line)
    
    return "\n".join(formatted_lines)

def main():
    """Main function to get and display goals"""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    csv_file = os.path.join(script_dir, 'goals.csv')
    
    goals = read_goals(csv_file)
    
    # Choose format based on preference
    # Use format_goals_table() for full table with borders
    # Use format_goals_simple_table() for cleaner Conky display
    formatted_output = format_goals_simple_table(goals)
    
    print(formatted_output)

if __name__ == "__main__":
    main()