#!/usr/bin/env bash

set -e

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
echo "---------------------------------------------------------------"
echo "                DATABASE STACK GENERATOR"
echo "---------------------------------------------------------------"

DB_NAME=$1
DB_USER=${2:-postgres}
DB_PASSWORD=${3:-postgres}

MONGO_USER=${4:-mongo}
MONGO_PASSWORD=${5:-mongo}

BASE_PG_PORT=5432
BASE_MONGO_PORT=27017

DATA_DIR="./data"

if [ -z "$DB_NAME" ]; then
  echo "Usage:"
  echo "./create-db.sh <db_name> [pg_user] [pg_password] [mongo_user] [mongo_password]"
  exit 1
fi

PROJECT_DIR="$DATA_DIR/$DB_NAME"

if [ -d "$PROJECT_DIR" ]; then
  echo "Error: Database '$DB_NAME' already exists in $DATA_DIR"
  exit 1
fi

# find free postgres port
PG_PORT=$BASE_PG_PORT
while ss -lnt | awk '{print $4}' | grep -q ":$PG_PORT$"; do
  PG_PORT=$((PG_PORT+1))
done

# find free mongo port
MONGO_PORT=$BASE_MONGO_PORT
while ss -lnt | awk '{print $4}' | grep -q ":$MONGO_PORT$"; do
  MONGO_PORT=$((MONGO_PORT+1))
done

echo "Allocating Ports..."
echo ">> Postgres port : $PG_PORT"
echo ">> Mongo port    : $MONGO_PORT"
echo ""

# Buat folder project
mkdir -p "$PROJECT_DIR/postgres"
mkdir -p "$PROJECT_DIR/mongo"

# --- SIMPAN KREDENSIAL KE FILE .env ---
ENV_FILE="$PROJECT_DIR/.env"
cat << EOT > "$ENV_FILE"
DB_NAME="$DB_NAME"
DB_USER="$DB_USER"
DB_PASSWORD="$DB_PASSWORD"
PG_PORT="$PG_PORT"
MONGO_USER="$MONGO_USER"
MONGO_PASSWORD="$MONGO_PASSWORD"
MONGO_PORT="$MONGO_PORT"
CREATED_AT="$(date)"
EOT

echo "Credential saved to: $ENV_FILE"

# --- CREATE PROJECT DOCKER COMPOSE FILE ---
PROJECT_COMPOSE="$PROJECT_DIR/docker-compose.yml"
cat << EOT > "$PROJECT_COMPOSE"
services:
  postgres:
    image: postgres:17-alpine
    restart: always
    environment:
      POSTGRES_USER: "$DB_USER"
      POSTGRES_PASSWORD: "$DB_PASSWORD"
      POSTGRES_DB: "$DB_NAME"
    ports:
      - "$PG_PORT:5432"
    volumes:
      - ./postgres:/var/lib/postgresql/data

  mongo:
    image: mongo:7
    restart: always
    environment:
      MONGO_INITDB_ROOT_USERNAME: "$MONGO_USER"
      MONGO_INITDB_ROOT_PASSWORD: "$MONGO_PASSWORD"
    ports:
      - "$MONGO_PORT:27017"
    volumes:
      - ./mongo:/data/db

# Use 'docker compose -p ${DB_NAME}' when running this from the root
# Or better: use the start-db.sh script which handles everything correctly.
# NOTE: If using WSL, ensure data is stored in the Linux filesystem (e.g., /home/user/) 
# rather than /mnt/c/ to avoid permission issues and performance degradation.
EOT

echo "Docker Compose file generated at: $PROJECT_COMPOSE"

echo "🚀 Starting database containers..."
# Run Docker Compose from inside the project directory to ensure relative paths are stable
# We specify the project name (-p) to be consistent with start-db.sh
cd "$PROJECT_DIR" && docker compose -p "$DB_NAME" up -d

echo ""
echo "✅ Database stack '$DB_NAME' created successfully!"
echo "---------------------------------------------------------------"

echo "🐘 POSTGRESQL"
echo "   Host : localhost"
echo "   Port : $PG_PORT"
echo "   User : $DB_USER"
echo "   Pass : $DB_PASSWORD"
echo "   DB   : $DB_NAME"

echo ""

echo "🍃 MONGODB"
echo "   Host : localhost"
echo "   Port : $MONGO_PORT"
echo "   User : $MONGO_USER"
echo "   Pass : $MONGO_PASSWORD"
echo "---------------------------------------------------------------"