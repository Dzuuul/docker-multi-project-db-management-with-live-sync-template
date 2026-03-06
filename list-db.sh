#!/usr/bin/env bash

echo "Running Database Containers"
echo "---------------------------"

docker ps --format "table {{.Names}}\t{{.Ports}}"