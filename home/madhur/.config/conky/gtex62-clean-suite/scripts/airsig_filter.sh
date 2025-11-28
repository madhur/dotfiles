#!/usr/bin/env bash
set -euo pipefail
# airsig_filter.sh <STATION> <RADIUS_NM>
# Prints TSV rows for advisories within RADIUS_NM of STATION:
# kind  phen  region  zone  validFrom  validTo

STATION="$(echo "${1:-KMEM}" | tr '[:lower:]' '[:upper:]')"
RADIUS_NM="${2:-300}"

# Station lat/lon (decimal degrees)
read LAT LON <<<"$(~/.config/conky/gtex62-clean-suite/scripts/station_latlon.sh "$STATION" 2>/dev/null || echo "")"
[ -n "${LAT:-}" ] && [ -n "${LON:-}" ] || exit 0

# Ensure we have a fresh-ish cache
~/.config/conky/gtex62-clean-suite/scripts/airsig_fetch.sh >/dev/null 2>&1 || true
CACHE="/tmp/airsigmets.json"
[ -s "$CACHE" ] || exit 0

# Extract scalar fields only; compute centroid (lat,lon) as two separate scalars
jq -r '
  def flat(x): (if (x|type)=="array" then (x|join("/")) else x end);

  .features[]
  | .properties as $p
  | ( .geometry
      | if .type=="Polygon" then .coordinates[0]
        elif .type=="MultiPolygon" then .coordinates[0][0]
        elif .type=="LineString" then .coordinates
        else empty end
    ) as $pts
  | ($pts
     | reduce .[] as $c ([0,0,0]; [.[0]+($c[1]), .[1]+($c[0]), .[2]+1])
     | {lat: (.[0]/.[2]), lon: (.[1]/.[2])}
    ) as $cent
  | [
      flat($p.type // $p.advisoryType // "ADVISORY"),
      flat($p.phenomenon // $p.hazard // ""),
      flat($p.region // ""),
      flat($p.zone // ""),
      flat($p.validTimeFrom // $p.validFrom // ""),
      flat($p.validTimeTo   // $p.validTo   // ""),
      ($cent.lat|tostring),
      ($cent.lon|tostring)
    ]
  | @tsv
' "$CACHE" \
| awk -v slat="$LAT" -v slon="$LON" -v rnm="$RADIUS_NM" -F'\t' '
function rad(x){ return x*3.141592653589793/180 }
function haversine_nm(lat1,lon1,lat2,lon2,   R, dlat, dlon, a, c) {
  R=3440.065
  dlat=rad(lat2-lat1)
  dlon=rad(lon2-lon1)
  a=sin(dlat/2)^2 + cos(rad(lat1))*cos(rad(lat2))*sin(dlon/2)^2
  c=2*atan2(sqrt(a), sqrt(1-a))
  return R*c
}
{
  kind=$1; phen=$2; region=$3; zone=$4; from=$5; to=$6; clat=$7+0; clon=$8+0
  if (clat==0 && clon==0) next
  d = haversine_nm(slat, slon, clat, clon)
  if (d <= rnm) {
    printf "%s\t%s\t%s\t%s\t%s\t%s\n", kind, phen, region, zone, from, to
  }
}'
