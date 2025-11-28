#!/usr/bin/env bash
set -euo pipefail
# Usage: station_latlon.sh ICAO
# Prints: "<lat> <lon>" in decimal degrees, or nothing on failure.

ICAO="$(echo "${1:-KMEM}" | tr '[:lower:]' '[:upper:]')"

# Grab the first line from decoded METAR (has DMS coords), e.g.:
# "MEMPHIS INTERNATIONAL AIRPORT , TN, United States (KMEM) 35-02N 089-59W 86M"
line="$(
  ~/.config/conky/gtex62-clean-suite/scripts/metar.sh "$ICAO" 2>/dev/null \
    | sed -n '1p'
)"

[ -n "${line:-}" ] || exit 0

# Extract DMS like 35-02N and 089-59W
lat_dms="$(grep -oE '[0-9]{2,3}-[0-9]{2}[NS]' <<<"$line" | head -n1)"
lon_dms="$(grep -oE '[0-9]{2,3}-[0-9]{2}[EW]' <<<"$line" | tail -n1)"

[ -n "${lat_dms:-}" ] && [ -n "${lon_dms:-}" ] || exit 0

to_dec() {
  # arg: DMS like 35-02N or 089-59W (deg-min with hemisphere)
  local s="$1"
  local deg="${s%%-*}"
  local rest="${s#*-}"
  local min="${rest%[NSEW]}"
  local hemi="${s: -1}"
  # remove leading zeros safely
  deg=$((10#$deg))
  min=$((10#$min))
  # decimal = deg + min/60, sign by hemisphere
  awk -v d="$deg" -v m="$min" -v h="$hemi" 'BEGIN{
    dec = d + (m/60.0);
    if (h=="S" || h=="W") dec = -dec;
    printf "%.6f\n", dec
  }'
}

lat="$(to_dec "$lat_dms")"
lon="$(to_dec "$lon_dms")"

# Output "<lat> <lon>"
printf "%s %s\n" "$lat" "$lon"
