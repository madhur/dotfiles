#!/usr/bin/env python3
"""
Post-processing for Desktop Recording Sessions
Generates SRT subtitles from keylog - no video processing needed.
"""

import json
import re
import sys
from datetime import datetime
from pathlib import Path

# Key mappings from logkeys format to display format
KEY_MAPPINGS = {
    "<Enter>": "[ENTER]",
    "<BckSp>": "[BACKSPACE]",
    "<Tab>": "[TAB]",
    "<Esc>": "[ESC]",
    "<Space>": "[SPACE]",
    "<Up>": "[UP]",
    "<Down>": "[DOWN]",
    "<Left>": "[LEFT]",
    "<Right>": "[RIGHT]",
    "<Home>": "[HOME]",
    "<End>": "[END]",
    "<PgUp>": "[PGUP]",
    "<PgDn>": "[PGDN]",
    "<Del>": "[DEL]",
    "<Ins>": "[INS]",
    "<Caps>": "[CAPS]",
    "<LShft>": "[SHIFT]",
    "<RShft>": "[SHIFT]",
    "<LCtrl>": "[CTRL]",
    "<RCtrl>": "[CTRL]",
    "<LAlt>": "[ALT]",
    "<RAlt>": "[ALT]",
    "<LMeta>": "[META]",
    "<RMeta>": "[META]",
}


def load_metadata(session_path):
    """Load session metadata."""
    metadata_file = session_path / "metadata.json"
    if metadata_file.exists():
        with open(metadata_file) as f:
            return json.load(f)
    return {}


def format_srt_time(seconds):
    """Format seconds as SRT timestamp (HH:MM:SS,mmm)."""
    hours = int(seconds // 3600)
    minutes = int((seconds % 3600) // 60)
    secs = int(seconds % 60)
    millis = int((seconds % 1) * 1000)
    return f"{hours:02d}:{minutes:02d}:{secs:02d},{millis:03d}"


def parse_logkeys_line(line):
    """Parse a logkeys line and extract timestamp and keys."""
    match = re.match(r"(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})(?:[+-]\d{4})? > (.+)", line)
    if not match:
        return None, None

    timestamp_str = match.group(1)
    key_text = match.group(2)

    try:
        timestamp = datetime.strptime(timestamp_str, "%Y-%m-%d %H:%M:%S")
    except ValueError:
        return None, None

    return timestamp, key_text


def format_keys_for_display(key_text):
    """Convert key text to display format with brackets."""
    result = []
    i = 0
    while i < len(key_text):
        if key_text[i] == "<":
            end = key_text.find(">", i)
            if end != -1:
                special_key = key_text[i:end + 1]
                display = KEY_MAPPINGS.get(special_key, f"[{special_key[1:-1].upper()}]")
                result.append(display)
                i = end + 1
                continue
        char = key_text[i]
        if char == " ":
            result.append("[SPACE]")
        else:
            result.append(f"[{char}]")
        i += 1
    return "".join(result)


def generate_srt(session_path, video_start_time):
    """Generate SRT subtitle file from keylog."""
    keylog_path = session_path / "keylog.txt"
    srt_path = session_path / "recording.srt"

    if not keylog_path.exists():
        print(f"Keylog file not found: {keylog_path}")
        return None

    entries = []
    with open(keylog_path, "r", errors="replace") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            timestamp, key_text = parse_logkeys_line(line)
            if timestamp is None:
                continue
            offset = (timestamp - video_start_time).total_seconds()
            if offset < 0:
                offset = 0
            display_text = format_keys_for_display(key_text)
            entries.append((offset, display_text))

    if not entries:
        print("No keylog entries found")
        return None

    # Group entries within 0.5 seconds
    grouped = []
    current = None
    for offset, text in entries:
        if current is None:
            current = {"start": offset, "end": offset + 2, "texts": [text]}
        elif offset - current["start"] < 0.5:
            current["texts"].append(text)
            current["end"] = offset + 2
        else:
            grouped.append(current)
            current = {"start": offset, "end": offset + 2, "texts": [text]}
    if current:
        grouped.append(current)

    # Write SRT
    with open(srt_path, "w") as f:
        for i, entry in enumerate(grouped, 1):
            text = "".join(entry["texts"])
            if len(text) > 80:
                text = "\n".join([text[j:j + 80] for j in range(0, len(text), 80)])
            f.write(f"{i}\n")
            f.write(f"{format_srt_time(entry['start'])} --> {format_srt_time(entry['end'])}\n")
            f.write(f"{text}\n\n")

    print(f"Generated {len(grouped)} subtitle entries: {srt_path}")
    return srt_path


def process_session(session_path):
    """Process a recording session - just generate SRT."""
    session_path = Path(session_path)
    print(f"Processing: {session_path}")

    metadata = load_metadata(session_path)
    if metadata:
        video_start_time = datetime.fromisoformat(metadata["start_time"])
    else:
        print("Warning: No metadata, using file modification time")
        video_start_time = datetime.now()

    # Check video exists
    video_file = session_path / "recording.mkv"
    if not video_file.exists():
        print(f"No video file found: {video_file}")
        return False

    # Generate subtitles
    generate_srt(session_path, video_start_time)

    # Mark as processed
    (session_path / ".processed").touch()
    (session_path / ".needs_processing").unlink(missing_ok=True)

    print(f"Done. Play with: mpv {video_file}")
    return True


def main():
    if len(sys.argv) > 1:
        session_path = Path(sys.argv[1])
        if not session_path.exists():
            print(f"Session not found: {session_path}")
            sys.exit(1)
        process_session(session_path)
    else:
        # Find unprocessed sessions
        output_dir = Path("/home/madhur/Screenshots/Timeline")
        for session in output_dir.glob("session_*"):
            if session.is_dir() and not (session / ".processed").exists():
                if (session / "recording.mkv").exists():
                    process_session(session)


if __name__ == "__main__":
    main()
