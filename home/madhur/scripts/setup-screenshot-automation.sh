#!/bin/bash

# Screenshot automation setup script
# This script sets up a systemd service and timer to take screenshots every 30 minutes

set -e

# Configuration
SCREENSHOT_DIR="$HOME/Screenshots/Timeline"
SERVICE_NAME="desktop-screenshot"
USERNAME=$(whoami)

echo "Setting up desktop screenshot automation..."

# Create screenshot directory
mkdir -p "$SCREENSHOT_DIR"
echo "Created screenshot directory: $SCREENSHOT_DIR"

# Create the screenshot script
cat > "$HOME/.local/bin/take-screenshot.sh" << 'EOF'
#!/bin/bash

# Configuration
SCREENSHOT_DIR="$HOME/Screenshots/Timeline"
DATE=$(date +"%Y-%m-%d_%H-%M-%S")
FILENAME="screenshot_${DATE}.png"

# Ensure directory exists
mkdir -p "$SCREENSHOT_DIR"

# Take screenshot using different methods based on available tools
if command -v gnome-screenshot &> /dev/null; then
    # GNOME screenshot tool
    gnome-screenshot -f "$SCREENSHOT_DIR/$FILENAME"
elif command -v scrot &> /dev/null; then
    # scrot (lightweight)
    scrot "$SCREENSHOT_DIR/$FILENAME"
elif command -v import &> /dev/null; then
    # ImageMagick import
    import -window root "$SCREENSHOT_DIR/$FILENAME"
elif command -v spectacle &> /dev/null; then
    # KDE Spectacle
    spectacle -b -f -o "$SCREENSHOT_DIR/$FILENAME"
else
    echo "No screenshot tool found. Please install one of: gnome-screenshot, scrot, imagemagick, or spectacle"
    exit 1
fi

# Optional: Clean up old screenshots (older than 90 days)
find "$SCREENSHOT_DIR" -name "screenshot_*.png" -type f -mtime +90 -delete 2>/dev/null || true

echo "Screenshot saved: $FILENAME"
EOF

# Make screenshot script executable
chmod +x "$HOME/.local/bin/take-screenshot.sh"
echo "Created screenshot script: $HOME/.local/bin/take-screenshot.sh"

# Create systemd user service directory
mkdir -p "$HOME/.config/systemd/user"

# Create systemd service file
cat > "$HOME/.config/systemd/user/${SERVICE_NAME}.service" << EOF
[Unit]
Description=Desktop Screenshot Service
After=graphical-session.target

[Service]
Type=oneshot
ExecStart=%h/.local/bin/take-screenshot.sh
Environment=DISPLAY=:0
Environment=WAYLAND_DISPLAY=wayland-0
Environment=XDG_RUNTIME_DIR=/run/user/%i

[Install]
WantedBy=default.target
EOF

# Create systemd timer file
cat > "$HOME/.config/systemd/user/${SERVICE_NAME}.timer" << EOF
[Unit]
Description=Take desktop screenshot every 30 minutes
Requires=${SERVICE_NAME}.service

[Timer]
OnCalendar=*:0/30
Persistent=true

[Install]
WantedBy=timers.target
EOF

echo "Created systemd service and timer files"

# Reload systemd user daemon
systemctl --user daemon-reload

# Enable and start the timer
systemctl --user enable "${SERVICE_NAME}.timer"
systemctl --user start "${SERVICE_NAME}.timer"

echo "Screenshot automation setup complete!"
echo ""
echo "Configuration:"
echo "  - Screenshots will be saved to: $SCREENSHOT_DIR"
echo "  - Frequency: Every 30 minutes"
echo "  - Service name: ${SERVICE_NAME}"
echo ""
echo "Useful commands:"
echo "  - Check timer status: systemctl --user status ${SERVICE_NAME}.timer"
echo "  - Check service logs: journalctl --user -u ${SERVICE_NAME}.service"
echo "  - Stop timer: systemctl --user stop ${SERVICE_NAME}.timer"
echo "  - Start timer: systemctl --user start ${SERVICE_NAME}.timer"
echo "  - Test screenshot manually: $HOME/.local/bin/take-screenshot.sh"
echo ""
echo "Note: Screenshots older than 90 days will be automatically cleaned up."
