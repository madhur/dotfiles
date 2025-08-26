#!/usr/bin/env python3
"""
Script to read past mistakes from CSV and display them for Conky
Shows a random selection to avoid overwhelming display
"""

import csv
import os
from typing import List

def read_mistakes(csv_file: str) -> List[str]:
    """Read mistakes from CSV file"""
    mistakes = []
    
    if not os.path.exists(csv_file):
        return mistakes
    
    try:
        with open(csv_file, 'r', encoding='utf-8') as file:
            reader = csv.DictReader(file)
            
            for row in reader:
                if 'mistake' not in row:
                    continue
                
                mistake_text = row['mistake'].strip()
                
                if mistake_text:
                    mistakes.append(mistake_text)
    
    except Exception:
        return []
    
    return mistakes

def format_mistakes(mistakes: List[str], max_display: int = 5) -> str:
    """Format mistakes for display - show a random selection"""
    if not mistakes:
        return "No mistakes recorded"
    
    selected_mistakes = mistakes[:max_display]
    
    formatted_lines = []
    
    for mistake in selected_mistakes:
        # Add a warning emoji and format as reminder
        formatted_lines.append(f"* {mistake}")
    
    return "\n".join(formatted_lines)

def main():
    """Main function to get and display mistakes"""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    csv_file = os.path.join(script_dir, 'mistakes.csv')
    
    mistakes = read_mistakes(csv_file)
    formatted_output = format_mistakes(mistakes)
    
    print(formatted_output)

if __name__ == "__main__":
    main()