#!/usr/bin/env bash
set -euo pipefail

CONF_DIR="$HOME/.config/conky/gtex62-clean-suite"
CACHE_DIR="$HOME/.cache/conky"
ENV_FILE="$CONF_DIR/widgets/owm.env"
VARS_FILE="$CONF_DIR/widgets/owm.vars"
CACHE_JSON="$CACHE_DIR/owm_current.json"
TMP_JSON="$CACHE_DIR/.owm_current.tmp"
LOG_FILE="$CACHE_DIR/owm_fetch.log"
ICON_DIR="$CACHE_DIR/icons"

# Load API key + vars
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi
if [[ -f "$VARS_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$VARS_FILE"
fi

: "${OWM_API_KEY:?OWM_API_KEY missing (set in $ENV_FILE)}"
: "${LAT:?LAT missing (set in $VARS_FILE)}"
: "${LON:?LON missing (set in $VARS_FILE)}"
UNITS="${UNITS:-imperial}"
LANG="${LANG:-en}"
CACHE_TTL="${CACHE_TTL:-300}"

mkdir -p "$CACHE_DIR" "$ICON_DIR"

now_epoch() { date +%s; }

is_cache_fresh() {
  [[ -f "$CACHE_JSON" ]] || return 1
  local stat_cmd
  if stat --help 2>&1 | grep -qi 'GNU'; then
    stat_cmd="stat -c %Y"
  else
    stat_cmd="stat -f %m"
  fi
  local age=$(( $(now_epoch) - $($stat_cmd "$CACHE_JSON") ))
  [[ $age -lt $CACHE_TTL ]]
}

URL="https://api.openweathermap.org/data/2.5/weather?lat=${LAT}&lon=${LON}&units=${UNITS}&lang=${LANG}&appid=${OWM_API_KEY}"

# If cache is fresh, skip fetch
if is_cache_fresh; then
  exit 0
fi

fetch() { curl -fsS --max-time 6 "$URL" || return 1; }

if ! fetch > "$TMP_JSON" 2>>"$LOG_FILE"; then
  sleep 2
  if ! fetch > "$TMP_JSON" 2>>"$LOG_FILE"; then
    echo "$(date -Is) WARN: fetch failed; keeping old cache if present" >> "$LOG_FILE"
    rm -f "$TMP_JSON"
    exit 0
  fi
fi

# Basic validation
if ! grep -q '"weather"' "$TMP_JSON"; then
  echo "$(date -Is) WARN: response missing 'weather'; keeping old cache" >> "$LOG_FILE"
  rm -f "$TMP_JSON"
  exit 0
fi

# Move JSON into place
mv -f "$TMP_JSON" "$CACHE_JSON"

# --- Cache the icon ---
icon_code="$(jq -r '.weather[0].icon // empty' "$CACHE_JSON" 2>/dev/null || true)"
if [[ -n "$icon_code" ]]; then
  icon_path="$ICON_DIR/${icon_code}.png"
  # current_path="$ICON_DIR/current.png"
  need_dl=0
  if [[ ! -f "$icon_path" ]]; then
    need_dl=1
  else
    if [[ "$icon_path" -ot "$CACHE_JSON" ]]; then
      need_dl=1
    fi
  fi
  if [[ $need_dl -eq 1 ]]; then
    icon_url="https://openweathermap.org/img/wn/${icon_code}@2x.png"
    if ! curl -fsS --max-time 6 -o "$icon_path" "$icon_url" 2>>"$LOG_FILE"; then
      echo "$(date -Is) WARN: icon download failed ($icon_code)" >> "$LOG_FILE"
    fi
  fi
  # Always refresh the current.png pointer (copy is safest for Conky)
  # cp -f "$icon_path" "$current_path" 2>>"$LOG_FILE" || true
fi

# --- Cache the 5-day /forecast JSON (3-hour steps) ---
FC_JSON="$CACHE_DIR/owm_forecast.json"
FC_TMP="$CACHE_DIR/.owm_forecast.tmp"
FC_URL="https://api.openweathermap.org/data/2.5/forecast?lat=${LAT}&lon=${LON}&units=${UNITS}&lang=${LANG}&appid=${OWM_API_KEY}"

fetch_fc() { curl -fsS --max-time 8 "$FC_URL" || return 1; }

# Only refresh forecast if missing or older than main current JSON
need_fc=1
if [[ -f "$FC_JSON" ]]; then
  if [[ "$FC_JSON" -nt "$CACHE_JSON" ]]; then
    need_fc=0
  fi
fi

if [[ $need_fc -eq 1 ]]; then
  if ! fetch_fc > "$FC_TMP" 2>>"$LOG_FILE"; then
    sleep 2
    if ! fetch_fc > "$FC_TMP" 2>>"$LOG_FILE"; then
      echo "$(date -Is) WARN: forecast fetch failed; keeping old FC cache" >> "$LOG_FILE"
      rm -f "$FC_TMP"
    fi
  fi
  if [[ -f "$FC_TMP" ]]; then
    if grep -q '"list"' "$FC_TMP"; then
      mv -f "$FC_TMP" "$FC_JSON"
    else
      echo "$(date -Is) WARN: forecast response missing 'list'; keeping old FC cache" >> "$LOG_FILE"
      rm -f "$FC_TMP"
    fi
  fi
fi

exit 0

