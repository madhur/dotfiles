#!/usr/bin/env python3
"""
Generate uptime contribution graph data for Eww widget
Outputs HTML/text that can be displayed in Eww
"""

import sys
import json
from datetime import datetime, timedelta
from pathlib import Path
import sqlite3


class EwwUptimeGraph:
    def __init__(self, data_dir=None):
        if data_dir is None:
            self.data_dir = Path.home() / '.local' / 'share' / 'uptime-tracker'
        else:
            self.data_dir = Path(data_dir)

        self.db_path = self.data_dir / 'uptime.db'

    def get_daily_uptime_percentage(self, date):
        """Calculate total uptime percentage for a given date"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()

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

            session_start = max(boot_time, date_obj)
            session_end = min(boot_time + timedelta(seconds=last_seen_uptime),
                            date_obj + timedelta(days=1))

            if session_end > session_start:
                session_contribution = (session_end - session_start).total_seconds()
                total_uptime_seconds += session_contribution

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

    def generate_graph_data(self, weeks=16):
        """Generate contribution graph data as JSON"""
        end_date = datetime.now()
        days_since_sunday = (end_date.weekday() + 1) % 7
        current_week_sunday = end_date - timedelta(days=days_since_sunday)

        weeks_to_show = min(53, weeks)
        start_date = current_week_sunday - timedelta(weeks=weeks_to_show-1)

        today_date = datetime.now().strftime('%Y-%m-%d')

        # Generate month labels
        months = []
        current_month = None

        for week in range(weeks_to_show):
            week_start_date = start_date + timedelta(weeks=week)
            week_month = week_start_date.month

            if week_month != current_month:
                months.append({
                    'week': week,
                    'label': week_start_date.strftime('%b')
                })
                current_month = week_month

        # Generate grid data
        grid = []
        day_labels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']

        for day_idx in range(7):
            row = {
                'day': day_labels[day_idx],
                'cells': []
            }

            for week in range(weeks_to_show):
                current_date = start_date + timedelta(weeks=week, days=day_idx)

                if current_date <= end_date:
                    date_str = current_date.strftime('%Y-%m-%d')
                    uptime_percentage = self.get_daily_uptime_percentage(date_str)
                    level = self.get_uptime_level(uptime_percentage)

                    row['cells'].append({
                        'date': date_str,
                        'level': level,
                        'percentage': uptime_percentage,
                        'hours': round((uptime_percentage / 100) * 24, 1),
                        'is_today': date_str == today_date
                    })
                else:
                    row['cells'].append({
                        'date': '',
                        'level': 0,
                        'percentage': 0,
                        'hours': 0,
                        'is_today': False
                    })

            grid.append(row)

        # Generate summary
        good_days = 0
        total_days = 0
        current_date = start_date

        while current_date <= end_date:
            date_str = current_date.strftime('%Y-%m-%d')
            percentage = self.get_daily_uptime_percentage(date_str)
            if percentage > 0:
                total_days += 1
                if percentage > 75:
                    good_days += 1
            current_date += timedelta(days=1)

        today_percentage = self.get_daily_uptime_percentage(today_date)

        return {
            'months': months,
            'grid': grid,
            'summary': {
                'good_days': good_days,
                'total_days': total_days,
                'today_percentage': today_percentage,
                'today_hours': round((today_percentage / 100) * 24, 1)
            }
        }

    def generate_html_output(self, weeks=16):
        """Generate HTML output for Eww literal widget"""
        data = self.generate_graph_data(weeks)

        html_parts = []

        # Month labels
        html_parts.append('<box class="graph-container">')
        html_parts.append('<box class="month-labels" orientation="h">')

        # Add spacing for day labels
        html_parts.append('<label class="day-label-spacer" text="    "/>')

        for month in data['months']:
            html_parts.append(f'<label class="month-label" text="{month["label"]}"/>')

        html_parts.append('</box>')

        # Grid
        for row in data['grid']:
            html_parts.append('<box class="graph-row" orientation="h">')
            html_parts.append(f'<label class="day-label" text="{row["day"]}"/>')

            for cell in row['cells']:
                level_class = f'level-{cell["level"]}'
                today_class = ' today' if cell['is_today'] else ''
                tooltip = f"{cell['date']}: {cell['hours']}h ({cell['percentage']}%)" if cell['date'] else ''

                html_parts.append(
                    f'<box class="cell {level_class}{today_class}" '
                    f'tooltip="{tooltip}"/>'
                )

            html_parts.append('</box>')

        # Summary
        summary = data['summary']
        summary_text = f"{summary['good_days']} high uptime days. Today: {summary['today_hours']}h ({summary['today_percentage']}%)"
        html_parts.append(f'<label class="summary" text="{summary_text}"/>')

        html_parts.append('</box>')

        return '\n'.join(html_parts)

    def generate_simple_text_output(self, weeks=16):
        """Generate simple text-based output with Unicode blocks for Eww label"""
        data = self.generate_graph_data(weeks)

        lines = []

        # Title
        lines.append("UPTIME CONTRIBUTION GRAPH")
        lines.append("")

        # Month labels
        month_line = "    "
        for month in data['months']:
            month_line += month['label'][0] + " "
        lines.append(month_line.rstrip())

        # Grid with Unicode blocks
        symbols = {
            0: '▢',  # Empty square (no activity)
            1: '▣',  # Low activity
            2: '◧',  # Medium-low activity
            3: '◨',  # Medium-high activity
            4: '■'   # High activity
        }

        for row in data['grid']:
            row_line = f"{row['day']} "

            for cell in row['cells']:
                symbol = symbols[cell['level']]
                if cell['is_today']:
                    symbol = '◈'  # Diamond for today
                row_line += symbol + " "

            lines.append(row_line.rstrip())

        # Summary
        lines.append("")
        summary = data['summary']
        lines.append(f"{summary['good_days']} high uptime days. Today: {summary['today_hours']}h")

        return '\n'.join(lines)


def main():
    import argparse

    parser = argparse.ArgumentParser(description='Generate uptime graph data for Eww')
    parser.add_argument('--weeks', type=int, default=16, help='Number of weeks to show')
    parser.add_argument('--format', choices=['json', 'html', 'text'], default='text',
                       help='Output format')
    parser.add_argument('--data-dir', help='Custom data directory')

    args = parser.parse_args()

    graph = EwwUptimeGraph(args.data_dir)

    if args.format == 'json':
        data = graph.generate_graph_data(args.weeks)
        print(json.dumps(data, indent=2))
    elif args.format == 'html':
        print(graph.generate_html_output(args.weeks))
    else:  # text
        print(graph.generate_simple_text_output(args.weeks))


if __name__ == '__main__':
    main()
