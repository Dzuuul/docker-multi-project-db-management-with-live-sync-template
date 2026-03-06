#!/usr/bin/env bash

DB_NAME=$1
DELETE_DATA=$2

if [ -z "$DB_NAME" ]; then
  echo "Usage:"
  echo "./remove-db.sh <db_name> [--delete-data]"
  exit 1
fi

PROJECT="db_$DB_NAME"

docker compose -p "$PROJECT" down

echo "Containers removed"

if [ "$DELETE_DATA" = "--delete-data" ]; then
  rm -rf "./data/$DB_NAME"
  echo "Data folder deleted"
else
  echo "Data folder still exists: data/$DB_NAME"
fi