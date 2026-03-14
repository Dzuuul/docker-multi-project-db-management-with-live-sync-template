#!/bin/bash

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
echo "                       DATABASE BACKUP UTILITY"
echo "--------------------------------------------------------------------------------"

PROJECT=$1
TYPE=$2

BACKUP_DIR="./backup/$PROJECT"

function find_container() {
  local p_name=$1
  local p_type=$2
  # Mencari container yang cocok dengan pola nama project dan tipe db
  local match=$(docker ps --format '{{.Names}}' | grep -E "^(pg_|db_)?${p_name}(_|-)?${p_type}(-|$|[0-9])|^${p_name}$" | head -n 1)
  echo "$match"
}

# Pengecekan argumen
if [ -z "$PROJECT" ] || [ -z "$TYPE" ]; then
  echo "Usage:"
  echo "  ./backup-db.sh <project_name> <postgres|mongo>"
  echo ""
  exit 1
fi

mkdir -p "$BACKUP_DIR"

if [ "$TYPE" == "postgres" ]; then
  CONTAINER=$(find_container "$PROJECT" "postgres")
  if [ -z "$CONTAINER" ]; then 
    echo "❌ Error: Postgres container not found for project: $PROJECT"
    exit 1 
  fi

  echo "🐘 Backing up PostgreSQL from: $CONTAINER..."
  
  # Dump langsung ke file
  docker exec -t "$CONTAINER" \
  pg_dump -U "$PROJECT" "$PROJECT" \
  > "$BACKUP_DIR/postgres.sql"

  echo "✅ Backup success! Saved to: $BACKUP_DIR/postgres.sql"

elif [ "$TYPE" == "mongo" ]; then
  CONTAINER=$(find_container "$PROJECT" "mongo")
  if [ -z "$CONTAINER" ]; then 
    echo "❌ Error: Mongo container not found for project: $PROJECT"
    exit 1 
  fi

  echo "🍃 Backing up MongoDB from: $CONTAINER..."

  # Jalankan mongodump di dalam container
  docker exec "$CONTAINER" \
  mongodump \
  --username "$PROJECT" \
  --password "$PROJECT" \
  --authenticationDatabase admin \
  --db "$PROJECT" \
  --out /dump

  # Copy hasil dump ke host
  docker cp "$CONTAINER":/dump "$BACKUP_DIR"
  
  # Bersihkan dump di dalam container agar tidak menumpuk
  docker exec "$CONTAINER" rm -rf /dump

  echo "✅ Backup success! Saved to: $BACKUP_DIR/dump"

else
  echo "❌ Error: Invalid type '$TYPE'. Use 'postgres' or 'mongo'."
  exit 1
fi

echo "--------------------------------------------------------------------------------"