#!/bin/bash

# RedNotebook GitHub Backup Script (Using Reusable Git Functions)
# This script backs up RedNotebook data to a GitHub repository using git's incremental tracking

set -euo pipefail

# Source the git utilities
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "/home/madhur/scripts/git-utils.sh"

# Configuration
REDNOTEBOOK_DATA_DIR="$HOME/.rednotebook/data"
BACKUP_REPO_DIR="$HOME/rednotebook-backup"
GITHUB_REPO_URL="git@github.com:madhur/rednotebook-backup.git" # Update this
LOG_FILE="$HOME/.local/share/rednotebook-backup.log"

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to handle errors
handle_error() {
    log_message "ERROR: $1"
    exit 1
}

# Function to check network connectivity
check_connectivity() {
    if ! ping -c 1 -W 5 github.com >/dev/null 2>&1; then
        log_message "WARNING: No network connectivity to GitHub, skipping backup"
        exit 0
    fi
}

# Check if RedNotebook data directory exists
if [ ! -d "$REDNOTEBOOK_DATA_DIR" ]; then
    handle_error "RedNotebook data directory not found: $REDNOTEBOOK_DATA_DIR"
fi

# Check network connectivity
check_connectivity

log_message "Starting RedNotebook incremental backup process"

# Setup repository (clone if needed, or verify existing)
git_setup_repo "$GITHUB_REPO_URL" "$BACKUP_REPO_DIR"

# Navigate to backup directory
cd "$BACKUP_REPO_DIR" || handle_error "Failed to change to backup directory"

# FIXED: Prepare git repo (clean any uncommitted changes) BEFORE syncing new data
git_prepare_repo


# Create .gitignore if it doesn't exist to avoid backing up unnecessary files
if [ ! -f .gitignore ]; then
    cat > .gitignore << 'EOF'
# Backup script logs
*.log
.DS_Store
Thumbs.db

# Temporary files
*.tmp
*.temp
*~
EOF
    log_message "Created .gitignore file"
fi

# Sync RedNotebook data using rsync for efficiency
log_message "Syncing RedNotebook data (incremental)"
rsync -av --delete --exclude='*.log' --exclude='.git' --exclude='.gitignore' --exclude='backup_info.txt' "$REDNOTEBOOK_DATA_DIR/" . || handle_error "Failed to sync RedNotebook data"

# Create/update backup metadata
cat > backup_info.txt << EOF
Last backup: $(date)
Hostname: $(hostname)
User: $(whoami)
RedNotebook data source: $REDNOTEBOOK_DATA_DIR
Script version: Incremental v1.0 (with reusable git functions)
EOF

# Use the reusable git function to add, commit, and push
COMMIT_MSG="RedNotebook backup $(date '+%Y-%m-%d %H:%M:%S')"
git_add_commit_push "$COMMIT_MSG"

# Log repository statistics
REPO_STATS=$(get_repo_stats)
log_message "$REPO_STATS"

log_message "RedNotebook incremental backup process completed"