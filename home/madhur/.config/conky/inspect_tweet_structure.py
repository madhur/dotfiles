#!/usr/bin/env python3
"""
Inspect specific tweet structure to understand the JSON layout
"""

import json
import os

TWEETS_FILE = os.path.expanduser("~/.config/conky/tweets1.json")

def print_structure(obj, path="", max_depth=3, current_depth=0):
    """Print the structure of a nested object"""
    if current_depth > max_depth:
        return
    
    if isinstance(obj, dict):
        for key, value in obj.items():
            if key in ['retweeted_status_result', 'note_tweet', 'legacy', 'result']:
                print(f"{path}.{key}: {type(value)}")
                if isinstance(value, dict) and 'text' in value:
                    print(f"  -> HAS TEXT: {value['text'][:100]}...")
                print_structure(value, f"{path}.{key}", max_depth, current_depth + 1)
            elif key == 'text':
                print(f"{path}.{key}: {value[:100]}...")
            elif key == 'full_text':
                print(f"{path}.{key}: {value[:100]}...")

def main():
    with open(TWEETS_FILE, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    timeline_instructions = data['data']['user']['result']['timeline']['timeline']['instructions']
    
    # Find a specific retweet that's being truncated
    for instruction in timeline_instructions:
        if instruction['type'] == 'TimelineAddEntries':
            for entry in instruction['entries']:
                if entry['entryId'].startswith('tweet-1942433762165371225'):  # The orangebook tweet about money
                    print("=== TWEET STRUCTURE ANALYSIS ===")
                    tweet_result = entry['content']['itemContent']['tweet_results']['result']
                    print_structure(tweet_result, "tweet_result")
                    
                    print("\n=== CHECKING PATHS ===")
                    
                    # Check main legacy
                    if 'legacy' in tweet_result:
                        print(f"Main legacy full_text: {tweet_result['legacy']['full_text'][:150]}...")
                    
                    # Check retweeted_status_result (corrected path)
                    if 'retweeted_status_result' in tweet_result['legacy']:
                        ret_result = tweet_result['legacy']['retweeted_status_result']['result']
                        ret_full_text = ret_result['legacy']['full_text']
                        print(f"Retweeted legacy full_text: {ret_full_text[:150]}...")
                        print(f"Retweeted full_text length: {len(ret_full_text)}")
                        
                        if 'note_tweet' in ret_result:
                            note_text = ret_result['note_tweet']['note_tweet_results']['result']['text']
                            print(f"Retweeted note_tweet text: {note_text[:150]}...")
                            print(f"Full note_tweet length: {len(note_text)}")
                        else:
                            print("No note_tweet found in retweeted status")
                            print(f"FULL retweeted text: {ret_full_text}")
                    
                    return

if __name__ == "__main__":
    main()