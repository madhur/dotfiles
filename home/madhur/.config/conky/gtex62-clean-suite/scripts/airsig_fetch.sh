#!/usr/bin/env bash
set -euo pipefail
# Fetch AIRMET+SIGMET separately and merge to one GeoJSON cache.
# - Treat zero-byte cache as stale
# - Only replace cache if payload looks valid

CACHE="/tmp/airsigmets.json"
AGE_LIMIT=300   # seconds

# Consider cache stale if missing, too old, or zero bytes
fresh_cache=false
if [ -f "$CACHE" ] && [ -s "$CACHE" ] && [ $(( $(date +%s) - $(stat -c %Y "$CACHE") )) -lt "$AGE_LIMIT" ]; then
  fresh_cache=true
fi
$fresh_cache && exit 0

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

AIRMET_URLS=(
  "https://www.aviationweather.gov/data/cache/airmets.json"
  "https://www.aviationweather.gov/api/data/airmet?format=geojson"
)
SIGMET_URLS=(
  "https://www.aviationweather.gov/data/cache/sigmets.json"
  "https://www.aviationweather.gov/api/data/sigmet?format=geojson"
)

fetch_one() {
  local out="$1"; shift
  for u in "$@"; do
    if curl -fsSL -A "curl/airsig" "$u" -o "$out"; then
      if [ -s "$out" ] && grep -q '"features"' "$out"; then
        return 0
      fi
    fi
  done
  return 1
}

AIR="$TMPDIR/air.json"
SIG="$TMPDIR/sig.json"
fetch_one "$AIR" "${AIRMET_URLS[@]}" || true
fetch_one "$SIG" "${SIGMET_URLS[@]}" || true

# If neither fetched, abort (leave old cache if any)
if [ ! -s "$AIR" ] && [ ! -s "$SIG" ]; then
  exit 0
fi

# Normalize missing into empty FeatureCollections
[ -s "$AIR" ] || printf '{"type":"FeatureCollection","features":[]}\n' > "$AIR"
[ -s "$SIG" ] || printf '{"type":"FeatureCollection","features":[]}\n' > "$SIG"

MERGED="$TMPDIR/merged.json"
if jq -c --slurp '
  def fc(x): if x.type=="FeatureCollection" then x.features else [] end;
  { type: "FeatureCollection", features: ( fc(.[0]) + fc(.[1]) ) }
' "$AIR" "$SIG" > "$MERGED"; then
  mv "$MERGED" "$CACHE"
fi



