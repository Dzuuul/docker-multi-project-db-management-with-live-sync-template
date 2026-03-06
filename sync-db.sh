#!/bin/bash

set -e

PROJECT=$1
TYPE=$2

BACKUP_DIR="./backup/$PROJECT"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

mkdir -p "$BACKUP_DIR"

function find_container() {
  local project=$1
  local type=$2
  
  # 1. Try exact match if PROJECT is the full container name
  if docker ps --format '{{.Names}}' | grep -q "^${project}$"; then
    echo "${project}"
    return 0
  fi

  # 2. Try common patterns (db_ is priority from create-db.sh)
  local patterns=(
    "db_${project}-${type}"
    "pg_${project}-${type}"
    "${project}-${type}"
    "db_${project}_${type}"
    "pg_${project}_${type}"
    "${project}_${type}"
  )

  for p in "${patterns[@]}"; do
    local match=$(docker ps --format '{{.Names}}' | grep -E "^${p}(-|$|[0-9])" | head -n 1)
    if [ -n "$match" ]; then
      echo "$match"
      return 0
    fi
  done

  # 3. Final attempt: fuzzy match (contains both project and type)
  local fuzzy=$(docker ps --format '{{.Names}}' | grep "$project" | grep "$type" | head -n 1)
  if [ -n "$fuzzy" ]; then
    echo "$fuzzy"
    return 0
  fi

  return 1
}

function progress() {
  echo -e "\n\033[1;34m==>\033[0m \033[1m$1\033[0m"
}

if [ -z "$PROJECT" ] || [ -z "$TYPE" ]; then
  echo "Usage:"
  echo "./sync-db.sh <project> postgres|mongo"
  exit 1
fi


################################
# POSTGRES SYNC
################################

if [ "$TYPE" == "postgres" ]; then

progress "Detecting Postgres container..."

POSTGRES_CONTAINER=$(find_container "$PROJECT" "postgres")

if [ -z "$POSTGRES_CONTAINER" ]; then
  echo "Postgres container not found for project: $PROJECT"
  echo "Tried patterns like pg_${PROJECT}-postgres, db_${PROJECT}-postgres, etc."
  exit 1
fi

echo "Container detected: $POSTGRES_CONTAINER"

progress "Enter LIVE Postgres connection"
echo "Format: postgresql://user:pass@host:port/dbname"
read -p "URI (leave empty to use individual credentials): " LIVE_URI

if [ -n "$LIVE_URI" ]; then
  # Extract DB name from URI (last part after / and before any parameters)
  LIVE_DB=$(echo "$LIVE_URI" | sed -E 's/.*\/(.*)(\?.*)?/\1/' | cut -d'?' -f1)
  if [ -z "$LIVE_DB" ]; then
     read -p "Database name in LIVE: " LIVE_DB
  else
     echo "Detected Database: $LIVE_DB"
  fi
else
  read -p "Host: " LIVE_HOST
  read -p "Port: " LIVE_PORT
  read -p "User: " LIVE_USER
  read -p "Database: " LIVE_DB
  read -s -p "Password: " LIVE_PASS
  echo ""
  export PGPASSWORD=$LIVE_PASS
fi

BACKUP_FILE="$BACKUP_DIR/postgres_$TIMESTAMP.dump.gz"

progress "Estimating database size..."
if [ -n "$LIVE_URI" ]; then
  RAW_SIZE=$(psql "$LIVE_URI" -A -t -c "SELECT pg_database_size('$LIVE_DB');" 2>/dev/null || echo 0)
else
  # Use PGPASSWORD for the size check too
  RAW_SIZE=$(PGPASSWORD=$LIVE_PASS psql -h "$LIVE_HOST" -p "$LIVE_PORT" -U "$LIVE_USER" -d "$LIVE_DB" -A -t -c "SELECT pg_database_size('$LIVE_DB');" 2>/dev/null || echo 0)
fi
ESTIMATED_SIZE=$(echo "$RAW_SIZE" | tr -dc '0-9')
[ -z "$ESTIMATED_SIZE" ] && ESTIMATED_SIZE=0
echo "Estimated Size: $(numfmt --to=iec-i --suffix=B $ESTIMATED_SIZE 2>/dev/null || echo $ESTIMATED_SIZE)"

progress "Backing up LIVE Postgres database..."
if [ -n "$LIVE_URI" ]; then
  # Pipe through gzip to match the extension and restore command
  pg_dump "$LIVE_URI" -F c 2>/dev/null | pv -p -e -r -t -b -s "$ESTIMATED_SIZE" | gzip > "$BACKUP_FILE"
else
  pg_dump -h "$LIVE_HOST" -p "$LIVE_PORT" -U "$LIVE_USER" -d "$LIVE_DB" -F c 2>/dev/null | pv -p -e -r -t -b -s "$ESTIMATED_SIZE" | gzip > "$BACKUP_FILE"
fi

echo "Backup saved: $BACKUP_FILE"

# Auto-detect local Postgres superuser from container environment
LOCAL_PG_USER=$(docker exec "$POSTGRES_CONTAINER" env | grep "^POSTGRES_USER=" | cut -d= -f2 || echo "")

# If detection failed or returned empty, fallback
if [ -z "$LOCAL_PG_USER" ]; then
  LOCAL_PG_USER="postgres"
fi

echo "Using local Postgres user: $LOCAL_PG_USER"

progress "Cleaning LOCAL database..."

# Force connection via 127.0.0.1 to avoid permission denied on socket file
docker exec -i "$POSTGRES_CONTAINER" psql -h 127.0.0.1 -U "$LOCAL_PG_USER" -d postgres -c "DROP DATABASE IF EXISTS $PROJECT;"
docker exec -i "$POSTGRES_CONTAINER" psql -h 127.0.0.1 -U "$LOCAL_PG_USER" -d postgres -c "CREATE DATABASE $PROJECT;"

progress "Restoring to LOCAL docker Postgres..."
# Added --no-owner and --no-privileges to avoid role mismatch errors
gunzip -c "$BACKUP_FILE" | docker exec -i "$POSTGRES_CONTAINER" pg_restore -h 127.0.0.1 -U "$LOCAL_PG_USER" -d "$PROJECT" --no-owner --no-privileges

progress "Postgres sync completed"

fi


################################
# MONGO SYNC
################################

if [ "$TYPE" == "mongo" ]; then

progress "Detecting Mongo container..."

MONGO_CONTAINER=$(find_container "$PROJECT" "mongo")

if [ -z "$MONGO_CONTAINER" ]; then
  echo "Mongo container not found for project: $PROJECT"
  echo "Tried patterns like pg_${PROJECT}-mongo, db_${PROJECT}-mongo, etc."
  exit 1
fi

echo "Container detected: $MONGO_CONTAINER"

progress "Enter LIVE Mongo connection"
echo "Format: mongodb://[user:pass@]host[:port]/dbname"
read -p "URI (leave empty to use individual credentials): " LIVE_URI

if [ -n "$LIVE_URI" ]; then
  # Try to extract DB name from URI (last part after / and before ?)
  # Example: mongodb://user:pass@host:port/dbname?authSource=admin
  LIVE_DB=$(echo "$LIVE_URI" | sed -E 's/.*\/(.*)\?.*/\1/' | sed -E 's/.*\/(.*)/\1/')
  
  if [ -z "$LIVE_DB" ] || [[ "$LIVE_DB" == *"/"* ]]; then
     read -p "Database name in LIVE: " LIVE_DB
  else
     echo "Detected Database: $LIVE_DB"
  fi
else
  read -p "Host: " LIVE_HOST
  read -p "Port: " LIVE_PORT
  read -p "User: " LIVE_USER
  read -p "Database: " LIVE_DB
  read -s -p "Password: " LIVE_PASS
  echo ""
fi

BACKUP_FILE="$BACKUP_DIR/mongo_$TIMESTAMP.archive.gz"

progress "Estimating MongoDB size..."
if [ -n "$LIVE_URI" ]; then
  RAW_SIZE=$(mongosh "$LIVE_URI" --quiet --eval "db.stats().dataSize" 2>/dev/null || echo 0)
else
  RAW_SIZE=$(mongosh --host "$LIVE_HOST" --port "$LIVE_PORT" -u "$LIVE_USER" -p "$LIVE_PASS" --authenticationDatabase admin --quiet --eval "db.getSiblingDB('$LIVE_DB').stats().dataSize" 2>/dev/null || echo 0)
fi
# Clean size to only digits
ESTIMATED_SIZE=$(echo "$RAW_SIZE" | tr -dc '0-9')
[ -z "$ESTIMATED_SIZE" ] && ESTIMATED_SIZE=0
echo "Estimated Size: $(numfmt --to=iec-i --suffix=B $ESTIMATED_SIZE 2>/dev/null || echo $ESTIMATED_SIZE)"

progress "Backing up LIVE MongoDB..."
if [ -n "$LIVE_URI" ]; then
  # Use a separate pv for visual if redirected. Redirecting stderr of dump to dev/null to keep UI clean
  mongodump --uri="$LIVE_URI" --archive --quiet 2>/dev/null | pv -p -e -r -t -b -s "$ESTIMATED_SIZE" | gzip > "$BACKUP_FILE"
else
  mongodump \
  --host "$LIVE_HOST" \
  --port "$LIVE_PORT" \
  --username "$LIVE_USER" \
  --password "$LIVE_PASS" \
  --authenticationDatabase admin \
  --db "$LIVE_DB" \
  --archive --quiet 2>/dev/null | pv -p -e -r -t -b -s "$ESTIMATED_SIZE" | gzip > "$BACKUP_FILE"
fi

echo "Backup saved: $BACKUP_FILE"

progress "Cleaning LOCAL Mongo database..."

# Auto-detect local Mongo root user
LOCAL_MONGO_USER=$(docker exec "$MONGO_CONTAINER" env | grep "^MONGO_INITDB_ROOT_USERNAME=" | cut -d= -f2 || echo "")
LOCAL_MONGO_PASS=$(docker exec "$MONGO_CONTAINER" env | grep "^MONGO_INITDB_ROOT_PASSWORD=" | cut -d= -f2 || echo "")

[ -z "$LOCAL_MONGO_USER" ] && LOCAL_MONGO_USER="mongo"
[ -z "$LOCAL_MONGO_PASS" ] && LOCAL_MONGO_PASS="mongo"

echo "Using local Mongo user: $LOCAL_MONGO_USER"

# Verify auth, if failed ask user
if ! docker exec "$MONGO_CONTAINER" mongosh -u "$LOCAL_MONGO_USER" -p "$LOCAL_MONGO_PASS" --authenticationDatabase admin --eval "db.version()" >/dev/null 2>&1; then
    echo "Local MongoDB authentication failed for detected user $LOCAL_MONGO_USER."
    read -p "Local Mongo User: " LOCAL_MONGO_USER
    read -s -p "Local Mongo Password: " LOCAL_MONGO_PASS
    echo ""
fi

docker exec "$MONGO_CONTAINER" mongosh \
-u "$LOCAL_MONGO_USER" \
-p "$LOCAL_MONGO_PASS" \
--authenticationDatabase admin \
--eval "db.getSiblingDB('$PROJECT').dropDatabase()"

progress "Restoring to LOCAL Mongo..."

cat "$BACKUP_FILE" | docker exec -i "$MONGO_CONTAINER" mongorestore \
-u "$LOCAL_MONGO_USER" \
-p "$LOCAL_MONGO_PASS" \
--authenticationDatabase admin \
--archive --gzip \
--nsFrom "$LIVE_DB.*" --nsTo "$PROJECT.*"

progress "Mongo sync completed"

fi


progress "SYNC FINISHED 🚀"