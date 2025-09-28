#!/bin/bash

# Set the script to exit immediately if any command fails
set -e

DATE=$(date +%Y-%m-%d)
BACKUP_DIR=~/backups/vaultwarden
BACKUP_FILE=vaultwarden-$DATE.tar.gz
CONTAINER=vaultwarden
CONTAINER_DATA_DIR=/home/madhur/docker/vaultwarden/vw-data

# create backups directory if it does not exist
mkdir -p $BACKUP_DIR

# Stop the container
/usr/bin/docker stop $CONTAINER

# Backup the vaultwarden data directory to the backup directory
tar -czf "$BACKUP_DIR/$BACKUP_FILE" -C "$CONTAINER_DATA_DIR" .

# Restart the container
/usr/bin/docker restart $CONTAINER

# To delete files older than 30 days
find $BACKUP_DIR/* -mtime +30 -exec rm {} \;