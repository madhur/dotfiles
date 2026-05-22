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

CURL_AUTH=()
if [ -n "${NTFY_TOKEN:-}" ]; then
    CURL_AUTH=(-H "Authorization: Bearer ${NTFY_TOKEN}")
elif [ -n "${NTFY_USERNAME:-}" ] && [ -n "${NTFY_PASSWORD:-}" ]; then
    CURL_AUTH=(-u "${NTFY_USERNAME}:${NTFY_PASSWORD}")
fi

if [ ! -S "/tmp/.X11-unix/X${DISPLAY_TARGET#:}" ]; then
    echo "X server $DISPLAY_TARGET is not running" >&2
    curl -fsS -X POST \
        -H "Title: $TITLE" \
        -H "Tags: warning" \
        "${CURL_AUTH[@]}" \
        -d "X server $DISPLAY_TARGET is not running" \
        "$NTFY_URL" >/dev/null
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

curl -fsS -X POST \
    -H "Title: $TITLE" \
    -H "Message: $MESSAGE" \
    -H "Filename: $FILENAME" \
    -H "Tags: camera_flash" \
    -H "Content-Type: image/jpeg" \
    "${CURL_AUTH[@]}" \
    --data-binary @"$BUF" \
    "$NTFY_URL" >/dev/null

echo "Posted $FILENAME ($MESSAGE) to $NTFY_URL"
