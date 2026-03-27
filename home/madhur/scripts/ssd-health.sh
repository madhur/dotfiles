#!/usr/bin/env bash
# ssd-health.sh — Display SMART health for all SSDs in a table

RED='\033[0;31m'
YEL='\033[0;33m'
GRN='\033[0;32m'
BLD='\033[1m'
RST='\033[0m'

if ! command -v smartctl &>/dev/null; then
    echo "Error: smartctl not found. Install smartmontools." >&2
    exit 1
fi

# Collect all real (non-loop) block devices
mapfile -t DEVICES < <(lsblk -d -o NAME,TYPE | awk '$2=="disk"{print "/dev/"$1}')

# Header
printf "\n${BLD}%-12s %-28s %-8s %-10s %-8s %-8s %-8s %-6s${RST}\n" \
    "Device" "Model" "Status" "Hours" "Wear%" "TBW" "Temp°C" "Errors"
printf '%s\n' "$(printf '%.0s─' {1..96})"

for DEV in "${DEVICES[@]}"; do
    RAW=$(sudo smartctl -H -A -i "$DEV" 2>/dev/null)
    [[ -z "$RAW" ]] && continue

    MODEL=$(echo "$RAW" | grep -E "^(Device Model|Model Number)" | head -1 | sed 's/.*:[ \t]*//' | cut -c1-27)
    [[ -z "$MODEL" ]] && MODEL=$(echo "$RAW" | grep -E "^Model Family" | head -1 | sed 's/.*:[ \t]*//' | cut -c1-27)
    [[ -z "$MODEL" ]] && MODEL="Unknown"

    STATUS_RAW=$(echo "$RAW" | grep "overall-health\|result:" | grep -oE "PASSED|FAILED|UNKNOWN")
    if [[ "$STATUS_RAW" == "PASSED" ]]; then
        STATUS="${GRN}PASSED${RST}"
    elif [[ "$STATUS_RAW" == "FAILED" ]]; then
        STATUS="${RED}FAILED${RST}"
    else
        STATUS="${YEL}UNKNOWN${RST}"
    fi

    # ── NVMe ──────────────────────────────────────────────────
    if echo "$RAW" | grep -q "NVMe Log\|Percentage Used"; then
        HOURS=$(echo "$RAW" | grep "Power On Hours" | awk '{print $NF}' | tr -d ',')
        PCT_USED=$(echo "$RAW" | grep "Percentage Used" | awk '{print $NF}' | tr -d '%')
        WEAR=$((100 - ${PCT_USED:-0}))
        TEMP=$(echo "$RAW" | grep "^Temperature:" | head -1 | awk '{print $2}')
        ERRORS=$(echo "$RAW" | grep "Media and Data Integrity Errors" | awk '{print $NF}')
        # TBW from Data Units Written (each unit = 512,000 bytes)
        DUW=$(echo "$RAW" | grep "Data Units Written" | grep -oE '[0-9,]+' | head -1 | tr -d ',')
        TBW=$(awk "BEGIN{printf \"%.1f\", ${DUW:-0}*512000/1e12}")

    # ── SATA SSD ──────────────────────────────────────────────
    else
        HOURS=$(echo "$RAW" | awk '/Power_On_Hours/{print $NF}')
        WEAR=$(echo "$RAW" | awk '/Wear_Leveling_Count/{print $4}' | sed 's/^0*//')
        [[ -z "$WEAR" ]] && WEAR=0
        TEMP=$(echo "$RAW" | awk '/Airflow_Temperature_Cel/{print $NF}')
        ERRORS=$(echo "$RAW" | awk '/Uncorrectable_Error_Cnt/{print $NF}')
        # TBW from Total_LBAs_Written (each LBA = 512 bytes)
        LBW=$(echo "$RAW" | awk '/Total_LBAs_Written/{print $NF}')
        TBW=$(awk "BEGIN{printf \"%.1f\", ${LBW:-0}*512/1e12}")
    fi

    # Colour wear
    if [[ "$WEAR" =~ ^[0-9]+$ ]]; then
        if (( WEAR >= 80 )); then
            WEAR_COL="${GRN}${WEAR}${RST}"
        elif (( WEAR >= 50 )); then
            WEAR_COL="${YEL}${WEAR}${RST}"
        else
            WEAR_COL="${RED}${WEAR}${RST}"
        fi
    else
        WEAR_COL="$WEAR"
    fi

    # Colour temperature
    if [[ "$TEMP" =~ ^[0-9]+$ ]]; then
        if (( TEMP >= 70 )); then
            TEMP_COL="${RED}${TEMP}${RST}"
        elif (( TEMP >= 60 )); then
            TEMP_COL="${YEL}${TEMP}${RST}"
        else
            TEMP_COL="${GRN}${TEMP}${RST}"
        fi
    else
        TEMP_COL="${TEMP:-N/A}"
    fi

    # Colour errors
    if [[ "$ERRORS" == "0" ]]; then
        ERR_COL="${GRN}0${RST}"
    else
        ERR_COL="${RED}${ERRORS}${RST}"
    fi

    printf "%-12s %-28s %-8b %-10s %-8b %-8s %-8b %-6b\n" \
        "$(basename "$DEV")" "$MODEL" "$STATUS" "${HOURS:-N/A}" \
        "$WEAR_COL" "${TBW}T" "$TEMP_COL" "$ERR_COL"
done

printf '%s\n\n' "$(printf '%.0s─' {1..96})"
echo -e "  ${BLD}Wear%${RST}: remaining lifespan   ${BLD}TBW${RST}: total bytes written   ${BLD}Errors${RST}: media/uncorrectable errors"
echo -e "  Temp: ${GRN}■${RST} <60°C  ${YEL}■${RST} 60-69°C  ${RED}■${RST} ≥70°C\n"
