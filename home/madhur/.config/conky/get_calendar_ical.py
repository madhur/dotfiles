#!/usr/bin/env python3
"""
Debug version to troubleshoot calendar parsing
Save as ~/.conky/calendar-project/debug_calendar.py
"""

import os
import re
import socket
import urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path

try:
    from dotenv import load_dotenv
    DOTENV_AVAILABLE = True
except ImportError:
    DOTENV_AVAILABLE = False

# Load .env file if available
if DOTENV_AVAILABLE:
    script_dir = Path(__file__).parent
    env_file = script_dir / '.env'
    if env_file.exists():
        load_dotenv(env_file)

# Configuration from environment variables
ICAL_URL = os.getenv('GOOGLE_CALENDAR_ICAL_URL', '')
MAX_EVENTS = int(os.getenv('MAX_EVENTS', '5'))
CACHE_DAYS = int(os.getenv('CACHE_DAYS', '7'))  # Default to 7 for debugging

def fetch_ical_data():
    """Fetch iCal data from Google Calendar"""
    try:
        if not ICAL_URL:
            return None
        
        print(f"Fetching from URL: {ICAL_URL[:50]}...")
        
        request = urllib.request.Request(
            ICAL_URL,
            headers={
                'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36'
            }
        )
        
        with urllib.request.urlopen(request, timeout=10) as response:
            data = response.read().decode('utf-8')
        
        print(f"Fetched {len(data)} characters of iCal data")
        return data
    
    except Exception as e:
        print(f"Error fetching iCal data: {e}")
        return None

def debug_ical_structure(ical_data):
    """Debug the structure of the iCal data"""
    lines = ical_data.split('\n')
    
    print(f"\nTotal lines in iCal: {len(lines)}")
    
    # Count different types of lines
    vevent_count = 0
    dtstart_count = 0
    summary_count = 0
    
    for line in lines:
        line = line.strip()
        if line == 'BEGIN:VEVENT':
            vevent_count += 1
        elif line.startswith('DTSTART'):
            dtstart_count += 1
            print(f"DTSTART found: {line}")
        elif line.startswith('SUMMARY'):
            summary_count += 1
            print(f"SUMMARY found: {line}")
    
    print(f"\nFound {vevent_count} VEVENT blocks")
    print(f"Found {dtstart_count} DTSTART lines")
    print(f"Found {summary_count} SUMMARY lines")
    
    # Show first few lines
    print(f"\nFirst 10 lines of iCal:")
    for i, line in enumerate(lines[:10]):
        print(f"{i+1}: {line}")
    
    return vevent_count > 0

def parse_datetime_debug(dt_string, is_date_only=False):
    """Parse iCal datetime string with debug output"""
    try:
        print(f"Parsing datetime: '{dt_string}', is_date_only: {is_date_only}")
        
        if is_date_only:
            # Date only (YYYYMMDD)
            result = datetime.strptime(dt_string, '%Y%m%d').date()
            print(f"Parsed as date: {result}")
            return result
        else:
            # DateTime (YYYYMMDDTHHMMSS or YYYYMMDDTHHMMSSZ)
            if dt_string.endswith('Z'):
                # UTC time
                dt = datetime.strptime(dt_string, '%Y%m%dT%H%M%SZ')
                dt = dt.replace(tzinfo=timezone.utc)
                # Convert to local time
                result = dt.astimezone()
                print(f"Parsed as UTC datetime, converted to local: {result}")
                return result
            else:
                # Local time (assuming) - make it timezone-aware
                dt = datetime.strptime(dt_string, '%Y%m%dT%H%M%S')
                # Make it timezone-aware using local timezone
                result = dt.replace(tzinfo=datetime.now().astimezone().tzinfo)
                print(f"Parsed as local datetime: {result}")
                return result
    except ValueError as e:
        print(f"Error parsing datetime '{dt_string}': {e}")
        return None

def parse_ical_events_debug(ical_data):
    """Parse iCal data and extract events with debug output"""
    events = []
    current_event = {}
    event_count = 0
    
    lines = ical_data.split('\n')
    
    for line_num, line in enumerate(lines):
        line = line.strip()
        
        if line == 'BEGIN:VEVENT':
            current_event = {}
            event_count += 1
            print(f"\n=== Starting Event #{event_count} at line {line_num+1} ===")
        elif line == 'END:VEVENT':
            if current_event:
                print(f"Completed event: {current_event.get('summary', 'No Title')}")
                events.append(current_event)
            current_event = {}
        elif ':' in line and current_event is not None:
            # Split only on first colon to handle URLs in values
            key, value = line.split(':', 1)
            
            # Handle different datetime formats
            if key.startswith('DTSTART'):
                print(f"Found DTSTART: {line}")
                if ';VALUE=DATE' in key:
                    current_event['start_date'] = value
                    current_event['is_all_day'] = True
                    print(f"  -> All-day event: {value}")
                else:
                    current_event['start_datetime'] = value
                    current_event['is_all_day'] = False
                    print(f"  -> Timed event: {value}")
            elif key == 'SUMMARY':
                current_event['summary'] = value
                print(f"  -> Summary: {value}")
    
    print(f"\n=== PARSING COMPLETE ===")
    print(f"Total events parsed: {len(events)}")
    
    return events

def filter_events_debug(events):
    """Filter events with debug output"""
    now = datetime.now()
    local_tz = now.astimezone().tzinfo
    start_of_period = now.replace(hour=0, minute=0, second=0, microsecond=0, tzinfo=local_tz)
    end_of_period = start_of_period + timedelta(days=CACHE_DAYS)
    
    print(f"\n=== FILTERING EVENTS ===")
    print(f"Current time: {now}")
    print(f"Filter period: {start_of_period.date()} to {end_of_period.date()}")
    print(f"Looking for events in next {CACHE_DAYS} days")
    
    filtered_events = []
    
    for i, event in enumerate(events):
        print(f"\n--- Event {i+1}: {event.get('summary', 'No Title')} ---")
        
        if event.get('is_all_day'):
            # All-day event
            date_str = event.get('start_date', '')
            event_date = parse_datetime_debug(date_str, is_date_only=True)
            
            if event_date:
                print(f"All-day event date: {event_date}")
                print(f"In range? {start_of_period.date()} <= {event_date} < {end_of_period.date()}")
                
                if start_of_period.date() <= event_date < end_of_period.date():
                    print("✅ Event added to filtered list")
                    event['parsed_start'] = event_date
                    filtered_events.append(event)
                else:
                    print("❌ Event outside date range")
        else:
            # Timed event
            datetime_str = event.get('start_datetime', '')
            event_datetime = parse_datetime_debug(datetime_str)
            
            if event_datetime:
                # Ensure timezone-aware for comparison
                if event_datetime.tzinfo is None:
                    event_datetime = event_datetime.replace(tzinfo=local_tz)
                
                print(f"Timed event datetime: {event_datetime}")
                print(f"In range? {start_of_period} <= {event_datetime} < {end_of_period}")
                
                if start_of_period <= event_datetime < end_of_period:
                    print("✅ Event added to filtered list")
                    event['parsed_start'] = event_datetime
                    filtered_events.append(event)
                else:
                    print("❌ Event outside time range")
    
    print(f"\n=== FILTERING COMPLETE ===")
    print(f"Events after filtering: {len(filtered_events)}")
    
    return filtered_events[:MAX_EVENTS]

def main():
    """Debug main function"""
    print("=== GOOGLE CALENDAR DEBUG ===")
    
    # Check configuration
    if not ICAL_URL:
        print("❌ No GOOGLE_CALENDAR_ICAL_URL in .env file")
        return
    
    print(f"✅ iCal URL configured")
    print(f"✅ Looking for {MAX_EVENTS} events in next {CACHE_DAYS} days")
    
    # Fetch iCal data
    ical_data = fetch_ical_data()
    
    if not ical_data:
        print("❌ Failed to fetch iCal data")
        return
    
    # Debug iCal structure
    has_events = debug_ical_structure(ical_data)
    
    if not has_events:
        print("❌ No VEVENT blocks found in iCal data")
        return
    
    # Parse events
    all_events = parse_ical_events_debug(ical_data)
    
    # Filter events
    filtered_events = filter_events_debug(all_events)
    
    if not filtered_events:
        print(f"\n❌ No events found in the next {CACHE_DAYS} days")
        print("\nPossible issues:")
        print("1. All events are outside the date range")
        print("2. Events have different datetime formats than expected")
        print("3. Calendar might be empty or private")
    else:
        print(f"\n✅ Found {len(filtered_events)} events:")
        for event in filtered_events:
            summary = event.get('summary', 'No Title')
            start = event.get('parsed_start')
            print(f"  - {start}: {summary}")

if __name__ == '__main__':
    main()