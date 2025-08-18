#!/usr/bin/env python3
"""
Script to read recurring events from CSV and display them for Conky
Format matches your existing Google Calendar output
"""

import csv
import os
from datetime import datetime, timedelta
from typing import List, Tuple

def get_day_name(date_obj: datetime) -> str:
    """Get human-readable day name"""
    today = datetime.now().date()
    tomorrow = today + timedelta(days=1)
    
    if date_obj.date() == today:
        return "Today"
    elif date_obj.date() == tomorrow:
        return "Tomorrow"
    else:
        return date_obj.strftime("%A")  # Full day name

def parse_time(time_str: str) -> datetime:
    """Parse time string (e.g., '8:00 AM', '21:00') to datetime object"""
    time_str = time_str.strip()
    
    # Handle 24-hour format
    if ':' in time_str and ('AM' not in time_str.upper() and 'PM' not in time_str.upper()):
        try:
            time_obj = datetime.strptime(time_str, '%H:%M').time()
        except ValueError:
            # Try without minutes
            time_obj = datetime.strptime(time_str, '%H').time()
    else:
        # Handle 12-hour format
        try:
            time_obj = datetime.strptime(time_str, '%I:%M %p').time()
        except ValueError:
            try:
                time_obj = datetime.strptime(time_str, '%I %p').time()
            except ValueError:
                # Default to current time if parsing fails
                time_obj = datetime.now().time()
    
    # Combine with today's date
    today = datetime.now().date()
    return datetime.combine(today, time_obj)

def should_show_event(frequency: str, current_date: datetime) -> bool:
    """Determine if event should be shown based on frequency"""
    frequency = frequency.lower().strip()
    
    if frequency == 'daily':
        return True
    elif frequency == 'weekdays':
        return current_date.weekday() < 5  # Monday = 0, Friday = 4
    elif frequency == 'weekends':
        return current_date.weekday() >= 5  # Saturday = 5, Sunday = 6
    elif frequency in ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday']:
        day_map = {
            'monday': 0, 'tuesday': 1, 'wednesday': 2, 'thursday': 3,
            'friday': 4, 'saturday': 5, 'sunday': 6
        }
        return current_date.weekday() == day_map[frequency]
    
    return False

def read_recurring_events(csv_file: str) -> List[Tuple[str, str, str, str]]:
    """Read recurring events from CSV file"""
    events = []
    
    if not os.path.exists(csv_file):
        return events
    
    try:
        with open(csv_file, 'r', encoding='utf-8') as file:
            reader = csv.DictReader(file)
            current_time = datetime.now()
            
            for row in reader:
                if not all(key in row for key in ['time', 'event', 'frequency']):
                    continue
                
                time_str = row['time'].strip()
                event_name = row['event'].strip()
                frequency = row['frequency'].strip()
                
                if not time_str or not event_name or not frequency:
                    continue
                
                # Parse the time
                try:
                    event_time = parse_time(time_str)
                    
                    # Check if this event should be shown today
                    if should_show_event(frequency, current_time):
                        # Only show today's events if they haven't passed yet
                        if event_time >= current_time:
                            time_display = event_time.strftime('%I:%M %p').lstrip('0')
                            day_name = "Today"
                            
                            events.append((day_name, time_display, event_name, event_time))
                        else:
                            # If today's event has passed, show it for tomorrow instead
                            tomorrow = current_time + timedelta(days=1)
                            if should_show_event(frequency, tomorrow):
                                time_display = event_time.strftime('%I:%M %p').lstrip('0')
                                day_name = "Tomorrow"
                                tomorrow_time = datetime.combine(tomorrow.date(), event_time.time())
                                
                                events.append((day_name, time_display, event_name, tomorrow_time))
                    else:
                        # If event doesn't occur today, check tomorrow
                        tomorrow = current_time + timedelta(days=1)
                        if should_show_event(frequency, tomorrow):
                            time_display = event_time.strftime('%I:%M %p').lstrip('0')
                            day_name = "Tomorrow"
                            tomorrow_time = datetime.combine(tomorrow.date(), event_time.time())
                            
                            events.append((day_name, time_display, event_name, tomorrow_time))
                        
                except Exception as e:
                    # Skip problematic entries
                    continue
    
    except Exception as e:
        # Return empty list if file can't be read
        return []
    
    # Sort events by time
    events.sort(key=lambda x: x[3])  # Sort by datetime object
    
    # Remove the datetime object from the tuple (keep only display info)
    return [(day, time, event, None) for day, time, event, _ in events]

def format_events(events: List[Tuple[str, str, str, None]]) -> str:
    """Format events to match your existing calendar output style"""
    if not events:
        return ""
    
    formatted_lines = []
    
    for day, time, event_name, _ in events:
        # Match your existing format: "Tomorrow          All Day   Parents: Mount Abu"
        # The spacing appears to be: Day(variable) + spaces to pad to 18 chars + Time(variable) + 3 spaces + Event
        day_padded = f"{day:<18}"
        
        formatted_lines.append(f"{day_padded}{time:<10}{event_name}")
    
    return "\n".join(formatted_lines)

def main():
    """Main function to get and display recurring events"""
    # Get the directory where this script is located
    script_dir = os.path.dirname(os.path.abspath(__file__))
    csv_file = os.path.join(script_dir, 'recurring_events.csv')
    
    # Read and format events
    events = read_recurring_events(csv_file)
    formatted_output = format_events(events)
    
    # Print the formatted output (this will be captured by Conky)
    if formatted_output:
        print(formatted_output)

if __name__ == "__main__":
    main()