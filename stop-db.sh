#!/usr/bin/env bash

DB_NAME=$1

if [ -z "$DB_NAME" ]; then
  echo "Usage:"
  echo "  ./stop-db.sh <db_name>"
  exit 1
fi

PROJECT_DIR="./data/$DB_NAME"

if [ ! -d "$PROJECT_DIR" ]; then
  echo "❌ Error: Project '$DB_NAME' tidak ditemukan di folder data/"
  exit 1
fi

echo "🛑 Stopping containers for project: $DB_NAME..."
cd "$PROJECT_DIR" && docker compose -p "$DB_NAME" stop

echo ""
echo "✅ Database stack '$DB_NAME' stopped successfully!"
