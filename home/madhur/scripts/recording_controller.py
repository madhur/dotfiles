#!/usr/bin/env python3
"""
Desktop Recording Controller with Keylogging
Records screen to MKV (crash-resilient) and logs keystrokes.
"""

import atexit
import json
import os
import signal
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

# =============================================================================
# CONFIGURATION
# =============================================================================

CONFIG = {
    "output_dir": "/home/madhur/Screenshots/Timeline",
    "capture_resolution": "3840x2160",  # Primary monitor native resolution
    "capture_offset": "0,769",          # Primary monitor position
    "output_resolution": "1920x1080",   # Scale down for smaller files
    "framerate": 15,
    "crf": 28,
    "preset": "ultrafast",
    "state_file": "/tmp/desktop_recording.state",
    "logkeys_path": "/usr/bin/logkeys",
}

# =============================================================================
# GLOBALS
# =============================================================================

ffmpeg_process = None
session_dir = None
shutdown_requested = False


def get_screen_resolution():
    """Get screen resolution using xdpyinfo."""
    try:
        output = subprocess.check_output(["xdpyinfo"], stderr=subprocess.DEVNULL).decode()
        for line in output.split("\n"):
            if "dimensions:" in line:
                parts = line.split()
                for part in parts:
                    if "x" in part and part[0].isdigit():
                        return part.split()[0]
    except (subprocess.CalledProcessError, FileNotFoundError):
        pass
    return "1920x1080"


def create_session_directory():
    """Create a new session directory with timestamp."""
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    session_name = f"session_{timestamp}"
    session_path = Path(CONFIG["output_dir"]) / session_name
    session_path.mkdir(parents=True, exist_ok=True)
    return session_path


def write_state_file(session_path):
    """Write state file for recovery and stop script."""
    state = {
        "pid": os.getpid(),
        "session_dir": str(session_path),
        "start_time": datetime.now().isoformat(),
    }
    with open(CONFIG["state_file"], "w") as f:
        json.dump(state, f)


def remove_state_file():
    """Remove state file on clean shutdown."""
    try:
        os.remove(CONFIG["state_file"])
    except FileNotFoundError:
        pass


def write_metadata(session_path, start_time):
    """Write session metadata."""
    metadata = {
        "start_time": start_time.isoformat(),
        "resolution": CONFIG["output_resolution"],
        "framerate": CONFIG["framerate"],
    }
    with open(session_path / "metadata.json", "w") as f:
        json.dump(metadata, f, indent=2)


def start_ffmpeg(session_path):
    """Start FFmpeg recording to MKV."""
    global ffmpeg_process

    output_file = str(session_path / "recording.mkv")

    cmd = [
        "ffmpeg",
        "-f", "x11grab",
        "-video_size", CONFIG["capture_resolution"],
        "-framerate", str(CONFIG["framerate"]),
        "-i", f":0.0+{CONFIG['capture_offset']}",  # Primary monitor
        "-vf", f"scale={CONFIG['output_resolution'].replace('x', ':')}",  # Scale down
        "-c:v", "libx264",
        "-preset", CONFIG["preset"],
        "-crf", str(CONFIG["crf"]),
        output_file,
    ]

    print(f"Starting FFmpeg: {' '.join(cmd)}", flush=True)
    ffmpeg_process = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return ffmpeg_process


def stop_ffmpeg():
    """Stop FFmpeg gracefully."""
    global ffmpeg_process
    if ffmpeg_process:
        print("Stopping FFmpeg...")
        ffmpeg_process.send_signal(signal.SIGINT)
        try:
            ffmpeg_process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            ffmpeg_process.kill()
        ffmpeg_process = None


def start_logkeys(session_path):
    """Start logkeys keylogger."""
    subprocess.run(["sudo", CONFIG["logkeys_path"], "-k"], capture_output=True, timeout=5)

    keylog_file = session_path / "keylog.txt"
    cmd = ["sudo", CONFIG["logkeys_path"], "-s", "-o", str(keylog_file)]

    print(f"Starting logkeys: {' '.join(cmd)}", flush=True)
    # Use Popen since logkeys daemonizes and run() may block
    subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(1)  # Give logkeys time to start
    return True


def stop_logkeys(session_path=None):
    """Stop logkeys keylogger."""
    print("Stopping logkeys...")
    subprocess.run(["sudo", CONFIG["logkeys_path"], "-k"], capture_output=True)

    if session_path:
        keylog_file = session_path / "keylog.txt"
        if keylog_file.exists():
            subprocess.run(["sudo", "chmod", "644", str(keylog_file)], capture_output=True)


def signal_handler(signum, frame):
    """Handle shutdown signals gracefully."""
    global shutdown_requested
    print(f"\nReceived signal {signum}, shutting down...")
    shutdown_requested = True


def cleanup(logkeys_started=True):
    """Clean up resources on exit."""
    global session_dir

    print("\nShutting down...")
    stop_ffmpeg()
    if logkeys_started:
        stop_logkeys(session_dir)
    remove_state_file()

    if session_dir:
        marker = session_dir / ".needs_processing"
        marker.touch()
        print(f"Recording stopped. Session: {session_dir}")

        postprocess_script = Path(__file__).parent / "recording_postprocess.py"
        if postprocess_script.exists():
            print("\nGenerating subtitles...")
            subprocess.run([sys.executable, str(postprocess_script), str(session_dir)])


def main():
    global session_dir, shutdown_requested

    if os.path.exists(CONFIG["state_file"]):
        print("Error: Recording already in progress.")
        print(f"State file exists: {CONFIG['state_file']}")
        sys.exit(1)

    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGINT, signal_handler)

    start_time = datetime.now()
    session_dir = create_session_directory()
    print(f"Session directory: {session_dir}")

    write_state_file(session_dir)
    write_metadata(session_dir, start_time)

    logkeys_started = start_logkeys(session_dir)
    atexit.register(lambda: cleanup(logkeys_started))

    start_ffmpeg(session_dir)
    print("Recording started.", flush=True)

    try:
        while not shutdown_requested:
            if ffmpeg_process and ffmpeg_process.poll() is not None:
                print("FFmpeg process ended unexpectedly")
                break
            for _ in range(10):
                if shutdown_requested:
                    break
                time.sleep(0.1)
    except KeyboardInterrupt:
        shutdown_requested = True

    cleanup(logkeys_started)


if __name__ == "__main__":
    main()
