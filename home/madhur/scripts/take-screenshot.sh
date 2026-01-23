#!/bin/bash

# Set display environment for SSH/cron execution
if [ -z "$DISPLAY" ] && [ -z "$WAYLAND_DISPLAY" ]; then
    export DISPLAY=:0
    export XAUTHORITY="$HOME/.Xauthority"
fi

# Parse command line arguments
TIMER_MODE=false
for arg in "$@"; do
    case $arg in
        --timer)
            TIMER_MODE=true
            shift
            ;;
    esac
done

# Check if screenshot is disabled via flag file (in /tmp so it resets on reboot)
if [ -f "/tmp/screenshot-timeline-disabled" ]; then
    echo "Screenshot disabled via flag file"
    exit 0
fi

# Check screenshot frequency mode (only when called from automated timer)
# Manual and OliveTin calls should always take a screenshot
if [[ "$TIMER_MODE" == "true" ]]; then
    # If 5-min mode flag file doesn't exist (30-min mode), check if last screenshot is too recent
    FREQ_FLAG_FILE="/tmp/screenshot-5min-mode"
    if [[ ! -f "$FREQ_FLAG_FILE" ]]; then
        # 30-min mode: check last screenshot timestamp
        SCREENSHOT_DIR_CHECK="$HOME/Screenshots/Timeline"
        latest=$(ls -t "$SCREENSHOT_DIR_CHECK"/screenshot_*.png 2>/dev/null | head -1)
        if [[ -n "$latest" ]]; then
            last_mod=$(stat -c %Y "$latest")
            now=$(date +%s)
            age=$((now - last_mod))
            if [[ $age -lt 43200 ]]; then  # 12 hours = 43200 seconds
                echo "Skipping screenshot - last one was $age seconds ago (timer mode)"
                exit 0
            fi
        fi
    fi
fi

# Configuration
SCREENSHOT_DIR="$HOME/Screenshots/Timeline"
DATE=$(date +"%Y-%m-%d_%H-%M-%S")
FILENAME="screenshot_${DATE}.png"
SCREENSHOT_TOOL=""  # Initialize the tool variable

# Ensure directory exists
mkdir -p "$SCREENSHOT_DIR"

# Function to check if screen is locked or screensaver is active
is_screen_locked() {
    # Check loginctl (systemd) for session state - works on both X11 and Wayland
    if command -v loginctl &> /dev/null; then
        # Get current session ID
        SESSION_ID=$(loginctl | grep $(whoami) | grep -E '(seat|tty)' | head -1 | awk '{print $1}')
        if [ -n "$SESSION_ID" ]; then
            SESSION_STATE=$(loginctl show-session "$SESSION_ID" -p LockedHint 2>/dev/null | cut -d= -f2)
            if [ "$SESSION_STATE" = "yes" ]; then
                echo "Session is locked (loginctl)"
                return 0
            fi
        fi
    fi
    
    # Check GNOME screensaver (works on both X11 and Wayland)
    if command -v gnome-screensaver-command &> /dev/null; then
        if gnome-screensaver-command -q 2>/dev/null | grep -q "is active"; then
            echo "GNOME screensaver is active"
            return 0
        fi
    fi
    
    # Check if running on a virtual terminal (not graphical)
    if [ -z "$DISPLAY" ] && [ -z "$WAYLAND_DISPLAY" ]; then
        echo "No display available"
        return 0
    fi
    
    # For X11 only - check DPMS state
    if [ -n "$DISPLAY" ] && command -v xset &> /dev/null; then
        DPMS_STATE=$(xset q 2>/dev/null | grep "DPMS is" | awk '{print $3}')
        if [ "$DPMS_STATE" = "Enabled" ]; then
            MONITOR_STATE=$(xset q 2>/dev/null | grep "Monitor is" | awk '{print $3}')
            if [ "$MONITOR_STATE" = "Off" ]; then
                echo "Display is off (DPMS)"
                return 0
            fi
        fi
    fi
    
    # Check for KDE screen lock
    if command -v qdbus &> /dev/null; then
        # KDE 5
        if qdbus org.kde.screensaver /ScreenSaver GetActive 2>/dev/null | grep -q "true"; then
            echo "KDE screensaver is active"
            return 0
        fi
        # KDE 6
        if qdbus org.kde.KWin /ScreenLocker GetActive 2>/dev/null | grep -q "true"; then
            echo "KDE screen is locked"
            return 0
        fi
    fi
    
    return 1
}

# Check if we should skip screenshot
if is_screen_locked; then
    echo "Skipping screenshot - screen is locked or inactive"
    exit 0
fi

# Detect session type
if [ -n "$WAYLAND_DISPLAY" ]; then
    SESSION_TYPE="wayland"
elif [ -n "$DISPLAY" ]; then
    SESSION_TYPE="x11"
else
    SESSION_TYPE="unknown"
fi

echo "Detected session type: $SESSION_TYPE"

# Take screenshot using different methods based on session type and available tools
if [ "$SESSION_TYPE" = "wayland" ]; then
    # Wayland-specific screenshot tools
    if command -v grim &> /dev/null; then
        # grim (generic Wayland)
        SCREENSHOT_TOOL="grim"
        grim "$SCREENSHOT_DIR/$FILENAME"
    elif command -v wayshot &> /dev/null; then
        # wayshot (alternative Wayland tool)
        SCREENSHOT_TOOL="wayshot"
        wayshot -f "$SCREENSHOT_DIR/$FILENAME"
    elif command -v gnome-screenshot &> /dev/null; then
        # GNOME screenshot (works on Wayland but deprecated)
        SCREENSHOT_TOOL="gnome-screenshot"
        gnome-screenshot -f "$SCREENSHOT_DIR/$FILENAME"
    elif command -v spectacle &> /dev/null; then
        # KDE Spectacle (works on Wayland)
        SCREENSHOT_TOOL="spectacle"
        spectacle -b -f -o "$SCREENSHOT_DIR/$FILENAME"
    elif command -v flameshot &> /dev/null; then
        # Flameshot (has Wayland support)
        SCREENSHOT_TOOL="flameshot"
        flameshot full -p "$SCREENSHOT_DIR" -d 0
        # Flameshot doesn't use our filename format, so we need to rename
        LATEST_FLAMESHOT=$(ls -t "$SCREENSHOT_DIR"/Screenshot_*.png 2>/dev/null | head -1)
        if [ -n "$LATEST_FLAMESHOT" ]; then
            mv "$LATEST_FLAMESHOT" "$SCREENSHOT_DIR/$FILENAME"
        fi
    else
        echo "No Wayland-compatible screenshot tool found."
        echo "Please install one of: grim, wayshot, spectacle, or flameshot"
        exit 1
    fi
else
    # X11 or fallback screenshot tools
    if command -v gnome-screenshot &> /dev/null; then
        # GNOME screenshot tool
        SCREENSHOT_TOOL="gnome-screenshot"
        gnome-screenshot -f "$SCREENSHOT_DIR/$FILENAME"
    elif command -v scrot &> /dev/null; then
        # scrot (lightweight, X11 only)
        SCREENSHOT_TOOL="scrot"
        scrot "$SCREENSHOT_DIR/$FILENAME"
    elif command -v spectacle &> /dev/null; then
        # KDE Spectacle
        SCREENSHOT_TOOL="spectacle"
        spectacle -b -f -o "$SCREENSHOT_DIR/$FILENAME"
    elif command -v import &> /dev/null; then
        # ImageMagick import (X11 only)
        SCREENSHOT_TOOL="import"
        import -window root "$SCREENSHOT_DIR/$FILENAME"
    elif command -v flameshot &> /dev/null; then
        # Flameshot
        SCREENSHOT_TOOL="flameshot"
        flameshot full -p "$SCREENSHOT_DIR" -d 0
        # Rename to our format
        LATEST_FLAMESHOT=$(ls -t "$SCREENSHOT_DIR"/Screenshot_*.png 2>/dev/null | head -1)
        if [ -n "$LATEST_FLAMESHOT" ]; then
            mv "$LATEST_FLAMESHOT" "$SCREENSHOT_DIR/$FILENAME"
        fi
    else
        echo "No screenshot tool found."
        echo "Please install one of: gnome-screenshot, scrot, spectacle, imagemagick, or flameshot"
        exit 1
    fi
fi

# Compress PNG to reduce file size
if [ -f "$SCREENSHOT_DIR/$FILENAME" ]; then
    ORIGINAL_SIZE=$(stat -c %s "$SCREENSHOT_DIR/$FILENAME")
    if command -v pngquant &> /dev/null; then
        pngquant --quality=65-80 --force --output "$SCREENSHOT_DIR/$FILENAME" "$SCREENSHOT_DIR/$FILENAME"
        COMPRESSED_SIZE=$(stat -c %s "$SCREENSHOT_DIR/$FILENAME")
        SAVINGS=$((100 - (COMPRESSED_SIZE * 100 / ORIGINAL_SIZE)))
        echo "Compressed with pngquant (${SAVINGS}% reduction)"
    elif command -v optipng &> /dev/null; then
        optipng -o2 -quiet "$SCREENSHOT_DIR/$FILENAME"
        echo "Compressed with optipng"
    fi
fi

# Verify screenshot was actually taken
if [ -f "$SCREENSHOT_DIR/$FILENAME" ]; then
    echo "Screenshot saved: $FILENAME (using $SCREENSHOT_TOOL)"
    echo "File size: $(du -h "$SCREENSHOT_DIR/$FILENAME" | cut -f1)"
else
    echo "Failed to save screenshot using $SCREENSHOT_TOOL"
    exit 1
fi

# Optional: Clean up old screenshots (older than 90 days)
find "$SCREENSHOT_DIR" -name "screenshot_*.png" -type f -mtime +90 -delete 2>/dev/null || true