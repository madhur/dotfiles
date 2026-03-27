#!/bin/bash
# Docker Private Backup Script
# Backs up docker secrets, configs, and DB dumps to a private GitHub repo

set -euo pipefail

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "$SCRIPT_DIR/git-utils.sh"

DOCKER_DIR="$HOME/docker"
PRIVATE_BACKUP_DIR="$HOME/docker-private"
GITHUB_REPO_URL="git@github.com:madhur/docker-private.git"
LOG_FILE="$HOME/.local/share/docker-private-backup.log"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

handle_error() {
    log_message "ERROR: $1"
    exit 1
}

# Check network connectivity
if ! ping -c 1 -W 5 github.com >/dev/null 2>&1; then
    log_message "WARNING: No network connectivity to GitHub, skipping backup"
    exit 0
fi

log_message "Starting docker private backup"

# Clone repo on first run, otherwise verify existing
if [ ! -d "$PRIVATE_BACKUP_DIR/.git" ]; then
    log_message "Cloning repository for first time"
    git clone "$GITHUB_REPO_URL" "$PRIVATE_BACKUP_DIR" || handle_error "Failed to clone repository"
else
    log_message "Using existing repository: $PRIVATE_BACKUP_DIR"
fi

cd "$PRIVATE_BACKUP_DIR" || handle_error "Failed to cd to $PRIVATE_BACKUP_DIR"

# Sync files from docker dir, excluding large data/db directories
# Note: do NOT use --delete-excluded (it would delete .git/ from destination)
log_message "Syncing files from $DOCKER_DIR"
# Use && ... || to capture rsync exit code safely under set -e
# Exit 23/24 = partial transfer (acceptable, e.g. permission denied on root-owned docker files)
rsync -av --delete \
    --exclude='.git/' \
    --exclude='archive/' \
    --exclude='rednotebook/' \
    --exclude='*/temp_upload/' \
    --exclude='*/data/' \
    --exclude='*pgdata*' \
    --exclude='*postgres*' \
    --exclude='*mongo*' \
    --exclude='*/media/' \
    --exclude='*/cache/' \
    --exclude='*/logs/' \
    --exclude='*/log/' \
    --exclude='*/storage/' \
    --exclude='*/es_data/' \
    --exclude='*/kafka/' \
    --exclude='*/rabbitmq/' \
    --exclude='*/cassandra/' \
    --exclude='*/sessions/' \
    --exclude='*/framework/views/' \
    --exclude='*/framework/cache/' \
    --exclude='komodo/db/' \
    --exclude='bookstack_db_data/' \
    --exclude='.gitignore' \
    --exclude='sterlingpdf/StirlingPDF/trainingData/' \
    --exclude='sterlingpdf/StirlingPDF/extraConfigs/backup/keys/' \
    --exclude='paperless/' \
    --exclude='qbittorrent/gluetun/servers.json' \
    --exclude='vaultwarden/vw-data/icon_cache/' \
    --exclude='homeassistant/config/' \
    --exclude='jellyfin/config/' \
    "$DOCKER_DIR/" \
    "$PRIVATE_BACKUP_DIR/" && RSYNC_EXIT=0 || RSYNC_EXIT=$?
if [ $RSYNC_EXIT -ne 0 ] && [ $RSYNC_EXIT -ne 23 ] && [ $RSYNC_EXIT -ne 24 ]; then
    handle_error "rsync failed with exit code $RSYNC_EXIT"
fi
log_message "rsync completed (exit code: $RSYNC_EXIT)"

# Always write the private .gitignore (overrides the public one copied by rsync)
# This must allow .env files — unlike the public repo's .gitignore which blocks them
cat > .gitignore << 'EOF'
# Large data and database directories - never backup these
**/data/
**/pgdata/
**/*postgres*/
**/*mongo*/
**/media/
**/cache/
**/logs/
**/log/
**/storage/
**/es_data/
**/kafka/
**/rabbitmq/
**/cassandra/
**/sessions/
**/framework/cache/
**/framework/views/
komodo/db/
bookstack_db_data/
homeassistant/config/
jellyfin/config/
sterlingpdf/StirlingPDF/trainingData/
sterlingpdf/StirlingPDF/extraConfigs/backup/keys/
**/consume/
qbittorrent/gluetun/servers.json
vaultwarden/vw-data/icon_cache/
EOF
log_message "Wrote private .gitignore"

# --- Database dumps ---

dump_pg_host() {
    local db="$1" user="$2" pass="$3" outdir="$4"
    mkdir -p "$PRIVATE_BACKUP_DIR/$outdir"
    PGPASSWORD="$pass" pg_dump -h localhost -p 5432 -U "$user" "$db" \
        > "$PRIVATE_BACKUP_DIR/$outdir/${db}_dump.sql" \
        && log_message "Dumped postgres DB: $db" \
        || log_message "WARNING: pg_dump failed for $db (DB may be down)"
}

dump_pg_container() {
    local container="$1" db="$2" user="$3" outdir="$4"
    mkdir -p "$PRIVATE_BACKUP_DIR/$outdir"
    docker exec "$container" pg_dump -U "$user" "$db" \
        > "$PRIVATE_BACKUP_DIR/$outdir/${db}_dump.sql" \
        && log_message "Dumped postgres DB: $db (via $container)" \
        || log_message "WARNING: pg_dump failed for $db via $container (container may be stopped)"
}

# Host postgres databases (localhost:5432) — credentials from each service's .env
AUTHENTIK_PW=$(grep 'AUTHENTIK_POSTGRESQL__PASSWORD' "$DOCKER_DIR/authentik/.env" | cut -d= -f2)
dump_pg_host "authentik" "authentik" "$AUTHENTIK_PW" "authentik"

dump_pg_host "dawarich" "dawarich" "dawarich" "dawarich"

# Paperless: media (actual PDFs) not backed up — DB alone is useless. Skip.
# Gitea: git repos in ./data/ not backed up — DB metadata without repos is useless. Skip.

# BookStack: MariaDB via docker exec (binary db_data excluded, SQL dump instead)
mkdir -p "$PRIVATE_BACKUP_DIR/bookstack"
docker exec bookstack_db mysqldump -u bookstack -psupersecretpassword bookstackapp \
    > "$PRIVATE_BACKUP_DIR/bookstack/bookstackapp_dump.sql" \
    && log_message "Dumped BookStack MariaDB" \
    || log_message "WARNING: BookStack DB dump failed (container may be stopped)"

# Docmost: own postgres container
dump_pg_container "docmost_db" "docmost" "docmost" "docmost"

# --- Commit and push ---
COMMIT_MSG="Docker private backup $(date '+%Y-%m-%d %H:%M:%S')"

# Stage all changes
git add -A

# Check if there are changes to commit
if git diff --staged --quiet; then
    log_message "No changes to commit"
else
    git commit -m "$COMMIT_MSG"
    log_message "Committed: $COMMIT_MSG"
fi

# Push — handle first push to empty remote (no upstream branch yet)
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "main")
if git ls-remote --heads origin "$CURRENT_BRANCH" | grep -q .; then
    git push
else
    log_message "First push — setting upstream branch: $CURRENT_BRANCH"
    git push -u origin "$CURRENT_BRANCH"
fi

log_message "Docker private backup completed"
log_message "$(get_repo_stats)"
