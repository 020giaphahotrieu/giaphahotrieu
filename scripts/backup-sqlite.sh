#!/usr/bin/env bash
set -euo pipefail

DB_PATH="${1:-database/family-heritage.db}"
BACKUP_DIR="${2:-database/backups}"
STAMP="$(date +%Y%m%d-%H%M%S)"

mkdir -p "$BACKUP_DIR"
cp "$DB_PATH" "$BACKUP_DIR/family-heritage-$STAMP.db"
echo "Backup created: $BACKUP_DIR/family-heritage-$STAMP.db"
