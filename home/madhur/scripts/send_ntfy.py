#!/usr/bin/env python3
"""
Simple script to send ntfy notifications for systemd services.
Usage: python3 send_ntfy.py <method> <service_name> <message>
"""
import sys
import os

# Add the path to ntfy_notifier directory
sys.path.insert(0, os.path.expanduser("~/Desktop/python/email_reader"))

from ntfy_notifier import NtfyNotifier

def load_config(topic):
    """Load ntfy configuration from environment variables and provided topic."""
    return {
        'enabled': os.getenv('NTFY_ENABLED', 'true').lower() == 'true',
        'server_url': os.getenv('NTFY_SERVER', 'https://ntfy.madhur.co.in'),
        'topic': topic,  # Use the topic passed from shell script
        'username': os.getenv('NTFY_USERNAME'),
        'password': os.getenv('NTFY_PASSWORD'),
        'default_priority': 'default',
        'timeout': 10
    }

def main():
    if len(sys.argv) != 5:
        print(f"Usage: send_ntfy.py <method> <service_name> <message> <topic>")
        print(f"Received {len(sys.argv)} arguments: {sys.argv}")
        sys.exit(1)
    
    method = sys.argv[1]
    service_name = sys.argv[2]
    message = sys.argv[3]
    topic = sys.argv[4]
    
    print(f"Debug: method={method}, service={service_name}, message={repr(message)}, topic={topic}")
    
    config = load_config(topic)
    notifier = NtfyNotifier(config)
    
    title = f"systemd: {service_name}"
    
    if method == "success":
        result = notifier.send_success_notification(message, title)
    elif method == "error":
        result = notifier.send_error_notification(message, title)
    elif method == "warning":
        result = notifier.send_warning_notification(message, title)
    elif method == "info":
        result = notifier.send_info_notification(message, title)
    else:
        # Default to info
        result = notifier.send_info_notification(message, title)
    
    sys.exit(0 if result else 1)

if __name__ == "__main__":
    main()