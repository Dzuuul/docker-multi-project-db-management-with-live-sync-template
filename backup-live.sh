#!/bin/bash

PROJECT=$1
TYPE=$2
HOST=$3
PORT=$4
USER=$5
DB=$6

mkdir -p backup/$PROJECT

if [ "$TYPE" == "postgres" ]; then

pg_dump \
-h $HOST \
-p $PORT \
-U $USER \
-d $DB \
-F c \
-f backup/$PROJECT/postgres.dump

echo "Postgres backup saved"

elif [ "$TYPE" == "mongo" ]; then

mongodump \
--uri="mongodb://$USER@$HOST:$PORT/$DB" \
--out backup/$PROJECT

echo "Mongo backup saved"

fi