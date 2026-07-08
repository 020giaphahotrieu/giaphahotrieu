#!/usr/bin/env bash
set -Eeuo pipefail

DOMAIN="${DOMAIN:-giaphahotrieu.vn}"
WWW_DOMAIN="${WWW_DOMAIN:-}"
CERTBOT_EMAIL="${CERTBOT_EMAIL:-admin@giaphahotrieu.vn}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@example.com}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-Admin@123456}"
NODE_MAJOR_REQUIRED="${NODE_MAJOR_REQUIRED:-20}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEPLOY_ROOT="/var/www/${DOMAIN}"
LOG_FILE="${PROJECT_DIR}/deploy-production.log"
FINAL_URL="https://${DOMAIN}"

mkdir -p "$(dirname "$LOG_FILE")"
: >"$LOG_FILE"

on_error() {
  local exit_code="$1"
  echo "Deploy failed with exit code ${exit_code}. See ${LOG_FILE}" >&2
  exit "$exit_code"
}

trap 'on_error $?' ERR

cd "$PROJECT_DIR"

if [[ "$(id -u)" -eq 0 ]]; then
  sudo() {
    while [[ "$#" -gt 0 && "$1" == -* ]]; do
      shift
    done
    "$@"
  }
fi

run_retry() {
  local attempts="${1}"
  shift
  local delay=4
  local n=1
  until "$@"; do
    if [[ "$n" -ge "$attempts" ]]; then
      return 1
    fi
    sleep "$delay"
    n=$((n + 1))
    delay=$((delay * 2))
  done
}

ensure_node() {
  if command -v node >/dev/null 2>&1; then
    local major
    major="$(node -p 'Number(process.versions.node.split(".")[0])')"
    if [[ "$major" -ge "$NODE_MAJOR_REQUIRED" ]]; then
      return
    fi
  fi

  curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR_REQUIRED}.x" | sudo -E bash -
  sudo apt-get install -y nodejs
}

pull_latest_code() {
  if [[ -d .git ]]; then
    git config --global --add safe.directory "$PROJECT_DIR" || true
    if ! git diff --quiet || ! git diff --cached --quiet; then
      git stash push -u -m "auto-stash-before-production-deploy-$(date +%Y%m%d%H%M%S)" || true
    fi
    git fetch --all --prune || true
    git pull --rebase --autostash || git pull --ff-only || true
  fi
}

write_env_files() {
  local jwt_secret
  if [[ -f backend/.env ]] && grep -q '^JWT_SECRET=' backend/.env; then
    jwt_secret="$(grep '^JWT_SECRET=' backend/.env | tail -n1 | cut -d= -f2- | tr -d '"')"
  else
    jwt_secret="${JWT_SECRET:-$(openssl rand -hex 48)}"
  fi

  local client_urls="https://${DOMAIN}"
  if [[ -n "$WWW_DOMAIN" ]]; then
    client_urls="${client_urls},https://${WWW_DOMAIN}"
  fi

  cat > backend/.env <<EOF_ENV
DATABASE_URL="file:${PROJECT_DIR}/database/family-heritage.db"
JWT_SECRET="${jwt_secret}"
JWT_EXPIRES_IN="7d"
PORT=4000
CLIENT_URL="${client_urls}"
UPLOAD_DIR="${PROJECT_DIR}/uploads"
ADMIN_EMAIL="${ADMIN_EMAIL}"
ADMIN_PASSWORD="${ADMIN_PASSWORD}"
DEFAULT_FAMILY_NAME="Họ Triệu Văn"
EOF_ENV

  cat > frontend/.env.production <<EOF_ENV
VITE_API_URL="/api"
EOF_ENV
}

install_system_dependencies() {
  export DEBIAN_FRONTEND=noninteractive
  sudo apt-get update
  sudo apt-get install -y curl ca-certificates gnupg git nginx certbot sqlite3 ufw openssl rsync
  ensure_node
  sudo npm install -g pnpm@11 pm2
}

install_node_dependencies() {
  if ! run_retry 3 pnpm install --frozen-lockfile; then
    pnpm install
  fi
}

database_has_data() {
  [[ -f database/family-heritage.db ]] && \
    sqlite3 database/family-heritage.db "select count(*) from sqlite_master where type='table' and name='User';" | grep -q '^1$' && \
    [[ "$(sqlite3 database/family-heritage.db "select count(*) from User;" 2>/dev/null || echo 0)" -gt 0 ]]
}

migrate_and_seed() {
  mkdir -p database uploads
  pnpm db:migrate
  if database_has_data; then
    pnpm admin:ensure
  else
    pnpm db:seed
    pnpm admin:ensure
  fi
}

build_project() {
  pnpm build
  test -f backend/dist/src/server.js
  test -f frontend/dist/index.html
}

write_http_nginx_config() {
  local server_names="${DOMAIN}${WWW_DOMAIN:+ ${WWW_DOMAIN}}"
  sudo mkdir -p "$DEPLOY_ROOT/frontend/dist" /var/www/letsencrypt
  sudo tee "/etc/nginx/sites-available/${DOMAIN}.conf" >/dev/null <<EOF_NGINX
limit_req_zone \$binary_remote_addr zone=giaphahotrieu_api:10m rate=10r/s;

server {
    listen 80;
    listen [::]:80;
    server_name ${server_names};

    root ${DEPLOY_ROOT}/frontend/dist;
    index index.html;
    client_max_body_size 25M;

    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Permissions-Policy "camera=(), microphone=(), geolocation=()" always;

    location ^~ /.well-known/acme-challenge/ {
        root /var/www/letsencrypt;
        default_type "text/plain";
    }

    location /api/ {
        limit_req zone=giaphahotrieu_api burst=30 nodelay;
        proxy_pass http://127.0.0.1:4000/api/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /uploads/ {
        proxy_pass http://127.0.0.1:4000/uploads/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location ~ /\.(?!well-known) {
        deny all;
    }

    location / {
        try_files \$uri \$uri/ /index.html;
    }
}
EOF_NGINX

  sudo ln -sf "/etc/nginx/sites-available/${DOMAIN}.conf" "/etc/nginx/sites-enabled/${DOMAIN}.conf"
  sudo rm -f /etc/nginx/sites-enabled/default
  sudo nginx -t
  sudo systemctl enable nginx
  sudo systemctl reload nginx
}

write_https_nginx_config() {
  local server_names="${DOMAIN}${WWW_DOMAIN:+ ${WWW_DOMAIN}}"
  sudo tee "/etc/nginx/sites-available/${DOMAIN}.conf" >/dev/null <<EOF_NGINX
limit_req_zone \$binary_remote_addr zone=giaphahotrieu_api:10m rate=10r/s;

server {
    listen 80;
    listen [::]:80;
    server_name ${server_names};

    location ^~ /.well-known/acme-challenge/ {
        root /var/www/letsencrypt;
        default_type "text/plain";
    }

    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name ${server_names};

    root ${DEPLOY_ROOT}/frontend/dist;
    index index.html;

    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;
    ssl_session_tickets off;

    client_max_body_size 25M;

    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Permissions-Policy "camera=(), microphone=(), geolocation=()" always;

    location /api/ {
        limit_req zone=giaphahotrieu_api burst=30 nodelay;
        proxy_pass http://127.0.0.1:4000/api/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /uploads/ {
        proxy_pass http://127.0.0.1:4000/uploads/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location ~* \.(?:css|js|jpg|jpeg|gif|png|webp|ico|svg|woff2?)\$ {
        expires 30d;
        access_log off;
        add_header Cache-Control "public, immutable";
        try_files \$uri =404;
    }

    location ~ /\.(?!well-known) {
        deny all;
    }

    location / {
        try_files \$uri \$uri/ /index.html;
    }
}
EOF_NGINX
}

deploy_frontend_assets() {
  sudo mkdir -p "$DEPLOY_ROOT/frontend/dist"
  sudo rsync -a --delete frontend/dist/ "$DEPLOY_ROOT/frontend/dist/"
  sudo chown -R www-data:www-data "$DEPLOY_ROOT" /var/www/letsencrypt
}

configure_pm2() {
  set -a
  # shellcheck disable=SC1091
  source backend/.env
  set +a
  pm2 startOrReload ecosystem.config.cjs --env production
  pm2 save
  sudo env PATH="$PATH" pm2 startup systemd -u "$USER" --hp "$HOME" >/tmp/giaphahotrieu-pm2-startup.log
  pm2 save
}

configure_firewall() {
  sudo ufw allow OpenSSH
  sudo ufw allow "Nginx Full"
  sudo ufw --force enable
}

issue_ssl() {
  local certbot_args=(certonly --webroot -w /var/www/letsencrypt --non-interactive --agree-tos --keep-until-expiring --expand --cert-name "$DOMAIN" --email "$CERTBOT_EMAIL" -d "$DOMAIN")
  if [[ -n "$WWW_DOMAIN" ]]; then
    certbot_args+=(-d "$WWW_DOMAIN")
  fi

  run_retry 3 sudo certbot "${certbot_args[@]}"
}

wait_for_pm2_api() {
  for _ in {1..30}; do
    if curl -fsS "http://127.0.0.1:4000/api/health" >/dev/null; then
      return
    fi
    pm2 restart giaphahotrieu-api || true
    sleep 2
  done
  return 1
}

verify_system() {
  wait_for_pm2_api
  curl -fsS "https://${DOMAIN}/api/health" >/dev/null
  curl -fsS -X POST "https://${DOMAIN}/api/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"${ADMIN_EMAIL}\",\"password\":\"${ADMIN_PASSWORD}\"}" | grep -q '"success":true'
  curl -fsS "https://${DOMAIN}/" | grep -q "Digital Family Heritage Platform"
}

install_system_dependencies
pull_latest_code
write_env_files
install_node_dependencies
migrate_and_seed
build_project
deploy_frontend_assets
write_http_nginx_config
configure_pm2
configure_firewall
issue_ssl
write_https_nginx_config
sudo systemctl enable certbot.timer
sudo nginx -t
sudo systemctl reload nginx
verify_system

echo "$FINAL_URL"
