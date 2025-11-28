#!/usr/bin/env bash
set -euo pipefail
CUR_JSON="${1:-$HOME/.cache/conky/owm_current.json}"
THEME_DIR="${2:-$HOME/.config/conky/gtex62-clean-suite/icons/owm}"
OUTPNG="$HOME/.cache/conky/icons/current.png"

code="$(jq -r '.weather[0].icon // empty' "$CUR_JSON" 2>/dev/null || true)"
# --- Daylight override based on cloud cover (when no precip) ---
now=$(date +%s)
sr=$(jq -r '.sys.sunrise // 0' "$CUR_JSON" 2>/dev/null)
ss=$(jq -r '.sys.sunset  // 0' "$CUR_JSON" 2>/dev/null)
clouds=$(jq -r '.clouds.all // empty' "$CUR_JSON" 2>/dev/null || true)
rain1=$(jq -r '.rain["1h"] // 0' "$CUR_JSON" 2>/dev/null)
snow1=$(jq -r '.snow["1h"] // 0' "$CUR_JSON" 2>/dev/null)

if [[ -n "$clouds" ]] && [[ "$rain1" == "0" && "$snow1" == "0" ]] && [[ "$now" -ge "$sr" && "$now" -le "$ss" ]]; then
  c=${clouds%.*}  # integer
  if   (( c <= 15 )); then code="01d"   # clear
  elif (( c <= 40 )); then code="02d"   # few clouds
  elif (( c <= 70 )); then code="03d"   # scattered
  else                    code="04d"   # broken/overcast
  fi
fi

[[ -z "$code" ]] && exit 0

src="$THEME_DIR/${code}.png"
# If your pack is missing a specific code, optionally fall back to day variant:
[[ -f "$src" ]] || src="$THEME_DIR/$(printf '%s' "$code" | sed 's/n$/d/')"
# Final safety: if still missing, try OWM CDN once
# if [[ ! -f "$src" ]]; then
#   mkdir -p "$THEME_DIR"
#   curl -fsSL "https://openweathermap.org/img/wn/${code}@2x.png" -o "$THEME_DIR/${code}.png" || true
#   src="$THEME_DIR/${code}.png"
# fi

[[ -f "$src" ]] && cp -f "$src" "$OUTPNG"
