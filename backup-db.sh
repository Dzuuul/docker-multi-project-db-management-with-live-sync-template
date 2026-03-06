#!/bin/bash

PROJECT=$1
TYPE=$2

BACKUP_DIR="./backup/$PROJECT"

mkdir -p $BACKUP_DIR

function find_container() {
  local p_name=$1
  local p_type=$2
  local match=$(docker ps --format '{{.Names}}' | grep -E "^(pg_|db_)?${p_name}(_|-)?${p_type}(-|$|[0-9])|^${p_name}$" | head -n 1)
  echo "$match"
}

if [ "$TYPE" == "postgres" ]; then
  CONTAINER=$(find_container "$PROJECT" "postgres")
  if [ -z "$CONTAINER" ]; then echo "Postgres container not found for $PROJECT"; exit 1; fi

  echo "Backing up PostgreSQL from $CONTAINER..."

  docker exec -t "$CONTAINER" \
  pg_dump -U $PROJECT $PROJECT \
  > $BACKUP_DIR/postgres.sql

  echo "Backup saved to $BACKUP_DIR/postgres.sql"

elif [ "$TYPE" == "mongo" ]; then
  CONTAINER=$(find_container "$PROJECT" "mongo")
  if [ -z "$CONTAINER" ]; then echo "Mongo container not found for $PROJECT"; exit 1; fi

  echo "Backing up MongoDB from $CONTAINER..."

  docker exec "$CONTAINER" \
  mongodump \
  --username $PROJECT \
  --password $PROJECT \
  --authenticationDatabase admin \
  --db $PROJECT \
  --out /dump

  docker cp "$CONTAINER":/dump $BACKUP_DIR

  echo "Backup saved to $BACKUP_DIR/dump"

else
  echo "Usage:"
  echo "./backup-db.sh <project> postgres|mongo"
fi