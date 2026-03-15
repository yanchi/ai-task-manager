#!/bin/bash
set -e

# ==================================================
# AI Task Manager - VPS デプロイスクリプト
# 使い方: ./config/deploy/deploy.sh
# ==================================================

APP_DIR="/var/www/ai-task-manager"

echo "==> Pulling latest code..."
cd "$APP_DIR"
git pull origin main

echo "==> Building production image..."
docker compose --env-file .env.production -f docker-compose.production.yml build web

echo "==> Starting services..."
docker compose --env-file .env.production -f docker-compose.production.yml up -d

echo "==> Waiting for web to be healthy..."
sleep 5

echo "==> Running migrations..."
docker compose --env-file .env.production -f docker-compose.production.yml exec -T web bundle exec rails db:migrate

echo "==> Done! App is running at https://task.isl-mentor.com"
