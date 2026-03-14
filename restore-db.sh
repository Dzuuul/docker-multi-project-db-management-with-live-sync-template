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
echo "                    DATABASE STACK RESTORE UTILITY"
echo "--------------------------------------------------------------------------------"

PROJECT=$1
TYPE=$2

BACKUP_DIR="./backup/$PROJECT"

function find_container() {
  local p_name=$1
  local p_type=$2
  local match=$(docker ps --format '{{.Names}}' | grep -E "^(pg_|db_)?${p_name}(_|-)?${p_type}(-|$|[0-9])|^${p_name}$" | head -n 1)
  echo "$match"
}

# Pengecekan argumen
if [ -z "$PROJECT" ] || [ -z "$TYPE" ]; then
  echo "Usage:"
  echo "  ./restore-db.sh <project_name> <postgres|mongo>"
  echo ""
  exit 1
fi

if [ "$TYPE" == "postgres" ]; then
  CONTAINER=$(find_container "$PROJECT" "postgres")
  if [ -z "$CONTAINER" ]; then 
    echo "❌ Error: Postgres container not found for $PROJECT"
    exit 1 
  fi

  if [ ! -f "$BACKUP_DIR/postgres.sql" ]; then
    echo "❌ Error: Backup file $BACKUP_DIR/postgres.sql not found"
    exit 1
  fi

  echo "🐘 Restoring PostgreSQL to $CONTAINER..."

  cat "$BACKUP_DIR/postgres.sql" | docker exec -i "$CONTAINER" \
  psql -U "$PROJECT" -d "$PROJECT"

  echo "✅ Restore complete"

elif [ "$TYPE" == "mongo" ]; then
  CONTAINER=$(find_container "$PROJECT" "mongo")
  if [ -z "$CONTAINER" ]; then 
    echo "❌ Error: Mongo container not found for $PROJECT"
    exit 1 
  fi

  if [ ! -d "$BACKUP_DIR/dump" ]; then
    echo "❌ Error: Backup directory $BACKUP_DIR/dump not found"
    exit 1
  fi

  echo "🍃 Restoring MongoDB to $CONTAINER..."

  # Menyalin data dump ke dalam container
  docker cp "$BACKUP_DIR/dump" "$CONTAINER":/dump

  # Menjalankan mongorestore
  docker exec "$CONTAINER" mongorestore \
    --username "$PROJECT" \
    --password "$PROJECT" \
    --authenticationDatabase admin \
    --db "$PROJECT" \
    /dump/"$PROJECT"

  # Opsional: Hapus dump di dalam container setelah selesai
  docker exec "$CONTAINER" rm -rf /dump

  echo "✅ Restore complete"

else
  echo "❌ Error: Invalid type '$TYPE'. Use 'postgres' or 'mongo'."
  exit 1
fi

echo "--------------------------------------------------------------------------------"