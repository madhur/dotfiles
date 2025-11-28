#!/usr/bin/env bash
set -euo pipefail

# Usage: taf.sh [STATION]
# Returns a single line starting with "TAF ..." (no leading header),
# and trims anything after the first "=" separator.

STATION="$(echo "${1:-${STATION:-KMEM}}" | tr '[:lower:]' '[:upper:]')"
RAW="/tmp/taf_${STATION}_raw.txt"
AGE_LIMIT=1800  # 30 minutes
URL="https://tgftp.nws.noaa.gov/data/forecasts/taf/stations/${STATION}.TXT"

# Refresh raw cache if missing/old/zero-byte
need_fetch=1
if [ -f "$RAW" ] && [ -s "$RAW" ] && [ $(( $(date +%s) - $(stat -c %Y "$RAW") )) -lt "$AGE_LIMIT" ]; then
  need_fetch=0
fi

if [ $need_fetch -eq 1 ]; then
  tmp="$(mktemp)"
  if curl -fsS "$URL" -o "$tmp"; then
    mv "$tmp" "$RAW"
  else
    rm -f "$tmp"
  fi
fi

# If still nothing, bail quietly
[ -s "$RAW" ] || exit 0

# Collapse to one line, strip leading header before first "TAF",
# then trim anything from the first "=" to the end.
collapsed="$(tr -d '\r' < "$RAW" | tr '\n' ' ' | tr -s ' ' | sed -E 's/[[:space:]]+$//')"

cleaned="$(
  awk 'BEGIN{IGNORECASE=1}
  {
    # find first "TAF " (or "TAF")
    match($0, /TAF[[:space:]]/)
    if (RSTART == 0) { match($0, /TAF/); }
    if (RSTART > 0) {
      s = substr($0, RSTART)
    } else {
      s = $0
    }
    print s
  }' <<<"$collapsed" \
  | sed -E 's/[[:space:]]*=[[:space:]]*.*$//'   # cut at first "=" (and any trailing stuff)
)"

printf '%s\n' "$cleaned"
