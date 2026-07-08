#!/usr/bin/env bash
set -Eeuo pipefail

DOMAIN="${DOMAIN:-giaphahotrieu.vn}"
WWW_DOMAIN="${WWW_DOMAIN:-}"
CERTBOT_EMAIL="${CERTBOT_EMAIL:-admin@giaphahotrieu.vn}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@example.com}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-Admin@123456}"
NODE_MAJOR_REQUIRED="${NODE_MAJOR_REQUIRED:-20}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEPLOY_ROOT="${DEPLOY_ROOT:-/var/www/${DOMAIN}}"
ACME_WEBROOT="${ACME_WEBROOT:-/var/www/letsencrypt}"
NGINX_AVAILABLE_DIR="${NGINX_AVAILABLE_DIR:-/etc/nginx/sites-available}"
NGINX_ENABLED_DIR="${NGINX_ENABLED_DIR:-/etc/nginx/sites-enabled}"
LETSENCRYPT_LIVE_DIR="${LETSENCRYPT_LIVE_DIR:-/etc/letsencrypt/live}"
PM2_STARTUP_LOG="${PM2_STARTUP_LOG:-/tmp/giaphahotrieu-pm2-startup.log}"
LOG_FILE="${PROJECT_DIR}/deploy-production.log"
FINAL_URL="https://${DOMAIN}"

mkdir -p "$(dirname "$LOG_FILE")"
: >"$LOG_FILE"

on_error() {
  local line="$1"
  local command="$2"
  local exit_code="$3"
  echo "ERROR: deploy failed"
  echo "ERROR: line=${line}"
  echo "ERROR: exit_code=${exit_code}"
  echo "ERROR: command=${command}"
  echo "ERROR: log=${LOG_FILE}"
  exit "$exit_code"
}

if [[ "$(id -u)" -eq 0 ]]; then
  sudo() {
    while [[ "$#" -gt 0 && "$1" == -* ]]; do
      shift
    done
    "$@"
  }
fi

log_step() {
  echo
  echo "==> $*"
}

ensure_dir() {
  local dir="$1"
  sudo mkdir -p "$dir"
}

chown_dir_if_exists() {
  local owner="$1"
  shift
  local dir
  for dir in "$@"; do
    if [[ -d "$dir" ]]; then
      sudo chown -R "$owner" "$dir"
    fi
  done
}

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
  log_step "Pulling latest code"
  if [[ -d .git ]]; then
    git config --global --add safe.directory "$PROJECT_DIR" || true
    git update-index --skip-worktree database/family-heritage.db 2>/dev/null || true
    git fetch --all --prune || true
    git pull --ff-only || git pull --rebase --autostash || true
  fi
}

write_env_files() {
  log_step "Writing environment files"
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
  log_step "Installing system dependencies"
  export DEBIAN_FRONTEND=noninteractive
  sudo apt-get update
  sudo apt-get install -y curl ca-certificates gnupg git nginx certbot sqlite3 ufw openssl rsync
  ensure_node
  sudo npm install -g pnpm@11 pm2
}

install_node_dependencies() {
  log_step "Installing node dependencies"
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
  log_step "Migrating and seeding database"
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
  log_step "Building frontend and backend"
  pnpm build
  test -f backend/dist/src/server.js
  test -f frontend/dist/index.html
}

write_http_nginx_config() {
  log_step "Writing temporary HTTP Nginx config"
  local server_names="${DOMAIN}${WWW_DOMAIN:+ ${WWW_DOMAIN}}"
  ensure_dir "$DEPLOY_ROOT/frontend/dist"
  ensure_dir "$ACME_WEBROOT"
  ensure_dir "$NGINX_AVAILABLE_DIR"
  ensure_dir "$NGINX_ENABLED_DIR"
  sudo tee "${NGINX_AVAILABLE_DIR}/${DOMAIN}.conf" >/dev/null <<EOF_NGINX
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
        root ${ACME_WEBROOT};
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

  sudo ln -sf "${NGINX_AVAILABLE_DIR}/${DOMAIN}.conf" "${NGINX_ENABLED_DIR}/${DOMAIN}.conf"
  sudo rm -f "${NGINX_ENABLED_DIR}/default"
  sudo nginx -t
  sudo systemctl enable nginx
  sudo systemctl reload nginx
}

write_https_nginx_config() {
  local server_names="${DOMAIN}${WWW_DOMAIN:+ ${WWW_DOMAIN}}"
  ensure_dir "$NGINX_AVAILABLE_DIR"
  ensure_dir "$NGINX_ENABLED_DIR"
  sudo tee "${NGINX_AVAILABLE_DIR}/${DOMAIN}.conf" >/dev/null <<EOF_NGINX
limit_req_zone \$binary_remote_addr zone=giaphahotrieu_api:10m rate=10r/s;

server {
    listen 80;
    listen [::]:80;
    server_name ${server_names};

    location ^~ /.well-known/acme-challenge/ {
        root ${ACME_WEBROOT};
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

    ssl_certificate ${LETSENCRYPT_LIVE_DIR}/${DOMAIN}/fullchain.pem;
    ssl_certificate_key ${LETSENCRYPT_LIVE_DIR}/${DOMAIN}/privkey.pem;
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
  log_step "Deploying frontend assets"
  ensure_dir "$DEPLOY_ROOT/frontend/dist"
  ensure_dir "$ACME_WEBROOT"
  sudo rsync -a --delete frontend/dist/ "$DEPLOY_ROOT/frontend/dist/"
  chown_dir_if_exists www-data:www-data "$DEPLOY_ROOT" "$ACME_WEBROOT"
}

configure_pm2() {
  log_step "Configuring PM2"
  set -a
  # shellcheck disable=SC1091
  source backend/.env
  set +a
  pm2 startOrReload ecosystem.config.cjs --env production
  pm2 save
  sudo env PATH="$PATH" pm2 startup systemd -u "$USER" --hp "$HOME" >"$PM2_STARTUP_LOG"
  pm2 save
}

configure_firewall() {
  log_step "Configuring firewall"
  sudo ufw allow OpenSSH
  sudo ufw allow "Nginx Full"
  sudo ufw --force enable
}

issue_ssl() {
  log_step "Issuing SSL certificate"
  ensure_dir "$ACME_WEBROOT"
  local certbot_args=(certonly --webroot -w "$ACME_WEBROOT" --non-interactive --agree-tos --keep-until-expiring --expand --cert-name "$DOMAIN" --email "$CERTBOT_EMAIL" -d "$DOMAIN")
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
  log_step "Verifying system health"
  wait_for_pm2_api
  curl -fsS "https://${DOMAIN}/api/health" >/dev/null
  curl -fsS -X POST "https://${DOMAIN}/api/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"${ADMIN_EMAIL}\",\"password\":\"${ADMIN_PASSWORD}\"}" | grep -q '"success":true'
  curl -fsS "https://${DOMAIN}/" | grep -q "Digital Family Heritage Platform"
}

main() {
  trap 'on_error "$LINENO" "$BASH_COMMAND" "$?"' ERR
  cd "$PROJECT_DIR"
  log_step "Starting production bootstrap for ${DOMAIN}"
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
}

main "$@" 2>&1 | tee -a "$LOG_FILE"
exit "${PIPESTATUS[0]}"
