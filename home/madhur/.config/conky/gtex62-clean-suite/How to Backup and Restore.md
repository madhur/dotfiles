# How to Backup and Restore

This guide explains how to use the `backup-restore-conky.sh` script to back up and restore your **gtex62-clean-suite** Conky setup, and how to customize the directories the script uses.

> Works on Linux Mint/Ubuntu (Bash). The script intentionally fails fast on errors and prints what it’s doing.

---

## What the script does

- **Backs up** your Conky suite into a single `tar.gz` archive named like:  
  `conky_<HOST>_<YYYYmmdd-HHMM>.tar.gz`
- **Prefers** to save the archive in `/mnt/NAS_Data/Data/Linux/backups` **if present and writable**, otherwise falls back to your home directory.
- **Includes**:
  - `.config/conky/gtex62-clean-suite/` (all `.conky.conf`, `.lua`, `scripts/`, `.vscode/`, etc.)
  - `~/.config/autostart/start-conky.desktop`
- **Excludes** common cache/log content (`*.log`, `.cache/*`).
- **Restores** files back into the original locations under your home folder.
- **Safety copy**: Before restore, it copies the current suite to `~/.config/conky.safe.<STAMP>` if it exists.
- **Fixes execute permissions** on `*.sh` in the suite root and `scripts/` after restore.

---

## Script (reference)

The guide assumes you have this script saved as:
```
~/.config/conky/gtex62-clean-suite/scripts/backup-restore-conky.sh
```
and made executable:
```bash
chmod +x ~/.config/conky/gtex62-clean-suite/scripts/backup-restore-conky.sh
```

> If your script lives elsewhere, just adjust the paths below.

---

## Prerequisites

- `tar` must be available (it is on most distros). The script checks for it.
- Ensure your Conky suite is in `~/.config/conky/gtex62-clean-suite/` (or update `SRC` if different).
- If you want to use a NAS destination, make sure it’s mounted and **writable**.

---

## Quick usage

### Backup
```bash
~/.config/conky/gtex62-clean-suite/scripts/backup-restore-conky.sh backup
```
- The script prints:
  - the **source** directory it’s backing up
  - the **destination archive** (full path)

The resulting file will be created at either:
- `/mnt/NAS_Data/Data/Linux/backups/conky_<HOST>_<STAMP>.tar.gz` (preferred if available)
- `~/conky_<HOST>_<STAMP>.tar.gz` (fallback)

> **Verify**: You can list the archive contents with:
```bash
tar -tzf /path/to/conky_<HOST>_<STAMP>.tar.gz | head
```

### Restore
```bash
~/.config/conky/gtex62-clean-suite/scripts/backup-restore-conky.sh restore /path/to/conky_<HOST>_<STAMP>.tar.gz
```
What happens:
1. If `~/.config/conky/gtex62-clean-suite/` exists, it’s copied to `~/.config/conky.safe.<STAMP>`.
2. The archive is extracted **into your home folder**, restoring to:
   - `~/.config/conky/gtex62-clean-suite/`
   - `~/.config/autostart/start-conky.desktop`
3. Execute bits are re-applied to `*.sh` under the suite root and `scripts/`.

> **Tip**: After restore, restart Conky or your session to reload the autostart file if needed.

---

## How to customize directories

You may want to change:
- The **source** of your suite (if you renamed or reorganized)
- The **default destination** for backups (e.g., different NAS path)
- The **autostart** desktop file location/name

Below are the critical variables inside the script and how to safely modify them.

### 1) `SRC` — where to back up from (suite root)

**Current:**
```bash
SRC="$HOME/.config/conky/gtex62-clean-suite"
```

**Change it if:**
- You renamed the suite folder, e.g. `my-conky-suite`
- You keep it elsewhere

**Example changes:**
```bash
# Example: different suite name
SRC="$HOME/.config/conky/my-conky-suite"

# Example: different base path entirely
SRC="$HOME/dev/dotfiles/conky/gtex62-clean-suite"
```

> Ensure the path exists before running `backup` or `restore`.

### 2) Preferred NAS/archive destination

The script tries a preferred directory first, then falls back to `$HOME`.

**Current:**
```bash
DEFAULT_DEST_DIR="$HOME"
if [ -d "/mnt/NAS_Data/Data/Linux/backups" ] && [ -w "/mnt/NAS_Data/Data/Linux/backups" ]; then
  DEFAULT_DEST_DIR="/mnt/NAS_Data/Data/Linux/backups"
fi
DEST="${DEFAULT_DEST_DIR}/conky_${HOST}_${STAMP}.tar.gz"
```

**Change it if:**
- Your NAS path differs
- You want to always save locally
- You’d like a different local folder (e.g., `~/Backups/Conky`)

**Examples:**
```bash
# Always save to a custom local folder
DEFAULT_DEST_DIR="$HOME/Backups/Conky"

# Prefer a different NAS path when available
if [ -d "/mnt/NAS_Data/Backups/Conky" ] && [ -w "/mnt/NAS_Data/Backups/Conky" ]; then
  DEFAULT_DEST_DIR="/mnt/NAS_Data/Backups/Conky"
fi
```

> The script will `mkdir -p "$DEFAULT_DEST_DIR"` before writing the archive.

### 3) Autostart .desktop file location (optional)

The backup command includes this file explicitly:
```bash
tar -czf "$DEST" \
  ... \
  -C "$HOME" \
  ".config/conky/gtex62-clean-suite/" \
  ".config/autostart/start-conky.desktop"
```

**Change it if:**
- Your autostart file has a different name or location.
- You want to include **additional** files.

**Examples:**
```bash
# Different autostart file name
  ".config/autostart/conky-suite.desktop"

# Include an extra config subtree
  ".config/conky/extra-theme/"
```

> Keep the `-C "$HOME"` design so all paths are **relative to your $HOME**; this makes restores land correctly.

---

## Advanced: include/exclude patterns

The script already excludes logs and caches:
```bash
--exclude='*.log' \
--exclude='.cache' \
--exclude='*/.cache/*' \
```

**Add more excludes** (examples):
```bash
--exclude='*.tmp' \
--exclude='*.bak' \
--exclude='.git' \
```

**Add more includes** by appending relative paths after `-C "$HOME"`:
```bash
-C "$HOME" \
".config/conky/gtex62-clean-suite/" \
".config/autostart/start-conky.desktop" \
"Documents/Conky-Notes/" \
```

> Paths after `-C "$HOME"` must be **relative to your home folder**.

---

## Troubleshooting

- **“Conky source not found”**  
  Check that `SRC` points to a real folder:  
  ```bash
  ls -la "$HOME/.config/conky/gtex62-clean-suite"
  ```

- **Missing `tar`** (rare)  
  Install it:
  ```bash
  sudo apt update && sudo apt install -y tar
  ```

- **NAS not writable / not mounted**  
  The script will fall back to `~`. Verify mounts:
  ```bash
  mount | grep -i nas
  ls -ld /mnt/NAS_Data/Data/Linux/backups
  ```

- **Permissions after restore**  
  The script re-applies execute bits to `*.sh`. If you add new script locations, set them manually:
  ```bash
  chmod +x ~/.config/conky/gtex62-clean-suite/*.sh
  chmod +x ~/.config/conky/gtex62-clean-suite/scripts/*.sh
  ```

- **Dry-run (what would be archived?)**  
  You can simulate the file list with:
  ```bash
  tar -czf - --exclude='*.log' --exclude='.cache' --exclude='*/.cache/*' -C "$HOME" \
    ".config/conky/gtex62-clean-suite/" ".config/autostart/start-conky.desktop" \
  | tar -tzf - | less
  ```

---

## Common recipes

- **Change suite name everywhere** (from `gtex62-clean-suite` → `my-suite`):  
  1) Update `SRC` to point to `~/.config/conky/my-suite`  
  2) In the `tar` include list, change the included path:  
     ```bash
     ".config/conky/my-suite/"
     ```
  3) Autostart entry (if renamed):
     ```bash
     ".config/autostart/my-suite.desktop"
     ```

- **Force a custom archive file name**:
  ```bash
  DEST="$HOME/Backups/Conky/my-pretty-name.tar.gz"
  ```

- **Back up to an external drive** (mounted at `/media/$USER/Backup`):
  ```bash
  DEFAULT_DEST_DIR="/media/$USER/Backup/Conky"
  ```

---

## Safety and rollback

During restore, the script saves a safety copy of your current suite into:
```
~/.config/conky.safe.<YYYYmmdd-HHMM>
```
If something looks wrong after you restore, you can **roll back** by copying files from that safety folder back into:
```
~/.config/conky/gtex62-clean-suite/
```

---

## Appendix: Full script for reference

> Keep this in sync with your working copy.

```bash
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
```

---

### That’s it!
You now have a simple, repeatable way to back up and restore your Conky suite, plus a clean path to customize where things live.
