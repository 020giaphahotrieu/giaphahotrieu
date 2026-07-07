#!/usr/bin/env bash
set -euo pipefail

BACKUP_PATH="${1:?Usage: scripts/restore-sqlite.sh <backup-db-path> [target-db-path]}"
TARGET_PATH="${2:-database/family-heritage.db}"

cp "$BACKUP_PATH" "$TARGET_PATH"
echo "Database restored to: $TARGET_PATH"
