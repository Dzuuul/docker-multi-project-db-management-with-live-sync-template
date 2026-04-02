#!/bin/bash

# --- SHARED LIBRARY (auto-install tools) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

# --- BANNER ASCII HARDCODED ---
clear
cat << "EOF"
 ██▓███   ▄▄▄       █    ██   ██████      ██████  ▄▄▄       ██▓  ▄▄▄█████▓ ▒█████  
▓██░  ██▒▒████▄     ██  ▓██▒▒██    ▒    ▒██    ▒ ▒████▄    ▓██▒  ▓  ██▒ ▓▒▒██▒  ██▒
▓██░ ██▓▒▒██  ▀█▄  ▓██  ▒██░░ ▓██▄      ░ ▓██▄   ▒██  ▀█▄  ▒██░  ▒ ▓██░ ▒░▒██░  ██▒
▒██▄█▓▒ ▒░██▄▄▄▄██ ▓▓█  ░██░  ▒   ██▒     ▒   ██▒░██▄▄▄▄██ ▒██░  ░ ▓██▓ ░ ▒██   ██░
▒██▒ ░  ░ ▓█   ▓██▒▒▒█████▓ ▒██████▒▒   ▒██████▒▒ ▓█   ▓██▒░██████▒▒██▒ ░ ░ ████▓▒░
▒▓▒░ ░  ░ ▒▒   ▓▒█░░▒▓▒ ▒ ▒ ▒ ▒▓▒ ▒ ░   ▒ ▒▓▒ ▒ ░ ▒▒   ▓▒█░░ ▒░▓  ░▒ ░░   ░ ▒░▒░▒░ 
░▒ ░       ▒   ▒▒ ░░░▒░ ░ ░ ░ ░▒  ░ ░   ░ ░▒  ░ ░  ▒   ▒▒ ░░ ░ ▒  ░  ░      ░ ▒ ▒░ 
░░         ░   ▒    ░░░ ░ ░ ░  ░  ░     ░  ░  ░    ░   ▒     ░ ░   ░      ░ ░ ░ ▒  
               ░  ░   ░           ░           ░        ░  ░    ░  ░           ░ ░  
EOF
echo "--------------------------------------------------------------------------------"
echo "                    DATABASE STACK RESTORE UTILITY"
echo "--------------------------------------------------------------------------------"

PROJECT=$1
TYPE=$2

# Pengecekan argumen
if [ -z "$PROJECT" ] || [ -z "$TYPE" ]; then
  echo "Usage:"
  echo "  ./restore-db.sh <project_name> <postgres|mongo>"
  echo ""
  exit 1
fi

# Load Local Credentials if exists
ENV_PATH="./data/$PROJECT/.env"
if [ -f "$ENV_PATH" ]; then
    echo "📂 Local config found for '$PROJECT'. Loading credentials..."
    # Sed to handle spaces and ensure export works
    eval "$(grep -v '^#' "$ENV_PATH" | grep -v '^\s*$' | sed 's/[[:space:]]*=[[:space:]]*/=/g' | sed 's/^/export /')"
fi

function find_container() {
  local p_name=$1
  local p_type=$2
  local match=$(docker ps --format '{{.Names}}' | grep -E "^(db_|pg_)?${p_name}.*${p_type}" | head -n 1)
  echo "$match"
}

BACKUP_DIR="./backup/$PROJECT"

if [ "$TYPE" == "postgres" ]; then
  CONTAINER=$(find_container "$PROJECT" "postgres")
  if [ -z "$CONTAINER" ]; then 
    echo "❌ Error: Postgres container not found for $PROJECT"
    exit 1 
  fi

  # Auto-install tools
  ensure_tools gunzip pg_restore

  # Find latest backup
  LATEST_BACKUP=$(ls -t "$BACKUP_DIR"/postgres_*.dump.gz 2>/dev/null | head -n 1)
  
  # Fallback for old naming if exists
  if [ -z "$LATEST_BACKUP" ] && [ -f "$BACKUP_DIR/postgres.sql" ]; then
    LATEST_BACKUP="$BACKUP_DIR/postgres.sql"
  fi

  if [ -z "$LATEST_BACKUP" ] || [ ! -f "$LATEST_BACKUP" ]; then
    echo "❌ Error: No backup file found in $BACKUP_DIR"
    exit 1
  fi

  L_USER=${DB_USER:-"postgres"}
  L_PASS=${DB_PASSWORD:-"postgres"}

  echo "🐘 Restoring PostgreSQL to $CONTAINER..."
  echo "📄 Source: $LATEST_BACKUP"
  echo "🎯 Database: $PROJECT"

  # Drop and recreate database (matching sync-db scheme)
  echo "🔄 Refreshing local database '$PROJECT'..."
  PGPASSWORD=$L_PASS docker exec -i "$CONTAINER" psql -h 127.0.0.1 -U "$L_USER" -d postgres -c "DROP DATABASE IF EXISTS \"$PROJECT\";" -c "CREATE DATABASE \"$PROJECT\";"

  # Restore process
  if [[ "$LATEST_BACKUP" == *.gz ]]; then
    gunzip -c "$LATEST_BACKUP" | PGPASSWORD=$L_PASS docker exec -i "$CONTAINER" pg_restore -h 127.0.0.1 -U "$L_USER" -d "$PROJECT" --no-owner --no-privileges
  else
    # Fallback for plain SQL
    cat "$LATEST_BACKUP" | docker exec -i "$CONTAINER" psql -U "$L_USER" -d "$PROJECT"
  fi

  echo "✅ Restore complete"

elif [ "$TYPE" == "mongo" ]; then
  CONTAINER=$(find_container "$PROJECT" "mongo")
  if [ -z "$CONTAINER" ]; then 
    echo "❌ Error: Mongo container not found for $PROJECT"
    exit 1 
  fi

  # Auto-install tools
  ensure_tools mongorestore

  # Find latest backup (archive format)
  LATEST_BACKUP=$(ls -t "$BACKUP_DIR"/mongo_*.archive.gz 2>/dev/null | head -n 1)

  if [ -z "$LATEST_BACKUP" ] || [ ! -f "$LATEST_BACKUP" ]; then
    # Fallback to directory dump if exists (old format)
    if [ -d "$BACKUP_DIR/dump" ]; then
      echo "🍃 Restoring MongoDB (Folder Dump) to $CONTAINER..."
      docker cp "$BACKUP_DIR/dump" "$CONTAINER":/dump
      docker exec "$CONTAINER" mongorestore --username "${MONGO_USER:-$PROJECT}" --password "${MONGO_PASSWORD:-$PROJECT}" --authenticationDatabase admin --db "$PROJECT" /dump/"$PROJECT"
      docker exec "$CONTAINER" rm -rf /dump
      echo "✅ Restore complete"
      exit 0
    fi
    echo "❌ Error: No backup found in $BACKUP_DIR"
    exit 1
  fi

  L_USER=${MONGO_USER:-"mongo"}
  L_PASS=${MONGO_PASSWORD:-"mongo"}

  echo "🍃 Restoring MongoDB to $CONTAINER..."
  echo "📄 Source: $LATEST_BACKUP"
  echo "🎯 Database: $PROJECT"

  # Refresh database
  docker exec "$CONTAINER" mongosh -u "$L_USER" -p "$L_PASS" --authenticationDatabase admin --eval "db.getSiblingDB('$PROJECT').dropDatabase()"

  # Deteksi nama database asal dari dalam archive secara otomatis
  echo "🔍 Detecting source database name..."
  ORIG_DB=$(cat "$LATEST_BACKUP" | docker exec -i "$CONTAINER" mongorestore --archive --gzip --list 2>/dev/null | grep -v "preparing collections" | grep -v "listing contents" | head -n 1 | awk '{print $NF}' | cut -d'.' -f1)
  
  if [ -z "$ORIG_DB" ]; then
    echo "⚠️  Could not detect source DB name, attempting direct restore..."
    cat "$LATEST_BACKUP" | docker exec -i "$CONTAINER" mongorestore \
        -u "$L_USER" -p "$L_PASS" --authenticationDatabase admin \
        --archive --gzip
  else
    echo "📦 Mapping namespace: $ORIG_DB -> $PROJECT"
    # Restore dengan mapping nama yang benar
    cat "$LATEST_BACKUP" | docker exec -i "$CONTAINER" mongorestore \
        -u "$L_USER" -p "$L_PASS" --authenticationDatabase admin \
        --archive --gzip --nsFrom "$ORIG_DB.*" --nsTo "$PROJECT.*"
  fi

  echo "✅ Restore complete"

else
  echo "❌ Error: Invalid type '$TYPE'. Use 'postgres' or 'mongo'."
  exit 1
fi

echo "--------------------------------------------------------------------------------"