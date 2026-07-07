#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DB_PATH="$ROOT_DIR/database/family-heritage.db"
MIGRATION_PATH="$ROOT_DIR/backend/prisma/migrations/20260708000000_init/migration.sql"

mkdir -p "$(dirname "$DB_PATH")"

if sqlite3 "$DB_PATH" "select name from sqlite_master where type='table' and name='User';" | grep -q User; then
  echo "SQLite schema already exists: $DB_PATH"
else
  sqlite3 "$DB_PATH" < "$MIGRATION_PATH"
  echo "SQLite schema created: $DB_PATH"
fi
