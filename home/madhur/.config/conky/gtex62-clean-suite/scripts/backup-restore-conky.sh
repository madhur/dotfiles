#!/usr/bin/env bash
# Backup/restore your Conky setup in one file.
# Usage:
#   backup-restore-conky.sh backup
#   backup-restore-conky.sh restore <file>
#   $HOME/.config/conky/gtex62-clean-suite/scripts/backup-restore-conky.sh backup
#
# Behavior:
# - Backup prefers DEST dir /mnt/NAS_Data/Data/Linux/backups if it exists & is writable.
# - Otherwise backs up to $HOME as conky_<host>_<YYYYmmdd-HHMM>.tar.gz
# - Includes .vscode (Lua stubs/settings), scripts, *.conky.conf, *.lua, autostart desktop.
# - Excludes caches and logs.
set -euo pipefail
IFS=$'\n\t'

SRC="$HOME/.config/conky/gtex62-clean-suite"
HOST="$(hostname -s || echo host)"
STAMP="$(date +%Y%m%d-%H%M)"

# Choose default destination directory
DEFAULT_DEST_DIR="$HOME"
if [ -d "/mnt/NAS_Data/Data/Linux/backups" ] && [ -w "/mnt/NAS_Data/Data/Linux/backups" ]; then
  DEFAULT_DEST_DIR="/mnt/NAS_Data/Data/Linux/backups"
fi

DEST="${DEFAULT_DEST_DIR}/conky_${HOST}_${STAMP}.tar.gz"

must() { command -v "$1" >/dev/null 2>&1 || { echo "Missing: $1" >&2; exit 1; }; }

backup() {
  must tar
  [ -d "$SRC" ] || { echo "Conky source not found: $SRC" >&2; exit 1; }

  mkdir -p "$DEFAULT_DEST_DIR"

  echo "Backing up Conky from: $SRC"
  echo "Destination archive:   $DEST"

  # Build archive from $HOME so paths restore correctly
  tar -czf "$DEST" \
    --exclude='*.log' \
    --exclude='.cache' \
    --exclude='*/.cache/*' \
    --warning=no-file-changed \
    -C "$HOME" \
    ".config/conky/gtex62-clean-suite/" \
    ".config/autostart/start-conky.desktop" 2>/dev/null || true

  echo "Backup created: $DEST"
}

restore() {
  must tar
  local src="${1:-}"
  [ -f "$src" ] || { echo "Restore file not found: $src" >&2; exit 1; }

  # Safety copy of current config (if present)
  if [ -d "$SRC" ]; then
    local safe="$HOME/.config/conky.safe.${STAMP}"
    cp -a "$SRC" "$safe"
    echo "Safety copy saved to: $safe"
  fi

  echo "Restoring from: $src"
  tar -xzf "$src" -C "$HOME"

  # Re-apply execute bits for scripts
  chmod +x "$SRC"/*.sh 2>/dev/null || true
  chmod +x "$SRC"/scripts/*.sh 2>/dev/null || true

  echo "Restored files into: $SRC"
}

case "${1:-}" in
  backup)  backup ;;
  restore) restore "${2:-}" ;;
  *) echo "Usage: $0 {backup|restore <tar.gz>}" >&2; exit 1 ;;
esac
