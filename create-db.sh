#!/usr/bin/env bash

set -e

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

if [ -d "$DATA_DIR/$DB_NAME" ]; then
  echo "Database '$DB_NAME' already exists"
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

echo "Postgres port: $PG_PORT"
echo "Mongo port: $MONGO_PORT"

mkdir -p "$DATA_DIR/$DB_NAME/postgres"
mkdir -p "$DATA_DIR/$DB_NAME/mongo"

DB_NAME=$DB_NAME \
DB_USER=$DB_USER \
DB_PASSWORD=$DB_PASSWORD \
PG_PORT=$PG_PORT \
MONGO_PORT=$MONGO_PORT \
MONGO_USER=$MONGO_USER \
MONGO_PASSWORD=$MONGO_PASSWORD \
docker compose -p "db_$DB_NAME" up -d

echo ""
echo "Database stack created"
echo "----------------------------------"

echo "Postgres"
echo "host : localhost"
echo "port : $PG_PORT"
echo "user : $DB_USER"
echo "pass : $DB_PASSWORD"
echo "db   : $DB_NAME"

echo ""

echo "MongoDB"
echo "host : localhost"
echo "port : $MONGO_PORT"
echo "user : $MONGO_USER"
echo "pass : $MONGO_PASSWORD"