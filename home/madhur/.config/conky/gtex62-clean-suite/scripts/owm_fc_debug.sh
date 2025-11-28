#!/usr/bin/env bash
set -e
J="$HOME/.cache/conky/owm_forecast.json"
echo "Chosen codes (one per day):"
jq -r '
  .list
  | group_by(.dt | strftime("%Y-%m-%d"))
  | map(select((.[0].dt | strftime("%Y-%m-%d")) != (now | strftime("%Y-%m-%d"))))
  | .[:5]
  | map(
      ( [ .[] | {icon:.weather[0].icon, hour:(.dt | strftime("%H") | tonumber)} ] ) as $arr
      | ( [ $arr[] | select(.hour >= 10 and .hour <= 16) | .icon ] ) as $day
      | ( if ($day|length) > 0
          then ($day | group_by(.) | max_by(length)[0])
          else ($arr[0].icon)
        end )
    )
  | @tsv
' "$J"
echo "---- THEME (code PNGs in ~/.config/conky/gtex62-clean-suite/icons/owm):"
ls -l "$HOME/.config/conky/gtex62-clean-suite/icons/owm" | head -n 20 || true
echo "---- FC files (cache in ~/.cache/conky/icons):"
ls -l "$HOME/.cache/conky/icons"/fc*.png 2>/dev/null || echo "(no fc*.png)"
