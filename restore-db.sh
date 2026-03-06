#!/bin/bash

PROJECT=$1
TYPE=$2

BACKUP_DIR="./backup/$PROJECT"

function find_container() {
  local p_name=$1
  local p_type=$2
  local match=$(docker ps --format '{{.Names}}' | grep -E "^(pg_|db_)?${p_name}(_|-)?${p_type}(-|$|[0-9])|^${p_name}$" | head -n 1)
  echo "$match"
}

if [ "$TYPE" == "postgres" ]; then
  CONTAINER=$(find_container "$PROJECT" "postgres")
  if [ -z "$CONTAINER" ]; then echo "Postgres container not found for $PROJECT"; exit 1; fi

  echo "Restoring PostgreSQL to $CONTAINER..."

  cat $BACKUP_DIR/postgres.sql | docker exec -i "$CONTAINER" \
  psql -U $PROJECT -d $PROJECT

  echo "Restore complete"

elif [ "$TYPE" == "mongo" ]; then
  CONTAINER=$(find_container "$PROJECT" "mongo")
  if [ -z "$CONTAINER" ]; then echo "Mongo container not found for $PROJECT"; exit 1; fi

  echo "Restoring MongoDB to $CONTAINER..."

  docker cp $BACKUP_DIR/dump "$CONTAINER":/dump

  docker exec "$CONTAINER" mongorestore \
    --username $PROJECT \
    --password $PROJECT \
    --authenticationDatabase admin \
    --db $PROJECT \
    /dump/$PROJECT

  echo "Restore complete"

else
  echo "Usage:"
  echo "./restore-db.sh <project> postgres|mongo"
fi