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
echo "                   REMOTE DATABASE BACKUP (LOCAL TOOLS)"
echo "--------------------------------------------------------------------------------"

PROJECT=$1
TYPE=$2
HOST=$3
PORT=$4
USER=$5
DB=$6

# Validasi Input
if [ -z "$DB" ]; then
  echo "Usage:"
  echo "  ./backup-remote.sh <project> <postgres|mongo> <host> <port> <user> <db_name>"
  echo ""
  exit 1
fi

# --- AUTO-INSTALL REQUIRED TOOLS ---
if [ "$TYPE" == "mongo" ]; then
    ensure_tools mongodump pv
elif [ "$TYPE" == "postgres" ]; then
    ensure_tools pg_dump pv
fi

mkdir -p "backup/$PROJECT"

if [ "$TYPE" == "postgres" ]; then
  echo "🐘 Connecting to Remote Postgres..."
  
  pg_dump \
    -h "$HOST" \
    -p "$PORT" \
    -U "$USER" \
    -d "$DB" \
    -F c \
    -f "backup/$PROJECT/postgres.dump"

  echo "✅ Postgres backup saved to backup/$PROJECT/postgres.dump"

elif [ "$TYPE" == "mongo" ]; then
  echo "🍃 Connecting to Remote MongoDB..."

  mongodump \
    --uri="mongodb://$USER@$HOST:$PORT/$DB" \
    --out "backup/$PROJECT"

  echo "✅ Mongo backup saved to backup/$PROJECT"

else
  echo "❌ Error: Type must be 'postgres' or 'mongo'"
  exit 1
fi

echo "--------------------------------------------------------------------------------"