#!/bin/bash
set -e

# PostgreSQL が起動するまで待機
until pg_isready -h db -U postgres; do
  echo "Waiting for PostgreSQL..."
  sleep 1
done

# Rails の server.pid が残っている場合は削除
rm -f /app/tmp/pids/server.pid

exec "$@"
