#!/bin/bash

set -e
set -o pipefail

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
echo "                    DATABASE REAL-TIME SYNC UTILITY"
echo "--------------------------------------------------------------------------------"

PROJECT=$1
TYPE=$2

# Validasi awal argumen
if [ -z "$PROJECT" ] || [ -z "$TYPE" ]; then
  echo "Usage: ./sync-db.sh <project> <postgres|mongo>"
  exit 1
fi

# --- AUTO-INSTALL REQUIRED TOOLS ---
if [ "$TYPE" == "mongo" ]; then
    ensure_tools mongodump mongosh pv
elif [ "$TYPE" == "postgres" ]; then
    ensure_tools pv
fi

# Load Local Credentials if exists
ENV_PATH="./data/$PROJECT/.env"
if [ -f "$ENV_PATH" ]; then
    echo "📂 Local config found for '$PROJECT'. Loading credentials..."
    eval "$(grep -v '^#' "$ENV_PATH" | grep -v '^\s*$' | sed 's/[[:space:]]*=[[:space:]]*/=/g' | sed 's/^/export /')"
fi

function progress() {
  echo -e "\n\033[1;36m[➤]\033[0m \033[1m$1\033[0m"
}

# --- BAGIAN INPUT KONEKSI ---
progress "Setup Connection"
if [ "$TYPE" == "postgres" ]; then
    echo "Format: postgresql://user:pass@host:port/dbname"
    read -p "URI (empty to use credentials): " LIVE_URI
    if [ -z "$LIVE_URI" ]; then
        read -p "Host: " LIVE_HOST; read -p "Port: " LIVE_PORT; read -p "User: " LIVE_USER; read -p "Database: " LIVE_DB
        read -s -p "Password: " LIVE_PASS; echo ""
    fi
elif [ "$TYPE" == "mongo" ]; then
    echo "Format: mongodb://[user:pass@]host[:port]/dbname"
    read -p "URI (empty to use credentials): " LIVE_URI
    if [ -z "$LIVE_URI" ]; then
        read -p "Host: " LIVE_HOST; read -p "Port: " LIVE_PORT; read -p "User: " LIVE_USER; read -p "Database: " LIVE_DB
        read -s -p "Password: " LIVE_PASS; echo ""
    fi
fi

# Deteksi nama DB asal untuk Mongo mapping
if [ "$TYPE" == "mongo" ]; then
    if [ -n "$LIVE_URI" ] && [ -z "$LIVE_DB" ]; then
        LIVE_DB=$(echo "$LIVE_URI" | sed -E 's/.*\/(.*)(\?.*)?/\1/' | cut -d'?' -f1)
    fi
    if [ -z "$LIVE_DB" ] || [ "$LIVE_DB" == "*" ]; then
        echo -e "\n\033[1;31m[!] Nama database LIVE tidak terdeteksi.\033[0m"
        read -p "Masukkan nama database asli di server PRODUCTION: " LIVE_DB
    fi
fi

# --- RINGKASAN & KONFIRMASI ---
echo -e "\n\033[1;33m⚠️  SYNC EXECUTION PLAN\033[0m"
echo "---------------------------------------------------"
echo "SOURCE (LIVE) : ${LIVE_URI:-$LIVE_HOST (Manual)}"
echo "SOURCE DB     : ${LIVE_DB:-'detected via URI'}"
echo "TARGET (LOCAL): Docker Container matching '$PROJECT'"
echo "DATABASE NAME : Local DB '$PROJECT' will be OVERWRITTEN"
echo "---------------------------------------------------"
read -p "Apakah Anda yakin ingin melanjutkan? (y/N): " CONFIRM

if [[ ! "$CONFIRM" =~ ^[yY]$ ]]; then
    echo -e "\n❌ Sinkronisasi dibatalkan."
    exit 0
fi

BACKUP_DIR="./backup/$PROJECT"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
mkdir -p "$BACKUP_DIR"

function find_container() {
  local project=$1; local type=$2
  local match=$(docker ps --format '{{.Names}}' | grep -E "^(db_|pg_)?${project}.*${type}" | head -n 1)
  echo "$match"
}

################################
# POSTGRES SYNC
################################
if [ "$TYPE" == "postgres" ]; then
    POSTGRES_CONTAINER=$(find_container "$PROJECT" "postgres")
    [ -z "$POSTGRES_CONTAINER" ] && { echo "❌ Container not found"; exit 1; }

    # Estimasi ukuran untuk progress bar
    progress "Estimating Database Size..."
    if [ -n "$LIVE_URI" ]; then
        SIZE=$(docker run --rm --network=host postgres:17 psql "$LIVE_URI" -Atc "SELECT pg_database_size(current_database())" 2>/dev/null || echo 0)
    else
        SIZE=$(docker run --rm --network=host -e PGPASSWORD="$LIVE_PASS" postgres:17 psql -h "$LIVE_HOST" -p "$LIVE_PORT" -U "$LIVE_USER" -d "$LIVE_DB" -Atc "SELECT pg_database_size('$LIVE_DB')" 2>/dev/null || echo 0)
    fi

    BACKUP_FILE="$BACKUP_DIR/postgres_$TIMESTAMP.dump.gz"
    progress "Backing up LIVE (with Progress)..."
    if [ -n "$LIVE_URI" ]; then
        docker run --rm --network=host postgres:17 pg_dump "$LIVE_URI" -F c | pv -s "$SIZE" | gzip > "$BACKUP_FILE"
    else
        docker run --rm --network=host -e PGPASSWORD="$LIVE_PASS" postgres:17 pg_dump -h "$LIVE_HOST" -p "$LIVE_PORT" -U "$LIVE_USER" -d "$LIVE_DB" -F c | pv -s "$SIZE" | gzip > "$BACKUP_FILE"
    fi

    # Validasi backup file
    if [ ! -s "$BACKUP_FILE" ]; then
        echo -e "\n\033[1;31m[!] Backup file kosong. pg_dump kemungkinan gagal. Periksa koneksi dan kredensial.\033[0m"
        exit 1
    fi

    L_USER=${DB_USER:-"postgres"}
    L_PASS=${DB_PASSWORD:-"postgres"}

    progress "Refreshing Local Database..."
    PGPASSWORD=$L_PASS docker exec -i "$POSTGRES_CONTAINER" psql -h 127.0.0.1 -U "$L_USER" -d postgres -c "DROP DATABASE IF EXISTS $PROJECT;" -c "CREATE DATABASE $PROJECT;"
    
    progress "Restoring to Local..."
    gunzip -c "$BACKUP_FILE" | PGPASSWORD=$L_PASS docker exec -i "$POSTGRES_CONTAINER" pg_restore -h 127.0.0.1 -U "$L_USER" -d "$PROJECT" --no-owner --no-privileges
    progress "Postgres sync completed ✅"

################################
# MONGO SYNC
################################
elif [ "$TYPE" == "mongo" ]; then
    MONGO_CONTAINER=$(find_container "$PROJECT" "mongo")
    [ -z "$MONGO_CONTAINER" ] && { echo "❌ Container not found"; exit 1; }

    # Estimasi ukuran
    progress "Estimating Database Size..."
    if [ -n "$LIVE_URI" ]; then
        SIZE=$(mongosh "$LIVE_URI" --quiet --eval "db.stats().dataSize" 2>/dev/null || echo 0)
    else
        SIZE=$(mongosh --host "$LIVE_HOST" --port "$LIVE_PORT" -u "$LIVE_USER" -p "$LIVE_PASS" --authenticationDatabase admin --quiet --eval "db.getSiblingDB('$LIVE_DB').stats().dataSize" 2>/dev/null || echo 0)
    fi
    SIZE=${SIZE%%.*}

    BACKUP_FILE="$BACKUP_DIR/mongo_$TIMESTAMP.archive.gz"
    progress "Backing up LIVE (with Mongo)..."
    if [ -n "$LIVE_URI" ]; then
        mongodump --uri="$LIVE_URI" --db "$LIVE_DB" --archive --quiet | pv -s "$SIZE" | gzip > "$BACKUP_FILE"
    else
        mongodump --host "$LIVE_HOST" --port "$LIVE_PORT" --username "$LIVE_USER" --password "$LIVE_PASS" --authenticationDatabase admin --db "$LIVE_DB" --archive --quiet | pv -s "$SIZE" | gzip > "$BACKUP_FILE"
    fi

    L_USER=${MONGO_USER:-"mongo"}
    L_PASS=${MONGO_PASSWORD:-"mongo"}

    progress "Refreshing Local Database..."
    docker exec "$MONGO_CONTAINER" mongosh -u "$L_USER" -p "$L_PASS" --authenticationDatabase admin --eval "db.getSiblingDB('$PROJECT').dropDatabase()"
    
    progress "Restoring to Local..."
    cat "$BACKUP_FILE" | docker exec -i "$MONGO_CONTAINER" mongorestore \
        -u "$L_USER" -p "$L_PASS" --authenticationDatabase admin \
        --archive --gzip --nsFrom "$LIVE_DB.*" --nsTo "$PROJECT.*"
    
    progress "Mongo sync completed ✅"
fi

progress "ALL SYNC PROCESSES FINISHED 🚀"