# get_work_rewards.py
import csv
from pathlib import Path

def get_work_rewards():
    csv_path = Path.home() / '.config/conky/work_rewards.csv'
    
    if not csv_path.exists():
        return "No goals set yet"
    
    output = []
    
    try:
        with open(csv_path, 'r') as f:
            reader = csv.DictReader(f)
            for row in reader:
                project = row['project']
                deadline = row['deadline']
                reward = row['reward']
                status = row['status']  # pending/completed
                
                # Format each goal
                if status.lower() == 'pending':
                    symbol = "⏳"
                    color = "${color0}"
                elif status.lower() == 'completed':
                    symbol = "✓"
                    color = "${color4}"
                else:
                    symbol = "○"
                    color = "${color0}"
                
                output.append(f"{color} {project}")
                output.append(f"   Date: {deadline}")
                output.append(f"   Action: {reward}")
                output.append("")
        
        return '\n'.join(output) if output else "No goals set"
        
    except Exception as e:
        return f"Error reading goals: {str(e)}"

if __name__ == '__main__':
    print(get_work_rewards())