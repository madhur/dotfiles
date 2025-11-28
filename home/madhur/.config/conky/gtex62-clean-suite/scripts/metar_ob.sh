#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   metar_ob.sh [STATION] [WRAP_COL]
#   STATION  : ICAO (default KMEM; case-insensitive)
#   WRAP_COL : wrap width in characters (default 40)
#
# Notes:
# - Pulls the decoded NOAA feed via your existing metar.sh
# - Extracts the raw METAR from the "ob:" line
# - Wraps to multiple lines without splitting tokens

STATION="$(echo "${1:-${STATION:-KMEM}}" | tr '[:lower:]' '[:upper:]')"
WRAP_COL="${2:-${WRAP_COL:-40}}"

# Fetch decoded text and extract the raw METAR after 'ob:'
line="$(
  ~/.config/conky/gtex62-clean-suite/scripts/metar.sh "$STATION" \
    | awk '/^ob:/{ sub(/^ob:[[:space:]]*/, ""); print; exit }'
)"

# Nothing to show if fetch failed
[ -n "${line:-}" ] || exit 0

# Multi-line word wrap at WRAP_COL, avoiding token splits
printf '%s\n' "$line" | awk -v col="$WRAP_COL" '
{
  gsub(/^[ \t]+|[ \t]+$/, "", $0)
  s = $0
  while (length(s) > col) {
    splitPos = 0
    for (i = col; i > 1; i--) {
      if (substr(s, i, 1) == " ") { splitPos = i; break }
    }
    if (splitPos == 0) splitPos = col
    print substr(s, 1, splitPos - 1)
    s = substr(s, splitPos + 1)
    gsub(/^[ \t]+/, "", s)
  }
  print s
}'


