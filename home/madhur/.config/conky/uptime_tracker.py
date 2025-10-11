#!/usr/bin/env python3
"""
Conky-specific System Uptime Contribution Graph Generator
Enhanced version with Conky built-in bar graph support

Outputs directly in Conky color format to avoid text processing issues
Now tracks individual boot sessions and calculates daily totals

Modified to separate data collection (systemd timer) from visualization (Conky)

Uptime Levels and Thresholds:
Level 0: ${color1}■${color} (Dark Gray)
Level 1: ${color2}■${color} (Dark Green)  
Level 2: ${color3}■${color} (Medium Green)
Level 3: ${color4}■${color} (Bright Green)
Level 4: ${color5}■${color} (Brightest Green)
"""

import os
import sys
import json
import argparse
from datetime import datetime, timedelta
from pathlib import Path
import sqlite3

class ConkyUptimeTracker:
    def __init__(self, data_dir=None):
        if data_dir is None:
            self.data_dir = Path.home() / '.local' / 'share' / 'uptime-tracker'
        else:
            self.data_dir = Path(data_dir)
        
        self.data_dir.mkdir(parents=True, exist_ok=True)
        self.db_path = self.data_dir / 'uptime.db'
        self.init_database()
        
        # Conky color mappings - direct output
        self.conky_colors = {
            0: '${color1}■${color}',     # Dark gray (no activity)
            1: '${color2}■${color}',     # Dark green (low activity)
            2: '${color3}■${color}',     # Medium green
            3: '${color4}■${color}',     # Bright green  
            4: '${color5}■${color}'      # Brightest green (high activity)
        }
        
        # Today's date colors (with border/highlight effect)
        self.today_colors = {
            0: '${color1}▣${color}',     # Today with no activity (outlined square)
            1: '${color2}▣${color}',     # Today with low activity
            2: '${color3}▣${color}',     # Today with medium activity
            3: '${color4}▣${color}',     # Today with bright activity
            4: '${color5}▣${color}'      # Today with highest activity
        }
    
    def init_database(self):
        """Initialize SQLite database for storing boot session data"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # New table structure for individual boot sessions
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS boot_sessions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                boot_time TEXT NOT NULL,
                boot_timestamp INTEGER NOT NULL,
                date TEXT NOT NULL,
                last_seen_uptime INTEGER DEFAULT 0,
                last_updated TEXT,
                session_ended INTEGER DEFAULT 0,
                UNIQUE(boot_timestamp)
            )
        ''')
        
        # Create index for faster date-based queries
        cursor.execute('''
            CREATE INDEX IF NOT EXISTS idx_date ON boot_sessions(date)
        ''')
        
        conn.commit()
        conn.close()
    
    def get_current_uptime(self):
        """Get current system uptime in seconds"""
        try:
            with open('/proc/uptime', 'r') as f:
                uptime_seconds = float(f.read().split()[0])
            return int(uptime_seconds)
        except Exception as e:
            print(f"Error reading uptime: {e}", file=sys.stderr)
            return 0
    
    def get_boot_time(self):
        """Get system boot time"""
        try:
            with open('/proc/stat', 'r') as f:
                for line in f:
                    if line.startswith('btime'):
                        boot_timestamp = int(line.split()[1])
                        boot_datetime = datetime.fromtimestamp(boot_timestamp)
                        return boot_datetime.isoformat(), boot_timestamp
        except Exception:
            pass
        now = datetime.now()
        return now.isoformat(), int(now.timestamp())
    
    def update_uptime_data(self):
        """Update uptime data in database - separated from visualization"""
        boot_time_iso, boot_timestamp = self.get_boot_time()
        current_uptime = self.get_current_uptime()
        today = datetime.now().strftime('%Y-%m-%d')
        now_iso = datetime.now().isoformat()
        
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Try to find existing session for this boot
        cursor.execute('''
            SELECT id, last_seen_uptime FROM boot_sessions 
            WHERE boot_timestamp = ?
        ''', (boot_timestamp,))
        
        existing = cursor.fetchone()
        
        if existing:
            # Update existing session
            session_id, last_uptime = existing
            cursor.execute('''
                UPDATE boot_sessions 
                SET last_seen_uptime = ?, last_updated = ?
                WHERE id = ?
            ''', (current_uptime, now_iso, session_id))
            operation = "updated"
        else:
            # Mark all previous sessions as ended (they would have lower uptimes if still running)
            cursor.execute('''
                UPDATE boot_sessions 
                SET session_ended = 1 
                WHERE session_ended = 0
            ''')
            
            # Create new session
            cursor.execute('''
                INSERT INTO boot_sessions 
                (boot_time, boot_timestamp, date, last_seen_uptime, last_updated, session_ended)
                VALUES (?, ?, ?, ?, ?, 0)
            ''', (boot_time_iso, boot_timestamp, today, current_uptime, now_iso))
            operation = "created"
        
        conn.commit()
        conn.close()
        
        today_percentage = self.get_daily_uptime_percentage(today)
        return operation, today_percentage
    
    def log_uptime(self):
        """Legacy method - now just calls update_uptime_data for compatibility"""
        operation, percentage = self.update_uptime_data()
        return percentage
    
    def get_daily_uptime_percentage(self, date):
        """Calculate total uptime percentage for a given date"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Get all sessions that contributed to this date
        cursor.execute('''
            SELECT boot_time, boot_timestamp, last_seen_uptime
            FROM boot_sessions 
            WHERE date = ?
            ORDER BY boot_timestamp
        ''', (date,))
        
        sessions = cursor.fetchall()
        conn.close()
        
        if not sessions:
            return 0
        
        total_uptime_seconds = 0
        date_obj = datetime.strptime(date, '%Y-%m-%d')
        
        for boot_time_iso, boot_timestamp, last_seen_uptime in sessions:
            boot_time = datetime.fromisoformat(boot_time_iso.replace('Z', '+00:00'))
            
            # Calculate how much of this session contributed to the target date
            session_start = max(boot_time, date_obj)
            session_end = min(boot_time + timedelta(seconds=last_seen_uptime), 
                            date_obj + timedelta(days=1))
            
            if session_end > session_start:
                session_contribution = (session_end - session_start).total_seconds()
                total_uptime_seconds += session_contribution
        
        # Calculate percentage of day (86400 seconds = 24 hours)
        percentage = min(100, int((total_uptime_seconds / 86400) * 100))
        return percentage
    
    def get_uptime_level(self, percentage):
        """Convert uptime percentage to level (0-4) like GitHub"""
        if percentage == 0:
            return 0
        elif percentage <= 20:
            return 1
        elif percentage <= 40:
            return 2
        elif percentage <= 60:
            return 3
        else:
            return 4
    
    def get_uptime_data(self, days_back=365):
        """Get uptime data for specified number of days"""
        end_date = datetime.now()
        start_date = end_date - timedelta(days=days_back)
        
        # Generate all dates in range
        data_dict = {}
        current_date = start_date
        
        while current_date <= end_date:
            date_str = current_date.strftime('%Y-%m-%d')
            percentage = self.get_daily_uptime_percentage(date_str)
            data_dict[date_str] = percentage
            current_date += timedelta(days=1)
        
        return data_dict
    
    def get_data_date_range(self):
        """Get the actual date range of available data"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            SELECT MIN(date), MAX(date)
            FROM boot_sessions 
            WHERE last_seen_uptime > 0
        ''')
        
        result = cursor.fetchone()
        conn.close()
        
        if result and result[0] and result[1]:
            min_date = datetime.strptime(result[0], '%Y-%m-%d')
            max_date = datetime.strptime(result[1], '%Y-%m-%d')
            return min_date, max_date
        else:
            # No data available, return today's date
            today = datetime.now()
            return today, today
    
    def get_uptime_percentage_for_conky(self, days_back=0):
        """Get uptime percentage for a specific day (0=today, 1=yesterday, etc.)"""
        target_date = datetime.now() - timedelta(days=days_back)
        date_str = target_date.strftime('%Y-%m-%d')
        return self.get_daily_uptime_percentage(date_str)
    
    def get_hourly_uptime_data(self, date_str=None):
        """Get hourly uptime data for a specific date"""
        if date_str is None:
            date_str = datetime.now().strftime('%Y-%m-%d')
        
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        date_obj = datetime.strptime(date_str, '%Y-%m-%d')
        date_start_timestamp = int(date_obj.timestamp())
        date_end_timestamp = int((date_obj + timedelta(days=1)).timestamp())
        
        # Get ALL sessions that could have contributed to this date using timestamps
        cursor.execute('''
            SELECT boot_time, boot_timestamp, last_seen_uptime
            FROM boot_sessions 
            WHERE boot_timestamp + last_seen_uptime >= ?
            AND boot_timestamp < ?
            ORDER BY boot_timestamp
        ''', (date_start_timestamp, date_end_timestamp))
        
        sessions = cursor.fetchall()
        conn.close()
        
        # Initialize 24-hour array (0-23)
        hourly_data = [0] * 24
        
        if not sessions:
            return hourly_data
        
        for boot_time_iso, boot_timestamp, last_seen_uptime in sessions:
            boot_time = datetime.fromtimestamp(boot_timestamp)
            session_start = max(boot_time, date_obj)
            session_end = min(boot_time + timedelta(seconds=last_seen_uptime), 
                            date_obj + timedelta(days=1))
            
            if session_end > session_start:
                # Calculate uptime for each hour this session covers
                current_time = session_start
                while current_time < session_end:
                    # Get the hour of the day (0-23)
                    hour = current_time.hour
                    
                    # Calculate how much of this hour had uptime
                    hour_start = current_time.replace(minute=0, second=0, microsecond=0)
                    hour_end = hour_start + timedelta(hours=1)
                    
                    # Find overlap between session and this hour
                    overlap_start = max(current_time, hour_start)
                    overlap_end = min(session_end, hour_end)
                    
                    if overlap_end > overlap_start:
                        overlap_seconds = (overlap_end - overlap_start).total_seconds()
                        # Convert to percentage of hour (3600 seconds = 100%)
                        hour_percentage = min(100, (overlap_seconds / 3600) * 100)
                        hourly_data[hour] = max(hourly_data[hour], hour_percentage)
                    
                    # Move to next hour
                    current_time = hour_end
        
        return hourly_data

    def get_hourly_uptime_percentage(self, date_str=None, hour=None):
        """Get uptime percentage for a specific hour of a specific day"""
        if hour is None:
            hour = datetime.now().hour
        if date_str is None:
            date_str = datetime.now().strftime('%Y-%m-%d')
            
        hourly_data = self.get_hourly_uptime_data(date_str)
        return int(hourly_data[hour]) if 0 <= hour <= 23 else 0
    
    def get_weekly_average_percentage(self):
        """Get average uptime percentage for the last 7 days"""
        total = 0
        count = 0
        
        for days_back in range(7):
            percentage = self.get_uptime_percentage_for_conky(days_back)
            if percentage > 0:  # Only count days with data
                total += percentage
                count += 1
        
        return total / count if count > 0 else 0
    
    def get_monthly_average_percentage(self):
        """Get average uptime percentage for the last 30 days"""
        total = 0
        count = 0
        
        for days_back in range(30):
            percentage = self.get_uptime_percentage_for_conky(days_back)
            if percentage > 0:  # Only count days with data
                total += percentage
                count += 1
        
        return total / count if count > 0 else 0
    
    def generate_conky_bar_data(self, bar_type='today'):
        """Generate data for Conky's built-in execbar"""
        if bar_type == 'today':
            return int(self.get_uptime_percentage_for_conky(0))
        elif bar_type == 'yesterday':
            return int(self.get_uptime_percentage_for_conky(1))
        elif bar_type == 'week':
            return int(self.get_weekly_average_percentage())
        elif bar_type == 'month':
            return int(self.get_monthly_average_percentage())
        elif bar_type.startswith('day-'):
            # Format: day-N where N is days back
            days_back = int(bar_type.split('-')[1])
            return int(self.get_uptime_percentage_for_conky(days_back))
        elif bar_type.startswith('hour-'):
            # Format: hour-H where H is hour (0-23), defaults to today
            hour = int(bar_type.split('-')[1])
            return self.get_hourly_uptime_percentage(None, hour)
        elif bar_type.startswith('hour-') and len(bar_type.split('-')) > 2:
            # Format: hour-H-YYYY-MM-DD for specific date and hour
            parts = bar_type.split('-')
            hour = int(parts[1])
            date_str = f"{parts[2]}-{parts[3]}-{parts[4]}"
            return self.get_hourly_uptime_percentage(date_str, hour)
        else:
            return 0
    
    def generate_conky_bar_with_label(self, bar_type='today'):
        """Generate labeled percentage for Conky bars"""
        percentage = self.generate_conky_bar_data(bar_type)
        
        if bar_type == 'today':
            hours = (percentage / 100) * 24
            return f"{percentage}% ({hours:.1f}h today)"
        elif bar_type == 'yesterday':
            hours = (percentage / 100) * 24
            return f"{percentage}% ({hours:.1f}h yesterday)"
        elif bar_type == 'week':
            hours = (percentage / 100) * 24
            return f"{percentage}% (7-day avg: {hours:.1f}h)"
        elif bar_type == 'month':
            hours = (percentage / 100) * 24
            return f"{percentage}% (30-day avg: {hours:.1f}h)"
        elif bar_type.startswith('day-'):
            days_back = int(bar_type.split('-')[1])
            date_str = (datetime.now() - timedelta(days=days_back)).strftime('%m/%d')
            hours = (percentage / 100) * 24
            return f"{percentage}% ({hours:.1f}h on {date_str})"
        elif bar_type.startswith('hour-'):
            parts = bar_type.split('-')
            hour = int(parts[1])
            
            if len(parts) > 2:
                # Specific date provided
                date_str = f"{parts[2]}-{parts[3]}-{parts[4]}"
                display_date = datetime.strptime(date_str, '%Y-%m-%d').strftime('%m/%d')
                return f"{percentage}% (hour {hour:02d} on {display_date})"
            else:
                # Today
                return f"{percentage}% (hour {hour:02d} today)"
        else:
            return f"{percentage}%"
    
    def generate_hourly_bar_overview(self, date_str=None):
        """Generate overview of all 24 hours for a day"""
        if date_str is None:
            date_str = datetime.now().strftime('%Y-%m-%d')
            display_date = "today"
        else:
            display_date = datetime.strptime(date_str, '%Y-%m-%d').strftime('%m/%d')
        
        hourly_data = self.get_hourly_uptime_data(date_str)
        
        result = []
        result.append(f"24-Hour Uptime Overview ({display_date})")
        result.append("=" * 35)
        
        # Group hours into 4-hour blocks for better display
        for block_start in range(0, 24, 4):
            block_end = min(block_start + 4, 24)
            block_line = ""
            
            for hour in range(block_start, block_end):
                percentage = int(hourly_data[hour])
                if percentage == 0:
                    bar_char = "░"  # No uptime
                elif percentage < 25:
                    bar_char = "▒"  # Low uptime
                elif percentage < 75:
                    bar_char = "▓"  # Medium uptime  
                else:
                    bar_char = "█"  # High uptime
                
                block_line += f"{hour:02d}{bar_char} "
            
            result.append(block_line)
        
        # Add legend
        result.append("")
        result.append("Legend: ░=0% ▒=1-24% ▓=25-74% █=75-100%")
        
        # Add summary stats
        active_hours = sum(1 for x in hourly_data if x > 0)
        total_uptime_minutes = sum(hourly_data) * 0.6  # Convert percentage-hours to minutes
        avg_percentage = sum(hourly_data) / 24
        
        result.append(f"Active hours: {active_hours}/24")
        result.append(f"Total uptime: {total_uptime_minutes/60:.1f}h ({avg_percentage:.1f}%)")
        
        return "\n".join(result)
    
    def generate_hourly_conky_bars(self, date_str=None):
        """Generate hourly uptime data for Conky execbar - one value per hour"""
        if date_str is None:
            date_str = datetime.now().strftime('%Y-%m-%d')
        
        hourly_data = self.get_hourly_uptime_data(date_str)
        
        # Return 24 values (one for each hour) separated by newlines
        # Each value is the uptime percentage for that hour (0-100)
        return "\n".join(str(int(percentage)) for percentage in hourly_data)
    
    def generate_hourly_conky_bars_with_labels(self, date_str=None):
        """Generate hourly uptime data with time labels for Conky"""
        if date_str is None:
            date_str = datetime.now().strftime('%Y-%m-%d')
            display_date = "today"
        else:
            display_date = datetime.strptime(date_str, '%Y-%m-%d').strftime('%m/%d')
        
        hourly_data = self.get_hourly_uptime_data(date_str)
        
        result = []
        result.append(f"Hourly Uptime - {display_date}")
        result.append("=" * 25)
        
        # Group into 6-hour blocks for better display
        for block_start in range(0, 24, 6):
            block_end = min(block_start + 6, 24)
            
            # Time labels
            time_line = ""
            for hour in range(block_start, block_end):
                time_line += f"{hour:02d}:00".ljust(8)
            result.append(time_line)
            
            # Percentage values
            percent_line = ""
            for hour in range(block_start, block_end):
                percentage = int(hourly_data[hour])
                percent_line += f"{percentage:>3}%".ljust(8)
            result.append(percent_line)
            
            # Bar visualization
            bar_line = ""
            for hour in range(block_start, block_end):
                percentage = int(hourly_data[hour])
                bar_length = int(percentage / 4)  # Scale to 25 chars max
                bar = "█" * bar_length + "░" * (25 - bar_length)
                bar_line += bar[:6].ljust(8)  # Show first 6 chars
            result.append(bar_line)
            
            result.append("")  # Empty line between blocks
        
        return "\n".join(result)
    
    def generate_daily_conky_bar(self, date_str=None):
        """Generate single daily uptime percentage for Conky execbar"""
        if date_str is None:
            date_str = datetime.now().strftime('%Y-%m-%d')
        
        # Get the daily uptime percentage
        daily_percentage = self.get_daily_uptime_percentage(date_str)
        return int(daily_percentage)
    
    def generate_daily_conky_bar_with_label(self, date_str=None):
        """Generate daily uptime percentage with label for Conky"""
        if date_str is None:
            date_str = datetime.now().strftime('%Y-%m-%d')
            display_date = "today"
        else:
            display_date = datetime.strptime(date_str, '%Y-%m-%d').strftime('%m/%d')
        
        daily_percentage = self.get_daily_uptime_percentage(date_str)
        hours = (daily_percentage / 100) * 24
        
        return f"{int(daily_percentage)}% ({hours:.1f}h on {display_date})"
    
    def generate_last_24h_hourly_bars(self):
        """Generate hourly uptime data for the last 24 hours (rolling window)"""
        now = datetime.now()
        result = []
        
        # Get data for the last 24 hours, hour by hour
        for hours_back in range(23, -1, -1):  # 23 hours ago to now (oldest to newest)
            target_time = now - timedelta(hours=hours_back)
            target_date = target_time.strftime('%Y-%m-%d')
            target_hour = target_time.hour
            
            # DEBUG: Print what we're checking
            #print(f"Checking: {target_time.strftime('%m/%d %H:%M')} (hour {target_hour} of {target_date})", file=sys.stderr)
            
            # Get hourly data for that entire day
            hourly_data = self.get_hourly_uptime_data(target_date)
            percentage = int(hourly_data[target_hour])
            result.append(percentage)
        
        return "\n".join(str(p) for p in result)
    
    def generate_last_24h_hourly_bars_with_labels(self):
        """Generate hourly uptime data with time labels for the last 24 hours"""
        now = datetime.now()
        result = []
        
        result.append("Last 24 Hours Uptime Timeline")
        result.append("=" * 35)
        
        # Get data for the last 24 hours
        for hours_back in range(24):
            target_time = now - timedelta(hours=hours_back)
            target_date = target_time.strftime('%Y-%m-%d')
            target_hour = target_time.hour
            time_label = target_time.strftime('%H:%M')
            
            # Get hourly data for that date
            hourly_data = self.get_hourly_uptime_data(target_date)
            percentage = int(hourly_data[target_hour])
            
            # Create bar visualization
            bar_length = int(percentage / 4)  # Scale to 25 chars max
            bar = "█" * bar_length + "░" * (25 - bar_length)
            
            result.append(f"{time_label}: {percentage:>3}% {bar[:10]}")
        
        return "\n".join(result)
    
    def generate_circular_clock_data(self):
        """Generate data for circular clock visualization - 24 hours in clock format"""
        now = datetime.now()
        current_hour = now.hour
        
        # Get hourly data for today and yesterday (in case of midnight crossover)
        today_data = self.get_hourly_uptime_data()
        yesterday = now - timedelta(days=1)
        yesterday_data = self.get_hourly_uptime_data(yesterday.strftime('%Y-%m-%d'))
        
        # Create 24-hour array starting from current hour going backwards
        clock_data = []
        for hours_back in range(24):
            target_time = now - timedelta(hours=hours_back)
            target_date = target_time.strftime('%Y-%m-%d')
            target_hour = target_time.hour
            
            if target_date == now.strftime('%Y-%m-%d'):
                percentage = int(today_data[target_hour])
            else:
                percentage = int(yesterday_data[target_hour])
            
            clock_data.append(percentage)
        
        return clock_data, current_hour
    
    def generate_circular_clock_conky(self):
        """Generate circular clock visualization for Conky"""
        clock_data, current_hour = self.generate_circular_clock_data()
        
        # Create a 7x7 grid to represent the clock face
        # Position 24 hours around the perimeter
        clock_positions = [
            # Outer ring positions (24 hours)
            (0, 1), (0, 2), (0, 3), (0, 4), (0, 5),  # Top row
            (1, 6), (2, 6), (3, 6), (4, 6), (5, 6),  # Right column
            (6, 5), (6, 4), (6, 3), (6, 2), (6, 1),  # Bottom row
            (5, 0), (4, 0), (3, 0), (2, 0), (1, 0),  # Left column
            (0, 0), (0, 6), (6, 6), (6, 0)            # Corners
        ]
        
        # Create 7x7 grid
        grid = [[' ' for _ in range(7)] for _ in range(7)]
        
        # Place hours around the clock
        for i, (row, col) in enumerate(clock_positions):
            if i < 24:  # Only use first 24 positions
                percentage = clock_data[i]
                hour = (current_hour - i) % 24
                
                # Determine symbol and color based on uptime percentage
                if percentage == 0:
                    symbol = '○'  # Empty circle
                    color = '${color1}'  # Dark gray
                elif percentage < 25:
                    symbol = '◐'  # Half circle
                    color = '${color2}'  # Dark green
                elif percentage < 50:
                    symbol = '◑'  # Three-quarter circle
                    color = '${color3}'  # Medium green
                elif percentage < 75:
                    symbol = '◒'  # Almost full circle
                    color = '${color4}'  # Bright green
                else:
                    symbol = '●'  # Full circle
                    color = '${color5}'  # Brightest green
                
                # Highlight current hour
                if i == 0:  # Current hour
                    symbol = '◆'  # Diamond for current hour
                    color = '${color0}'  # White for current hour
                
                grid[row][col] = color + symbol + '${color}'
        
        # Convert grid to Conky text
        result = []
        result.append("${color0}24H UPTIME CLOCK${color}")
        result.append("")
        
        for row in grid:
            line = "".join(f"{cell:^3}" for cell in row)
            result.append(line)
        
        # Add hour labels
        result.append("")
        result.append("${color0}Hours: 00 06 12 18${color}")
        
        return "\n".join(result)
    
    def generate_horizontal_execgraph_data(self):
        """Generate data for horizontal execgraph - 24 data points for last 24 hours"""
        now = datetime.now()
        
        # Get hourly data for the last 24 hours
        data_points = []
        for hours_back in range(23, -1, -1):  # 23 hours ago to now
            target_time = now - timedelta(hours=hours_back)
            target_date = target_time.strftime('%Y-%m-%d')
            target_hour = target_time.hour
            
            hourly_data = self.get_hourly_uptime_data(target_date)
            percentage = int(hourly_data[target_hour])
            data_points.append(percentage)
        
        return data_points
    
    def generate_horizontal_execgraph_conky(self):
        """Generate horizontal execgraph visualization for Conky"""
        data_points = self.generate_horizontal_execgraph_data()
        
        # Create time labels for x-axis (every 4 hours)
        now = datetime.now()
        time_labels = []
        for i in range(0, 24, 4):
            time = now - timedelta(hours=23-i)
            time_labels.append(time.strftime('%H'))
        
        result = []
        result.append("${color0}24H UPTIME GRAPH${color}")
        result.append("")
        
        # Time labels
        time_line = "     " + "".join(f"{label:^6}" for label in time_labels)
        result.append(time_line)
        
        # Graph data (will be used with execgraph)
        graph_data = " ".join(str(p) for p in data_points)
        result.append("${execgraph " + graph_data + " 10,100}")
        
        # Legend
        result.append("")
        result.append("${color1}0%${color} ${color2}25%${color} ${color3}50%${color} ${color4}75%${color} ${color5}100%${color}")
        
        return "\n".join(result)

    def generate_conky_graph(self, weeks=26, months=None):
        """Generate GitHub-style contribution graph for Conky - DISPLAY ONLY"""
        # If months is specified, calculate weeks from months
        if months is not None:
            # Approximate: 4.33 weeks per month
            weeks = int(months * 4.33)
        
        days_back = weeks * 7
        uptime_data = self.get_uptime_data(days_back)
        
        # Calculate the start date (go back to last Sunday)
        end_date = datetime.now()
        
        # Find the Sunday of the current week
        days_since_sunday = (end_date.weekday() + 1) % 7
        current_week_sunday = end_date - timedelta(days=days_since_sunday)
        
        # Go back the specified number of weeks
        weeks_to_show = min(53, weeks)
        start_date = current_week_sunday - timedelta(weeks=weeks_to_show-1)
        
        # Generate month labels header - show letter for every month transition
        month_line = "    "  # 4 spaces for day labels alignment
        current_month = None
        
        for week in range(weeks_to_show):
            week_start_date = start_date + timedelta(weeks=week)
            week_month = week_start_date.month
            week_year = week_start_date.year
            
            if week_month != current_month:
                # New month detected - show the month letter
                month_letter = week_start_date.strftime('%b')[0]  # First letter of month
                month_line += month_letter + " "
                current_month = week_month
            else:
                # Same month - show space to maintain alignment
                month_line += "  "  # Two spaces to align with squares
        
        graph_lines = [month_line.rstrip()]
        
        # Day of week labels
        day_labels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
        today_date = datetime.now().strftime('%Y-%m-%d')
        
        # Generate 7 rows (days of week) with day labels
        for day_idx in range(7):
            day_line = f"{day_labels[day_idx]} "  # Day label + space
            
            for week in range(weeks_to_show):
                current_date = start_date + timedelta(weeks=week, days=day_idx)
                
                if current_date <= end_date:
                    date_str = current_date.strftime('%Y-%m-%d')
                    uptime_percentage = uptime_data.get(date_str, 0)
                    level = self.get_uptime_level(uptime_percentage)
                    
                    # Use special symbol for today's date
                    if date_str == today_date:
                        day_line += self.today_colors[level] + " "
                    else:
                        day_line += self.conky_colors[level] + " "
                else:
                    day_line += self.conky_colors[0] + " "  # Future dates as empty
            
            graph_lines.append(day_line.rstrip())
        
        return "\n".join(graph_lines)
    
    def generate_summary_line(self, period_months=None):
        """Generate summary like GitHub - READ ONLY"""
        # Calculate the period to check
        if period_months is not None:
            period_days = int(period_months * 30.44)  # Average days per month
            period_ago_date = datetime.now() - timedelta(days=period_days)
            period_text = f"last {period_months} month{'s' if period_months != 1 else ''}"
        else:
            period_ago_date = datetime.now() - timedelta(days=365)
            period_text = "last year"
        
        # Count days with good uptime in the period
        good_days = 0
        total_days = 0
        current_date = period_ago_date
        end_date = datetime.now()
        
        while current_date <= end_date:
            date_str = current_date.strftime('%Y-%m-%d')
            percentage = self.get_daily_uptime_percentage(date_str)
            if percentage > 0:  # Only count days we have data for
                total_days += 1
                if percentage > 75:
                    good_days += 1
            current_date += timedelta(days=1)
        
        # Get current uptime for today
        today_percentage = self.get_daily_uptime_percentage(datetime.now().strftime('%Y-%m-%d'))
        
        if total_days > 0:
            return f"{good_days} high uptime days in the {period_text}. Today: {today_percentage}%"
        else:
            return f"Starting to track uptime. Today: {today_percentage}%"
    
    def generate_raw_data_output(self, weeks=26, months=None):
        """Generate raw uptime data in hours for terminal output"""
        # If months is specified, calculate weeks from months
        if months is not None:
            weeks = int(months * 4.33)
        
        days_back = weeks * 7
        end_date = datetime.now()
        start_date = end_date - timedelta(days=days_back)
        
        # Get actual data range to optimize display
        data_start, data_end = self.get_data_date_range()
        
        # Use the later of calculated start_date or actual data start
        effective_start = max(start_date, data_start)
        
        uptime_data = self.get_uptime_data(days_back)
        
        # Calculate weeks to show based on effective date range
        days_to_show = (end_date - effective_start).days + 1
        weeks_to_show = min(53, (days_to_show + 6) // 7)  # Round up to nearest week
        
        # Align to weeks for display - find the Sunday before effective_start
        days_since_sunday = (effective_start.weekday() + 1) % 7
        display_start = effective_start - timedelta(days=days_since_sunday)
        
        # Generate header with dates
        result = []
        today_date = datetime.now().strftime('%Y-%m-%d')
        
        # Week headers showing date ranges
        header_line = "Week Range".ljust(25)
        weeks_in_header = min(weeks_to_show, 10)  # Limit to 10 weeks for readability
        
        for week in range(weeks_in_header):
            week_start = display_start + timedelta(weeks=week)
            week_end = week_start + timedelta(days=6)
            week_label = f"{week_start.strftime('%m/%d')}-{week_end.strftime('%m/%d')}"
            header_line += week_label.center(8)
        
        if weeks_to_show > 10:
            header_line += "..."
        
        result.append(header_line)
        result.append("-" * len(header_line))
        
        # Day labels and data
        day_labels = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']
        
        for day_idx in range(7):
            day_line = f"{day_labels[day_idx]:.<25}"  # Left-aligned with dots
            
            for week in range(weeks_in_header):
                current_date = display_start + timedelta(weeks=week, days=day_idx)
                
                if current_date <= end_date:
                    date_str = current_date.strftime('%Y-%m-%d')
                    uptime_percentage = uptime_data.get(date_str, 0)
                    hours = round((uptime_percentage / 100) * 24, 1)
                    
                    # Special formatting for today
                    if date_str == today_date:
                        hours_str = f"*{hours:>4.1f}*"
                    else:
                        hours_str = f"{hours:>6.1f}"
                    
                    day_line += hours_str.center(8)
                else:
                    day_line += "-".center(8)  # Future dates
            
            if weeks_to_show > 10:
                day_line += "..."
            
            result.append(day_line)
        
        # Summary statistics
        result.append("")
        result.append("Summary Statistics:")
        result.append("-" * 20)
        
        # Calculate averages and totals from actual data range
        total_hours = 0
        days_with_data = 0
        max_hours = 0
        max_date = ""
        
        current_date = data_start
        while current_date <= end_date:
            date_str = current_date.strftime('%Y-%m-%d')
            percentage = uptime_data.get(date_str, 0)
            if percentage > 0:
                hours = (percentage / 100) * 24
                total_hours += hours
                days_with_data += 1
                if hours > max_hours:
                    max_hours = hours
                    max_date = current_date.strftime('%m/%d')
            current_date += timedelta(days=1)
        
        if days_with_data > 0:
            avg_hours = total_hours / days_with_data
            result.append(f"Average daily uptime: {avg_hours:.1f} hours")
            result.append(f"Total uptime tracked: {total_hours:.1f} hours")
            result.append(f"Days with data: {days_with_data}")
            result.append(f"Highest single day: {max_hours:.1f} hours ({max_date})")
            result.append(f"Data range: {data_start.strftime('%m/%d/%y')} to {data_end.strftime('%m/%d/%y')}")
        else:
            result.append("No uptime data available")
        
        # Today's status
        today_percentage = self.get_daily_uptime_percentage(today_date)
        today_hours = (today_percentage / 100) * 24
        result.append(f"Today so far: {today_hours:.1f} hours ({today_percentage}%)")
        
        return "\n".join(result)
    
    def generate_simple_table(self, weeks=26, months=None):
        """Generate simple date/hours table for terminal"""
        # If months is specified, calculate weeks from months
        if months is not None:
            weeks = int(months * 4.33)
        
        days_back = weeks * 7
        end_date = datetime.now()
        start_date = end_date - timedelta(days=days_back)
        
        uptime_data = self.get_uptime_data(days_back)
        
        result = []
        result.append("Date       Hours  %   Level")
        result.append("-------------------------")
        
        current_date = start_date
        today_date = datetime.now().strftime('%Y-%m-%d')
        
        while current_date <= end_date:
            date_str = current_date.strftime('%Y-%m-%d')
            percentage = uptime_data.get(date_str, 0)
            hours = (percentage / 100) * 24
            level = self.get_uptime_level(percentage)
            
            # Only show days with data
            if percentage > 0 or date_str == today_date:
                date_display = current_date.strftime('%m/%d/%y')
                if date_str == today_date:
                    line = f"{date_display} *{hours:>5.1f} {percentage:>3}% {level} (today)"
                else:
                    line = f"{date_display}  {hours:>5.1f} {percentage:>3}% {level}"
                result.append(line)
            
            current_date += timedelta(days=1)
        
        return "\n".join(result)
    
    def generate_complete_conky_output(self, weeks=26, months=None, format_type='grid', bar_type='today'):
        """Generate complete output ready for Conky - DISPLAY ONLY"""
        if format_type == 'grid':
            result = []
            result.append(self.generate_conky_graph(weeks, months))
            result.append("")
            result.append(self.generate_summary_line(months))
            return "\n".join(result)
        elif format_type == 'conky-bar':
            # Just return the percentage for execbar
            return str(self.generate_conky_bar_data(bar_type))
        elif format_type == 'conky-label':
            # Return percentage with label
            return self.generate_conky_bar_with_label(bar_type)
        elif format_type == 'hourly':
            # Return 24-hour overview
            if bar_type.startswith('day-'):
                days_back = int(bar_type.split('-')[1])
                target_date = datetime.now() - timedelta(days=days_back)
                date_str = target_date.strftime('%Y-%m-%d')
                return self.generate_hourly_bar_overview(date_str)
            else:
                return self.generate_hourly_bar_overview()  # Defaults to today
        elif format_type == 'hourly-bars':
            # Return hourly data for Conky execbar (one value per hour)
            if bar_type.startswith('day-'):
                days_back = int(bar_type.split('-')[1])
                target_date = datetime.now() - timedelta(days=days_back)
                date_str = target_date.strftime('%Y-%m-%d')
                return self.generate_hourly_conky_bars(date_str)
            else:
                return self.generate_hourly_conky_bars()  # Defaults to today
        elif format_type == 'hourly-bars-labeled':
            # Return hourly data with labels for Conky
            if bar_type.startswith('day-'):
                days_back = int(bar_type.split('-')[1])
                target_date = datetime.now() - timedelta(days=days_back)
                date_str = target_date.strftime('%Y-%m-%d')
                return self.generate_hourly_conky_bars_with_labels(date_str)
            else:
                return self.generate_hourly_conky_bars_with_labels()  # Defaults to today
        elif format_type == 'daily-bar':
            # Return single daily uptime percentage for execbar
            if bar_type.startswith('day-'):
                days_back = int(bar_type.split('-')[1])
                target_date = datetime.now() - timedelta(days=days_back)
                date_str = target_date.strftime('%Y-%m-%d')
                return str(self.generate_daily_conky_bar(date_str))
            else:
                return str(self.generate_daily_conky_bar())  # Defaults to today
        elif format_type == 'daily-bar-labeled':
            # Return daily uptime percentage with label
            if bar_type.startswith('day-'):
                days_back = int(bar_type.split('-')[1])
                target_date = datetime.now() - timedelta(days=days_back)
                date_str = target_date.strftime('%Y-%m-%d')
                return self.generate_daily_conky_bar_with_label(date_str)
            else:
                return self.generate_daily_conky_bar_with_label()  # Defaults to today
        elif format_type == 'last24h-bars':
            # Return hourly data for last 24 hours (rolling window)
            return self.generate_last_24h_hourly_bars()
        elif format_type == 'last24h-bars-labeled':
            # Return hourly data with labels for last 24 hours
            return self.generate_last_24h_hourly_bars_with_labels()
        elif format_type == 'circular-clock':
            # Return circular clock visualization
            return self.generate_circular_clock_conky()
        elif format_type == 'horizontal-graph':
            # Return horizontal execgraph visualization
            return self.generate_horizontal_execgraph_conky()
        else:
            # Default to grid if unknown format
            result = []
            result.append(self.generate_conky_graph(weeks, months))
            result.append("")
            result.append(self.generate_summary_line(months))
            return "\n".join(result)
    
    def cleanup_old_sessions(self, days_to_keep=400):
        """Clean up old boot sessions to keep database size manageable"""
        cutoff_date = (datetime.now() - timedelta(days=days_to_keep)).strftime('%Y-%m-%d')
        
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            DELETE FROM boot_sessions 
            WHERE date < ?
        ''', (cutoff_date,))
        
        deleted = cursor.rowcount
        conn.commit()
        conn.close()
        
        return deleted

def main():
    parser = argparse.ArgumentParser(description='Conky System Uptime Contribution Graph')
    parser.add_argument('action', nargs='?', default='display', 
                       choices=['display', 'update', 'log', 'cleanup', 'graph', 'raw', 'table'],
                       help='Action to perform (default: display)')
    parser.add_argument('--weeks', type=int, default=26,
                       help='Number of weeks to show (default: 26)')
    parser.add_argument('--months', type=int,
                       help='Number of months to show (overrides --weeks)')
    parser.add_argument('--data-dir', help='Custom data directory')
    parser.add_argument('--format', choices=['grid', 'conky-bar', 'conky-label', 'hourly', 'hourly-bars', 'hourly-bars-labeled', 'daily-bar', 'daily-bar-labeled', 'last24h-bars', 'last24h-bars-labeled', 'circular-clock', 'horizontal-graph'], 
                       default='grid', help='Output format (default: grid)')
    parser.add_argument('--bar-type', choices=['today', 'yesterday', 'week', 'month'] + 
                       [f'day-{i}' for i in range(0, 31)] +
                       [f'hour-{i}' for i in range(0, 24)], 
                       default='today', help='Type of data for Conky bar (default: today)')
    
    args = parser.parse_args()
    
    tracker = ConkyUptimeTracker(args.data_dir)
    
    if args.action == 'update':
        # Data collection only - for systemd timer
        operation, uptime = tracker.update_uptime_data()
        print(f"Session {operation}. Today's uptime: {uptime}%")
    elif args.action == 'log':
        # Legacy compatibility - logs and shows percentage
        uptime = tracker.log_uptime()
        print(f"Logged uptime: {uptime}%")
    elif args.action == 'cleanup':
        # Database maintenance
        deleted = tracker.cleanup_old_sessions()
        print(f"Cleaned up {deleted} old boot sessions")
    elif args.action == 'raw':
        # Raw data output optimized for terminal
        print(tracker.generate_raw_data_output(args.weeks, args.months))
    elif args.action == 'table':
        # Simple table format
        print(tracker.generate_simple_table(args.weeks, args.months))
    elif args.action == 'graph':
        # Legacy compatibility - same as display but also updates data
        tracker.update_uptime_data()  # For backward compatibility
        print(tracker.generate_complete_conky_output(args.weeks, args.months, args.format, args.bar_type))
    else:  # display (default)
        # Visualization only - for Conky
        print(tracker.generate_complete_conky_output(args.weeks, args.months, args.format, args.bar_type))

if __name__ == '__main__':
    main()