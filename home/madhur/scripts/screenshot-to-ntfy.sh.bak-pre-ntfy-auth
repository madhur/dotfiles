#!/bin/bash
# Capture X display :0, downscale, push to ntfy as an image notification.
# Nothing is written to disk — import → magick → curl is fully piped.

set -euo pipefail

NTFY_URL="${NTFY_URL:-https://ntfy.madhur.co.in/private}"
DISPLAY_TARGET="${DISPLAY_TARGET:-:0}"
RESIZE="${RESIZE:-50%}"
QUALITY="${QUALITY:-70}"
TITLE="${NTFY_TITLE:-Screenshot ($(hostname))}"

export DISPLAY="$DISPLAY_TARGET"
export XAUTHORITY="${XAUTHORITY:-$HOME/.Xauthority}"

# Push via the instrumented homelab-ntfy bridge (service=ntfy metrics). It reads
# NTFY_SERVER/NTFY_TOPIC (+ NTFY_TOKEN | NTFY_USERNAME/PASSWORD) from the env, so
# split the configured URL into server + topic and export them.
HOMELAB_NTFY="${HOMELAB_NTFY:-/home/madhur/.virtualenvs/python-rsha/bin/homelab-ntfy}"
export NTFY_SERVER="${NTFY_URL%/*}"
export NTFY_TOPIC="${NTFY_URL##*/}"
# Propagate any auth the caller set so the subprocess (homelab-ntfy) sees it.
[ -n "${NTFY_TOKEN:-}" ] && export NTFY_TOKEN
[ -n "${NTFY_USERNAME:-}" ] && export NTFY_USERNAME
[ -n "${NTFY_PASSWORD:-}" ] && export NTFY_PASSWORD

if [ ! -S "/tmp/.X11-unix/X${DISPLAY_TARGET#:}" ]; then
    echo "X server $DISPLAY_TARGET is not running" >&2
    "$HOMELAB_NTFY" --title "$TITLE" --tags warning --source screenshot_to_ntfy \
        "X server $DISPLAY_TARGET is not running" >/dev/null || true
    exit 1
fi

FILENAME="screenshot_$(date +%Y%m%d_%H%M%S).jpg"

# Buffer the encoded JPEG in tmpfs (RAM, not disk) so we can read its
# dimensions/size before posting.
BUF=$(mktemp --tmpdir=/dev/shm screenshot.XXXXXX.jpg)
trap 'rm -f "$BUF"' EXIT

import -display "$DISPLAY_TARGET" -window root png:- \
  | magick - -resize "$RESIZE" -quality "$QUALITY" jpg:- > "$BUF"

DIMS=$(magick identify -format "%wx%h" "$BUF")
SIZE=$(stat -c %s "$BUF" | numfmt --to=iec --suffix=B --format="%.1f")
MESSAGE="${DIMS} • ${SIZE}"

# Rename the buffer to the desired ntfy filename; --file sets the attachment
# Filename header from the path's basename.
SHOT="$(dirname "$BUF")/$FILENAME"
mv "$BUF" "$SHOT"
trap 'rm -f "$SHOT"' EXIT

"$HOMELAB_NTFY" --file "$SHOT" --title "$TITLE" --tags camera_flash \
    --source screenshot_to_ntfy "$MESSAGE" >/dev/null

echo "Posted $FILENAME ($MESSAGE) to $NTFY_SERVER/$NTFY_TOPIC"
