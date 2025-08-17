#!/usr/bin/env python3
"""
Random Tweet Display Script for Conky
Parses Twitter timeline JSON and displays a random tweet
"""

import json
import random
import os

# Configuration
TWEETS_FILE = os.path.expanduser("~/.config/conky/tweets1.json")
MAX_TWEET_LENGTH = 1500  # Set to 1500 as requested
LINE_WIDTH = 60  # Characters per line for wrapping

def extract_tweet_text(tweet_result):
    """Extract the full tweet text, checking multiple possible locations"""
    
    # For retweets, we need to check the retweeted_status_result for the full text
    if 'legacy' in tweet_result and tweet_result['legacy'].get('full_text', '').startswith('RT @'):
        # The retweeted_status_result is under legacy
        if 'retweeted_status_result' in tweet_result['legacy']:
            retweeted_result = tweet_result['legacy']['retweeted_status_result'].get('result', {})
            
            # Check note_tweet in retweeted status first (for long tweets)
            if 'note_tweet' in retweeted_result:
                note_tweet_results = retweeted_result['note_tweet'].get('note_tweet_results', {})
                if 'result' in note_tweet_results:
                    note_text = note_tweet_results['result'].get('text')
                    if note_text:
                        # For retweets, prepend the RT info
                        rt_prefix = tweet_result['legacy']['full_text'].split(':', 1)[0] + ': '
                        return rt_prefix + note_text
            
            # Fallback to retweeted legacy text (this should work for most cases)
            if 'legacy' in retweeted_result and 'full_text' in retweeted_result['legacy']:
                rt_text = retweeted_result['legacy']['full_text']
                rt_prefix = tweet_result['legacy']['full_text'].split(':', 1)[0] + ': '
                return rt_prefix + rt_text
    
    # For original tweets, check note_tweet first
    if 'note_tweet' in tweet_result:
        note_tweet_results = tweet_result['note_tweet'].get('note_tweet_results', {})
        if 'result' in note_tweet_results:
            note_text = note_tweet_results['result'].get('text')
            if note_text:
                return note_text
    
    # Fallback to legacy full_text
    if 'legacy' in tweet_result and 'full_text' in tweet_result['legacy']:
        return tweet_result['legacy']['full_text']
    
    return None
def load_tweets():
    """Load and parse tweets from JSON file"""
    try:
        with open(TWEETS_FILE, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        tweets = []
        
        # Navigate through the JSON structure to find tweets
        timeline_instructions = data['data']['user']['result']['timeline']['timeline']['instructions']
        
        for instruction in timeline_instructions:
            if instruction['type'] == 'TimelineAddEntries':
                for entry in instruction['entries']:
                    if entry['entryId'].startswith('tweet-'):
                        try:
                            tweet_result = entry['content']['itemContent']['tweet_results']['result']
                            
                            # Extract tweet text using the new function
                            full_text = extract_tweet_text(tweet_result)
                            if full_text:
                                # Process both original tweets and retweets
                                clean_text = clean_tweet_text(full_text)
                                if clean_text:
                                    tweet_data = {
                                        'text': clean_text,
                                        'created_at': tweet_result['legacy']['created_at'],
                                        'favorite_count': tweet_result['legacy']['favorite_count'],
                                        'retweet_count': tweet_result['legacy']['retweet_count']
                                    }
                                    
                                    # Mark retweets
                                    if full_text.startswith('RT @'):
                                        tweet_data['is_retweet'] = True
                                    
                                    tweets.append(tweet_data)
                        except KeyError:
                            # Skip malformed tweet entries
                            continue
            
            # Also check pinned tweets
            elif instruction['type'] == 'TimelinePinEntry':
                try:
                    tweet_result = instruction['entry']['content']['itemContent']['tweet_results']['result']
                    
                    # Extract tweet text using the new function
                    full_text = extract_tweet_text(tweet_result)
                    if full_text:
                        if not full_text.startswith('RT @'):
                            clean_text = clean_tweet_text(full_text)
                            if clean_text:
                                tweets.append({
                                    'text': clean_text,
                                    'created_at': tweet_result['legacy']['created_at'],
                                    'favorite_count': tweet_result['legacy']['favorite_count'],
                                    'retweet_count': tweet_result['legacy']['retweet_count'],
                                    'pinned': True
                                })
                except KeyError:
                    continue
        
        return tweets
        
    except FileNotFoundError:
        print(f"Error: Tweet file not found at {TWEETS_FILE}")
        return []
    except json.JSONDecodeError:
        print("Error: Invalid JSON in tweet file")
        return []
    except Exception as e:
        print(f"Error loading tweets: {e}")
        return []

def wrap_text(text, width=LINE_WIDTH):
    """Wrap text to specified width, breaking at word boundaries"""
    import textwrap
    
    # Use textwrap to handle word wrapping intelligently
    wrapped_lines = textwrap.wrap(text, width=width, break_long_words=False, break_on_hyphens=False)
    return '\n'.join(wrapped_lines)

def clean_tweet_text(text):
    """Clean and format tweet text for display"""
    if not text:
        return ""
    
    # Remove URLs (https://t.co/...)
    import re
    text = re.sub(r'https://t\.co/\w+', '', text)
    
    # Remove extra whitespace
    text = ' '.join(text.split())
    
    # Replace some HTML entities that might appear
    text = text.replace('&amp;', '&')
    text = text.replace('&lt;', '<')
    text = text.replace('&gt;', '>')
    
    # Only truncate if extremely long (this should rarely trigger now)
    if len(text) > MAX_TWEET_LENGTH:
        text = text[:MAX_TWEET_LENGTH-3] + "..."
    
    # Wrap the text to fit Conky width
    text = wrap_text(text)
    
    return text.strip()

def should_update_tweet():
    """Check if it's time to update the tweet"""
    if not os.path.exists(CACHE_FILE):
        return True
    
    try:
        with open(CACHE_FILE, 'rb') as f:
            cache_data = pickle.load(f)
        
        last_update = cache_data.get('last_update')
        if not last_update:
            return True
        
        # Check if enough time has passed
        time_diff = datetime.now() - last_update
        return time_diff >= timedelta(hours=UPDATE_INTERVAL_HOURS)
        
    except Exception:
        return True

def save_tweet_cache(tweet):
    """Save current tweet and timestamp to cache"""
    try:
        os.makedirs(os.path.dirname(CACHE_FILE), exist_ok=True)
        cache_data = {
            'tweet': tweet,
            'last_update': datetime.now()
        }
        with open(CACHE_FILE, 'wb') as f:
            pickle.dump(cache_data, f)
    except Exception as e:
        print(f"Warning: Could not save cache: {e}")

def load_cached_tweet():
    """Load cached tweet if available"""
    try:
        with open(CACHE_FILE, 'rb') as f:
            cache_data = pickle.load(f)
        return cache_data.get('tweet')
    except Exception:
        return None

def format_tweet_for_display(tweet):
    """Format tweet for Conky display"""
    if not tweet:
        return "No tweets available"
    
    text = tweet['text']
    
    # Add some stats if available
    stats = []
    # if tweet.get('favorite_count', 0) > 0:
    #     stats.append(f" {tweet['favorite_count']}")
    # if tweet.get('retweet_count', 0) > 0:
    #     stats.append(f" {tweet['retweet_count']}")
    
    if stats:
        text += f"\n{' | '.join(stats)}"
    
    # Add indicators
    if tweet.get('pinned'):
        text = "󰐃 " + text
    elif tweet.get('is_retweet'):
        text = " " + text
    
    return text

def main():
    """Main function"""
    tweets = load_tweets()
    
    if not tweets:
        print("No tweets found")
        return
    
    # Debug: Show how many tweets we found
    # Uncomment the next line to see tweet count and first few tweets for debugging
    # print(f"DEBUG: Found {len(tweets)} tweets", file=sys.stderr)
    # for i, t in enumerate(tweets[:3]): print(f"DEBUG {i}: {t['text'][:50]}...", file=sys.stderr)
    
    # Always select a random tweet
    selected_tweet = random.choice(tweets)
    
    # Display the tweet
    print(format_tweet_for_display(selected_tweet))

if __name__ == "__main__":
    main()