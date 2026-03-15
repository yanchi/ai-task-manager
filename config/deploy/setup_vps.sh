#!/bin/bash
set -e

# ==================================================
# VPS 初回セットアップスクリプト（Ubuntu 22.04）
# root または sudo 権限で実行すること
# 使い方: bash setup_vps.sh
# ==================================================

APP_DIR="/var/www/ai-task-manager"
DOMAIN="task.isl-mentor.com"

echo "==> Installing Docker..."
apt-get update -qq
apt-get install -y ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -qq
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

echo "==> Installing Nginx and Certbot..."
apt-get install -y nginx certbot python3-certbot-nginx

echo "==> Cloning repository..."
mkdir -p "$APP_DIR"
git clone https://github.com/YOUR_USERNAME/ai-task-manager.git "$APP_DIR"

echo "==> Setting up environment..."
cp "$APP_DIR/.env.production.example" "$APP_DIR/.env.production"
echo ""
echo ">>> .env.production を編集してください:"
echo "    - ANTHROPIC_API_KEY"
echo "    - DB_PASSWORD（強いパスワードを設定）"
echo "    - SECRET_KEY_BASE（以下コマンドで生成）"
echo "    cd $APP_DIR && docker compose -f docker-compose.production.yml run --rm web bundle exec rails secret"
echo ""

echo "==> Setting up Nginx..."
cp "$APP_DIR/config/deploy/nginx.conf" /etc/nginx/sites-available/ai-task-manager
sed -i "s/task.yourdomain.com/$DOMAIN/g" /etc/nginx/sites-available/ai-task-manager
ln -sf /etc/nginx/sites-available/ai-task-manager /etc/nginx/sites-enabled/
nginx -t
systemctl reload nginx

echo "==> Obtaining SSL certificate..."
certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "your@email.com"

echo "==> Building and starting the app..."
cd "$APP_DIR"
docker compose -f docker-compose.production.yml build
docker compose -f docker-compose.production.yml up -d

echo "==> Running initial setup..."
sleep 10
docker compose -f docker-compose.production.yml exec -T web bundle exec rails db:create db:migrate db:seed

echo ""
echo "==> Setup complete! https://$DOMAIN"
