#!/bin/bash

# Scout Pro - Backup Script
# Creates backups of MongoDB database and uploaded files

set -e

# Configuration
BACKUP_DIR="./backups"
DATE=$(date +%Y%m%d_%H%M%S)
MONGO_CONTAINER="scoutpro-mongo"
BACKEND_CONTAINER="scoutpro-backend"

echo "🗄️  Scout Pro Backup Script"
echo "==========================="
echo "Starting backup at: $(date)"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Check if containers are running
if ! docker ps | grep -q "$MONGO_CONTAINER"; then
    echo "❌ MongoDB container is not running"
    exit 1
fi

if ! docker ps | grep -q "$BACKEND_CONTAINER"; then
    echo "❌ Backend container is not running"
    exit 1
fi

echo "✅ Containers are running"

# Backup MongoDB
echo "💾 Backing up MongoDB database..."
MONGO_BACKUP_DIR="$BACKUP_DIR/mongodb_$DATE"
mkdir -p "$MONGO_BACKUP_DIR"

docker exec "$MONGO_CONTAINER" mongodump --out /tmp/backup
docker cp "$MONGO_CONTAINER:/tmp/backup" "$MONGO_BACKUP_DIR/"
docker exec "$MONGO_CONTAINER" rm -rf /tmp/backup

echo "✅ MongoDB backup completed: $MONGO_BACKUP_DIR"

# Backup uploaded files (spray charts)
echo "📸 Backing up uploaded files..."
UPLOADS_BACKUP_DIR="$BACKUP_DIR/uploads_$DATE"
mkdir -p "$UPLOADS_BACKUP_DIR"

docker cp "$BACKEND_CONTAINER:/app/uploads/." "$UPLOADS_BACKUP_DIR/"

echo "✅ Uploads backup completed: $UPLOADS_BACKUP_DIR"

# Create compressed archive
echo "🗜️  Creating compressed archive..."
ARCHIVE_NAME="scoutpro_backup_$DATE.tar.gz"
tar -czf "$BACKUP_DIR/$ARCHIVE_NAME" -C "$BACKUP_DIR" "mongodb_$DATE" "uploads_$DATE"

# Clean up individual directories
rm -rf "$MONGO_BACKUP_DIR" "$UPLOADS_BACKUP_DIR"

echo "✅ Compressed backup created: $BACKUP_DIR/$ARCHIVE_NAME"

# Calculate backup size
BACKUP_SIZE=$(du -h "$BACKUP_DIR/$ARCHIVE_NAME" | cut -f1)
echo "📦 Backup size: $BACKUP_SIZE"

# Clean up old backups (keep last 5)
echo "🧹 Cleaning up old backups..."
cd "$BACKUP_DIR"
ls -t scoutpro_backup_*.tar.gz 2>/dev/null | tail -n +6 | xargs rm -f

REMAINING=$(ls -1 scoutpro_backup_*.tar.gz 2>/dev/null | wc -l)
echo "📚 Keeping $REMAINING most recent backups"

echo ""
echo "🎉 Backup completed successfully!"
echo "================================="
echo "Backup file: $BACKUP_DIR/$ARCHIVE_NAME"
echo "Backup size: $BACKUP_SIZE"
echo "Completed at: $(date)"

# Show restore instructions
echo ""
echo "📋 To restore from this backup:"
echo "1. Stop the application: docker compose down"
echo "2. Extract backup: tar -xzf $ARCHIVE_NAME"
echo "3. Restore database: docker compose up -d mongo"
echo "4. Import data: docker exec -i scoutpro-mongo mongorestore /tmp/restore"
echo "5. Copy uploads: docker cp uploads_$DATE/. scoutpro-backend:/app/uploads/"
echo "6. Start application: docker compose up -d"