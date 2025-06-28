#!/bin/bash

# Scout Pro - Restore Script
# Restores MongoDB database and uploaded files from backup

set -e

# Configuration
BACKUP_DIR="./backups"
MONGO_CONTAINER="scoutpro-mongo"
BACKEND_CONTAINER="scoutpro-backend"

echo "♻️  Scout Pro Restore Script"
echo "============================"

# Check if backup file is provided
if [ -z "$1" ]; then
    echo "❌ Please provide backup file name"
    echo "Usage: $0 <backup_file.tar.gz>"
    echo ""
    echo "Available backups:"
    ls -la "$BACKUP_DIR"/scoutpro_backup_*.tar.gz 2>/dev/null || echo "No backups found"
    exit 1
fi

BACKUP_FILE="$1"

# Check if backup file exists
if [ ! -f "$BACKUP_DIR/$BACKUP_FILE" ]; then
    if [ ! -f "$BACKUP_FILE" ]; then
        echo "❌ Backup file not found: $BACKUP_FILE"
        exit 1
    fi
    BACKUP_PATH="$BACKUP_FILE"
else
    BACKUP_PATH="$BACKUP_DIR/$BACKUP_FILE"
fi

echo "📦 Using backup file: $BACKUP_PATH"

# Confirm restoration
echo "⚠️  WARNING: This will replace all existing data!"
read -p "Are you sure you want to continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Restore cancelled"
    exit 1
fi

# Stop services
echo "🛑 Stopping services..."
docker compose down

# Extract backup
echo "📂 Extracting backup..."
TEMP_DIR="/tmp/scoutpro_restore_$$"
mkdir -p "$TEMP_DIR"
tar -xzf "$BACKUP_PATH" -C "$TEMP_DIR"

# Find extracted directories
MONGO_DIR=$(find "$TEMP_DIR" -name "mongodb_*" -type d | head -1)
UPLOADS_DIR=$(find "$TEMP_DIR" -name "uploads_*" -type d | head -1)

if [ -z "$MONGO_DIR" ]; then
    echo "❌ MongoDB backup not found in archive"
    exit 1
fi

if [ -z "$UPLOADS_DIR" ]; then
    echo "❌ Uploads backup not found in archive"
    exit 1
fi

echo "✅ Backup extracted successfully"

# Start MongoDB only
echo "🍃 Starting MongoDB..."
docker compose up -d mongo

# Wait for MongoDB to be ready
echo "⏳ Waiting for MongoDB to start..."
sleep 10

# Check if MongoDB is ready
until docker exec "$MONGO_CONTAINER" mongosh --eval "print('MongoDB is ready')" &>/dev/null; do
    echo "   Still waiting for MongoDB..."
    sleep 5
done

echo "✅ MongoDB is ready"

# Restore MongoDB data
echo "💾 Restoring MongoDB database..."

# Copy backup to container
docker cp "$MONGO_DIR/backup" "$MONGO_CONTAINER:/tmp/restore"

# Drop existing database and restore
docker exec "$MONGO_CONTAINER" mongosh --eval "
use scoutpro;
db.dropDatabase();
print('Database dropped');
"

# Restore from backup
docker exec "$MONGO_CONTAINER" mongorestore /tmp/restore

# Clean up backup in container
docker exec "$MONGO_CONTAINER" rm -rf /tmp/restore

echo "✅ MongoDB restore completed"

# Start backend to create uploads directory
echo "🚀 Starting backend..."
docker compose up -d backend

# Wait for backend to be ready
echo "⏳ Waiting for backend to start..."
sleep 10

# Restore uploaded files
echo "📸 Restoring uploaded files..."

# Clear existing uploads
docker exec "$BACKEND_CONTAINER" rm -rf /app/uploads/*

# Copy uploads backup to container
docker cp "$UPLOADS_DIR/." "$BACKEND_CONTAINER:/app/uploads/"

# Fix permissions
docker exec "$BACKEND_CONTAINER" chown -R nodejs:nodejs /app/uploads

echo "✅ Uploads restore completed"

# Start all services
echo "🚀 Starting all services..."
docker compose up -d

# Wait for services to be healthy
echo "⏳ Waiting for services to be fully ready..."
sleep 30

# Clean up temporary files
echo "🧹 Cleaning up temporary files..."
rm -rf "$TEMP_DIR"

# Check service status
echo "📊 Service Status:"
docker compose ps

# Verify restoration
echo "🔍 Verifying restoration..."

# Check MongoDB
MONGO_STATUS=$(docker exec "$MONGO_CONTAINER" mongosh --quiet --eval "
use scoutpro;
print('Users: ' + db.users.countDocuments());
print('Teams: ' + db.teams.countDocuments());
print('Players: ' + db.players.countDocuments());
print('Reports: ' + db.reports.countDocuments());
")

echo "📊 Database verification:"
echo "$MONGO_STATUS"

# Check uploads
UPLOADS_COUNT=$(docker exec "$BACKEND_CONTAINER" find /app/uploads -type f | wc -l)
echo "📸 Uploaded files: $UPLOADS_COUNT"

echo ""
echo "🎉 Restore completed successfully!"
echo "=================================="
echo ""
echo "📋 Next Steps:"
echo "1. Access application:"
echo "   - Local: http://$(hostname -I | awk '{print $1}'):3000"
echo "   - Demo login: coach@demo.com / password123"
echo ""
echo "2. Verify data integrity:"
echo "   - Check teams and players"
echo "   - Verify scouting reports"
echo "   - Test spray chart uploads"
echo ""
echo "3. If using Nginx Proxy Manager:"
echo "   - Access: http://$(hostname -I | awk '{print $1}'):81"
echo "   - Reconfigure domains if needed"
echo ""

echo "✅ All services are running and data has been restored"