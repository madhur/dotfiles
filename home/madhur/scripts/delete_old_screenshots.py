#!/usr/bin/env python3
import os
import sys
import argparse
from datetime import datetime, timedelta
from pathlib import Path

def delete_old_screenshots(folder_path, days_old=7):
    """
    Delete screenshot files older than specified number of days based on modification time.
    
    Args:
        folder_path (str): Path to the folder containing screenshot files
        days_old (int): Number of days old (default: 7)
    """
    
    # Convert to Path object for easier handling
    folder = Path(folder_path)
    
    if not folder.exists():
        print(f"Error: Folder '{folder_path}' does not exist.")
        return
    
    # Calculate cutoff time (files modified before this will be deleted)
    cutoff_time = datetime.now() - timedelta(days=days_old)
    
    deleted_count = 0
    error_count = 0
    
    print(f"Scanning for screenshots older than {days_old} days...")
    print(f"Cutoff time: {cutoff_time.strftime('%Y-%m-%d %H:%M:%S')}")
    print("-" * 50)
    
    # Iterate through all screenshot files in the folder
    for file_path in folder.glob('screenshot_*.png'):
        try:
            # Get file modification time
            file_mtime = datetime.fromtimestamp(file_path.stat().st_mtime)
            
            # Check if file is older than cutoff time
            if file_mtime < cutoff_time:
                try:
                    file_path.unlink()  # Delete the file
                    deleted_count += 1
                except PermissionError:
                    error_count += 1
                except Exception as e:
                    error_count += 1
                
        except Exception as e:
            error_count += 1
    
    print(f"Deleted {deleted_count} files older than {days_old} days")
    if error_count > 0:
        print(f"Errors encountered: {error_count}")
    
def main():
    parser = argparse.ArgumentParser(description='Delete screenshot files older than specified days')
    parser.add_argument('folder_path', help='Path to the folder containing screenshot files')
    parser.add_argument('-d', '--days', type=int, default=7, 
                       help='Number of days old to delete (default: 7)')
    
    args = parser.parse_args()
    
    # Validate folder path
    if not os.path.exists(args.folder_path):
        print(f"Error: Folder '{args.folder_path}' does not exist.", file=sys.stderr)
        sys.exit(1)
    
    if not os.path.isdir(args.folder_path):
        print(f"Error: '{args.folder_path}' is not a directory.", file=sys.stderr)
        sys.exit(1)
    
    # Run the cleanup
    delete_old_screenshots(args.folder_path, args.days)

if __name__ == "__main__":
    main()