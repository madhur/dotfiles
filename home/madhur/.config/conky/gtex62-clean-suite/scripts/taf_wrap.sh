#!/usr/bin/env bash
set -euo pipefail

# Usage: taf_wrap.sh [WRAP_COL] [MAX_LINES] [STATION]
WRAP_COL="${1:-40}"
MAX_LINES="${2:-4}"
STATION="$(echo "${3:-${STATION:-KMEM}}" | tr '[:lower:]' '[:upper:]')"

# Try the AWC API which preserves logical breaks; fall back to taf.sh
raw="$(curl -fsS "https://aviationweather.gov/api/data/taf?ids=${STATION}&hours=0&sep=true" 2>/dev/null || true)"
# if [ -z "${raw}" ]; then
#   raw="$(~/.config/conky/gtex62-clean-suite/scripts/taf.sh "$STATION" 2>/dev/null || true)"
# fi
[ -n "${raw:-}" ] || exit 0

# Normalize endings, drop everything after the first "=" line (end marker)
raw="$(printf '%s' "$raw" | tr -d '\r')"
raw="$(printf '%s\n' "$raw" | awk '/^[[:space:]]*=/ {exit} {print}')"

# Collapse to one line, keep only from first "TAF " onward,
# then insert newlines before FM/TEMPO/PROBxx/BECMG groups.
one_line="$(printf '%s' "$raw" | tr '\n' ' ' | tr -s ' ' | sed -E 's/[[:space:]]+$//')"
one_line="$(printf '%s' "$one_line" | sed -E 's/^.*\bTAF[[:space:]]+/TAF /')"
segmented="$(printf '%s' "$one_line" \
  | sed -E 's/[[:space:]]+(FM[0-9]{6})/\n\1/g; s/[[:space:]]+(TEMPO)/\n\1/g; s/[[:space:]]+(PROB[0-9]{2})/\n\1/g; s/[[:space:]]+(BECMG)/\n\1/g')"

# Wrap each logical line to WRAP_COL, cap to MAX_LINES total
printf '%s\n' "$segmented" | awk -v col="$WRAP_COL" -v maxl="$MAX_LINES" '
function trim(s){ gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
{
  s = trim($0); if (s=="") next;
  while (length(s) > col) {
    splitPos = 0;
    for (i = col; i > 1; i--) if (substr(s, i, 1) == " ") { splitPos = i; break }
    if (splitPos == 0) splitPos = col;
    out = substr(s, 1, splitPos - 1);
    print out;
    lines++;
    if (lines >= maxl) exit;
    s = substr(s, splitPos + 1);
    gsub(/^[ \t]+/, "", s);
  }
  print s;
  lines++;
  if (lines >= maxl) exit;
}
END {
  # If truncated, add an ellipsis on the last printed line is handled by caller if needed.
}'
