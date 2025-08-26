#!/usr/bin/env python3
"""
Conky-specific System Uptime Contribution Graph Generator
Outputs directly in Conky color format to avoid text processing issues
Now tracks individual boot sessions and calculates daily totals
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
    
    def log_uptime(self):
        """Log current uptime to database, tracking individual boot sessions"""
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
        
        conn.commit()
        conn.close()
        
        return self.get_daily_uptime_percentage(today)
    
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
    
    def generate_conky_graph(self, weeks=26, months=None):
        """Generate GitHub-style contribution graph for Conky"""
        self.log_uptime()
        
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
        
        # Generate the graph - no labels, just the grid
        graph_lines = []
        
        # Generate 7 rows (days of week) with just the squares
        today_date = datetime.now().strftime('%Y-%m-%d')
        
        for day_idx in range(7):
            day_line = ""
            
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
        """Generate summary like GitHub"""
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
    
    def generate_complete_conky_output(self, weeks=26, months=None):
        """Generate complete output ready for Conky"""
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
    parser.add_argument('action', nargs='?', default='graph', 
                       choices=['graph', 'log', 'cleanup'],
                       help='Action to perform')
    parser.add_argument('--weeks', type=int, default=26,
                       help='Number of weeks to show (default: 26)')
    parser.add_argument('--months', type=int,
                       help='Number of months to show (overrides --weeks)')
    parser.add_argument('--data-dir', help='Custom data directory')
    
    args = parser.parse_args()
    
    tracker = ConkyUptimeTracker(args.data_dir)
    
    if args.action == 'log':
        uptime = tracker.log_uptime()
        print(f"Logged uptime: {uptime}%")
    elif args.action == 'cleanup':
        deleted = tracker.cleanup_old_sessions()
        print(f"Cleaned up {deleted} old boot sessions")
    else:  # graph
        print(tracker.generate_complete_conky_output(args.weeks, args.months))

if __name__ == '__main__':
    main()