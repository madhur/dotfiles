#!/usr/bin/env bash
set -euo pipefail
# airsig_list.sh [MAX_ITEMS]
# Prints up to MAX_ITEMS short lines like:
#   SIGMET TURB JE Eastern Gulf Coast 13:00Z–17:00Z
#   AIRMET IFR  JC Central Rockies     12:00Z–18:00Z
#
# Notes:
# - Uses the merged cache at /tmp/airsigmets.json (created by airsig_fetch.sh)
# - No distance filter yet (we'll add that later)

MAX_ITEMS="${1:-6}"
CACHE="/tmp/airsigmets.json"

# Ensure we have a fresh-ish cache
~/.config/conky/gtex62-clean-suite/scripts/airsig_fetch.sh >/dev/null 2>&1 || true
[ -s "$CACHE" ] || exit 0

jq -r '
  .features[]
  | .properties as $p
  | [
      ($p.type // $p.advisoryType // "ADVISORY"),
      ($p.phenomenon // $p.hazard // ""),
      ($p.region // ""),
      ($p.zone // ""),
      ($p.validTimeFrom // $p.validFrom // ""),
      ($p.validTimeTo   // $p.validTo   // "")
    ]
  | @tsv
' "$CACHE" \
| head -n "$MAX_ITEMS" \
| awk -F'\t' '
function trim(s){ sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
function tz(s,  m){ gsub(/\..*Z$/, "Z", s); if (match(s, /T([0-9][0-9]:[0-9][0-9])/, m)) return m[1]"Z"; return s }
{
  kind = trim($1); phen = trim($2); region = trim($3); zone = trim($4);
  from = tz($5); to = tz($6);
  printf "%s %s %s %s %s–%s\n",
         (kind==""?"ADVISORY":kind),
         phen, (region==""?"":region), (zone==""?"":zone), from, to
}'
