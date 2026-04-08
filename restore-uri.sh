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
echo "                    DATABASE REMOTE URI RESTORE UTILITY"
echo "--------------------------------------------------------------------------------"

PROJECT=$1
TYPE=$2
URI=$3

# Pengecekan argumen
if [ -z "$PROJECT" ] || [ -z "$TYPE" ] || [ -z "$URI" ]; then
  echo "Usage:"
  echo "  ./restore-uri.sh <project_name> <postgres|mongo> <connection_uri>"
  echo ""
  echo "Examples:"
  echo "  ./restore-uri.sh myproject postgres \"postgresql://user:pass@host:5432/dbname\""
  echo "  ./restore-uri.sh myproject mongo \"mongodb://user:pass@host:27017/dbname?authSource=admin\""
  echo ""
  exit 1
fi

BACKUP_DIR="./backup/$PROJECT"

if [ "$TYPE" == "postgres" ]; then
  # Auto-install tools
  ensure_tools gunzip pg_restore psql

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

  echo "🐘 Restoring PostgreSQL to Remote URI..."
  echo "📄 Source: $LATEST_BACKUP"
  echo "🎯 Target: (Redacted URI)"

  # Step 1: Drop and recreate database (since pg_restore doesn't always handle it well for remote without high privs)
  # Extract DB name from URI if possible for the refresh, or just rely on pg_restore
  # For safety, let's assume the URI points to the target DB.
  
  if [[ "$LATEST_BACKUP" == *.gz ]]; then
    gunzip -c "$LATEST_BACKUP" | pg_restore --clean --if-exists --no-owner --no-privileges --dbname="$URI"
  else
    # Fallback for plain SQL
    cat "$LATEST_BACKUP" | psql "$URI"
  fi

  echo "✅ Restore complete"

elif [ "$TYPE" == "mongo" ]; then
  # Auto-install tools
  ensure_tools mongorestore mongosh

  # Find latest backup (archive format)
  LATEST_BACKUP=$(ls -t "$BACKUP_DIR"/mongo_*.archive.gz 2>/dev/null | head -n 1)

  if [ -z "$LATEST_BACKUP" ] || [ ! -f "$LATEST_BACKUP" ]; then
    echo "❌ Error: No backup found in $BACKUP_DIR (must be .archive.gz format for URI restore)"
    exit 1
  fi

  echo "🍃 Restoring MongoDB to Remote URI..."
  echo "📄 Source: $LATEST_BACKUP"
  echo "🎯 Target: (Redacted URI)"

  # Refresh database (Drop existing)
  echo "🔄 Dropping target database..."
  mongosh "$URI" --eval "db.dropDatabase()"

  # Deteksi nama database asal dari dalam archive secara otomatis
  echo "🔍 Detecting source database name..."
  # We extract first db name found in archive
  ORIG_DB=$(cat "$LATEST_BACKUP" | mongorestore --archive --gzip --list 2>/dev/null | grep -v "preparing collections" | grep -v "listing contents" | head -n 1 | awk '{print $NF}' | cut -d'.' -f1)
  
  # Extract target DB name from URI
  # Simplified extraction: everything after last / and before ?
  TARGET_DB=$(echo "$URI" | sed -E 's/.*\///; s/\?.*//')

  if [ -z "$ORIG_DB" ] || [ -z "$TARGET_DB" ] || [ "$ORIG_DB" == "$TARGET_DB" ]; then
    echo "📦 Direct restore to target..."
    mongorestore --uri="$URI" --archive="$LATEST_BACKUP" --gzip
  else
    echo "📦 Mapping namespace: $ORIG_DB -> $TARGET_DB"
    mongorestore --uri="$URI" --archive="$LATEST_BACKUP" --gzip --nsFrom "$ORIG_DB.*" --nsTo "$TARGET_DB.*"
  fi

  echo "✅ Restore complete"

else
  echo "❌ Error: Invalid type '$TYPE'. Use 'postgres' or 'mongo'."
  exit 1
fi

echo "--------------------------------------------------------------------------------"
