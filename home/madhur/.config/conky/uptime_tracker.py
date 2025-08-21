#!/usr/bin/env python3
"""
Conky-specific System Uptime Contribution Graph Generator
Outputs directly in Conky color format to avoid text processing issues
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
        """Initialize SQLite database for storing uptime data"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS uptime_records (
                date TEXT PRIMARY KEY,
                uptime_percentage INTEGER,
                uptime_seconds INTEGER,
                boot_time TEXT,
                logged_at TEXT
            )
        ''')
        
        conn.commit()
        conn.close()
    
    def get_current_uptime(self):
        """Get current system uptime in seconds and percentage of day"""
        try:
            with open('/proc/uptime', 'r') as f:
                uptime_seconds = float(f.read().split()[0])
            
            # Calculate percentage of day (86400 seconds = 24 hours)
            seconds_in_day = 86400
            uptime_percentage = min(100, int((uptime_seconds / seconds_in_day) * 100))
            
            return uptime_seconds, uptime_percentage
        except Exception as e:
            print(f"Error reading uptime: {e}")
            return 0, 0
    
    def get_boot_time(self):
        """Get system boot time"""
        try:
            with open('/proc/stat', 'r') as f:
                for line in f:
                    if line.startswith('btime'):
                        boot_timestamp = int(line.split()[1])
                        return datetime.fromtimestamp(boot_timestamp).isoformat()
        except Exception:
            pass
        return datetime.now().isoformat()
    
    def log_uptime(self):
        """Log current uptime to database"""
        today = datetime.now().strftime('%Y-%m-%d')
        uptime_seconds, uptime_percentage = self.get_current_uptime()
        boot_time = self.get_boot_time()
        logged_at = datetime.now().isoformat()
        
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            INSERT OR REPLACE INTO uptime_records 
            (date, uptime_percentage, uptime_seconds, boot_time, logged_at)
            VALUES (?, ?, ?, ?, ?)
        ''', (today, uptime_percentage, int(uptime_seconds), boot_time, logged_at))
        
        conn.commit()
        conn.close()
        
        return uptime_percentage
    
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
        
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            SELECT date, uptime_percentage 
            FROM uptime_records 
            WHERE date >= ? AND date <= ?
            ORDER BY date
        ''', (start_date.strftime('%Y-%m-%d'), end_date.strftime('%Y-%m-%d')))
        
        results = cursor.fetchall()
        conn.close()
        
        # Convert to dictionary for easy lookup
        data_dict = {date: percentage for date, percentage in results}
        
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
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Calculate the period to check
        if period_months is not None:
            period_days = int(period_months * 30.44)  # Average days per month
            period_ago = (datetime.now() - timedelta(days=period_days)).strftime('%Y-%m-%d')
            period_text = f"last {period_months} month{'s' if period_months != 1 else ''}"
        else:
            period_ago = (datetime.now() - timedelta(days=365)).strftime('%Y-%m-%d')
            period_text = "last year"
        
        cursor.execute('''
            SELECT COUNT(*), SUM(CASE WHEN uptime_percentage > 75 THEN 1 ELSE 0 END)
            FROM uptime_records 
            WHERE date >= ?
        ''', (period_ago,))
        
        result = cursor.fetchone()
        conn.close()
        
        if result and result[0] > 0:
            good_days = result[1] or 0
            
            # Get current uptime for today
            _, today_uptime = self.get_current_uptime()
            
            return f"{good_days} high uptime days in the {period_text}. Today: {today_uptime}%"
        else:
            _, today_uptime = self.get_current_uptime()
            return f"Starting to track uptime. Today: {today_uptime}%"
    
    def generate_complete_conky_output(self, weeks=26, months=None):
        """Generate complete output ready for Conky"""
        result = []
        result.append(self.generate_conky_graph(weeks, months))
        result.append("")
        result.append(self.generate_summary_line(months))
        
        return "\n".join(result)

def main():
    parser = argparse.ArgumentParser(description='Conky System Uptime Contribution Graph')
    parser.add_argument('action', nargs='?', default='graph', 
                       choices=['graph', 'log'],
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
    else:  # graph
        print(tracker.generate_complete_conky_output(args.weeks, args.months))

if __name__ == '__main__':
    main()