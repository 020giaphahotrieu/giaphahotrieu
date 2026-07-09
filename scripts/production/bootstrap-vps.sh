#!/usr/bin/env bash
# =============================================================================
# bootstrap-vps.sh — one-command production deployment for giaphahotrieu.vn
#
# Usage (as root on a fresh or existing Ubuntu 24.04 VPS, from the repo root):
#
#   ./scripts/production/bootstrap-vps.sh            # full deployment
#   ./scripts/production/bootstrap-vps.sh --resume   # finish an interrupted run
#   ./scripts/production/bootstrap-vps.sh --skip-ssl # never attempt certificates
#   ./scripts/production/bootstrap-vps.sh --force    # ignore saved stage state
#
# Design rules (do not break these):
#   * Fully idempotent — running it repeatedly must never break the server.
#   * DNS or SSL problems must NEVER fail the deployment: the site is brought
#     up on HTTP and `pnpm ssl:enable` upgrades to HTTPS later.
#   * No global `set -e`: stages run in `set -Eeo pipefail` subshells and the
#     runner decides whether a failure is fatal (see lib/common.sh).
#   * Every stage logs START / SUCCESS / WARNING / FAILED.
#
# Configuration is environment-driven — see scripts/production/lib/config.sh.
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ORIGINAL_ARGS=("$@")

# shellcheck source=lib/config.sh
source "${SCRIPT_DIR}/lib/config.sh"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
# shellcheck source=lib/dns.sh
source "${SCRIPT_DIR}/lib/dns.sh"
# shellcheck source=lib/nginx.sh
source "${SCRIPT_DIR}/lib/nginx.sh"
# shellcheck source=lib/ssl.sh
source "${SCRIPT_DIR}/lib/ssl.sh"

RESUME_MODE=0
RESUME_SKIPPABLE_STAGES="system_packages swap dependencies build"

usage() {
  cat <<'EOF'
Usage: bootstrap-vps.sh [--resume] [--force] [--skip-ssl] [--help]

  --resume     Resume an unfinished deployment: stages that already completed
               for the current git revision (packages, dependencies, build)
               are skipped; configuration, services and health checks re-run.
  --force      Forget all saved stage state before running.
  --skip-ssl   Do not attempt Let's Encrypt in this run.
  --help       Show this help.

Common environment overrides (see scripts/production/lib/config.sh for all):
  DOMAIN, WWW_DOMAIN, CERTBOT_EMAIL, ADMIN_EMAIL, ADMIN_PASSWORD,
  SERVER_IPV4, DNS_MAX_ATTEMPTS, SKIP_SSL
EOF
}

for arg in "$@"; do
  case "$arg" in
    --resume)   RESUME_MODE=1 ;;
    --force)    GIAPHA_FORCE_STATE_CLEAR=1 ;;
    --skip-ssl) SKIP_SSL=1 ;;
    --help|-h)  usage; exit 0 ;;
    *) printf 'Unknown option: %s\n\n' "$arg"; usage; exit 2 ;;
  esac
done

# =============================================================================
# Stages
# =============================================================================

stage_preflight() {
  cd "$PROJECT_DIR"
  [[ -f package.json && -f ecosystem.config.cjs && -d scripts/production ]] \
    || { echo "This does not look like the giaphahotrieu repository: $PROJECT_DIR"; return 1; }

  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    log_detail "Operating system: ${PRETTY_NAME:-unknown}"
    if [[ "${ID:-}" != "ubuntu" ]]; then
      log_warning "This script targets Ubuntu 24.04; detected '${ID:-unknown}'. Continuing anyway."
    fi
  else
    log_warning "Cannot detect the operating system (/etc/os-release missing). Continuing anyway."
  fi

  local avail_kb
  avail_kb="$(df -Pk "$PROJECT_DIR" | awk 'NR==2 {print $4}')"
  if [[ -n "$avail_kb" && "$avail_kb" -lt 1048576 ]]; then
    log_warning "Less than 1 GB of free disk space ($(( avail_kb / 1024 )) MB). The build may fail."
  fi

  mkdir -p database database/backups uploads logs .deploy
  log_detail "Project directory: $PROJECT_DIR"
  log_detail "Domain: $DOMAIN  (www: ${WWW_DOMAIN:-disabled})"
}

stage_system_packages() {
  export DEBIAN_FRONTEND=noninteractive
  if ! have_cmd apt-get; then
    log_warning "apt-get not found (not a Debian/Ubuntu system?) — skipping package installation."
    return 0
  fi

  retry_backoff 3 5 apt_update
  apt_install curl ca-certificates gnupg git nginx certbot sqlite3 ufw openssl rsync dnsutils

  # Node.js — install/upgrade via NodeSource only when needed.
  local need_node=1 major=0
  if have_cmd node; then
    major="$(node -p 'Number(process.versions.node.split(".")[0])' 2>/dev/null || echo 0)"
    if [[ "$major" -ge "$NODE_MAJOR" ]]; then
      need_node=0
    fi
  fi
  if [[ "$need_node" -eq 1 ]]; then
    log_info "Installing Node.js ${NODE_MAJOR}.x (found: ${major:-none})"
    retry_backoff 3 5 install_nodesource
    apt_install nodejs
    have_cmd node || { echo "node is still missing after installation"; return 1; }
  fi
  log_detail "node $(node --version)"

  # pnpm — pinned so local, CI and server always agree with the lockfile.
  if ! have_cmd pnpm || [[ "$(pnpm --version 2>/dev/null)" != "$PNPM_VERSION" ]]; then
    retry_backoff 3 5 as_root npm install -g "pnpm@${PNPM_VERSION}"
  fi
  log_detail "pnpm $(pnpm --version)"

  # PM2 process manager.
  if ! have_cmd pm2; then
    retry_backoff 3 5 as_root npm install -g pm2
  fi
  log_detail "pm2 $(pm2 --version 2>/dev/null | tail -n 1)"
}

install_nodesource() {
  curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | as_root env DEBIAN_FRONTEND=noninteractive bash -
}

stage_swap() {
  [[ -r /proc/meminfo ]] || { log_detail "No /proc/meminfo (not Linux) — skipping swap setup."; return 0; }
  local swap_kb mem_kb
  swap_kb="$(awk '/^SwapTotal:/ {print $2}' /proc/meminfo)"
  mem_kb="$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)"
  if [[ "${swap_kb:-0}" -gt 0 ]]; then
    log_detail "Swap already present ($(( swap_kb / 1024 )) MB)."
    return 0
  fi
  if [[ "${mem_kb:-0}" -ge 3145728 ]]; then
    log_detail "RAM $(( mem_kb / 1024 )) MB is sufficient; no swap needed."
    return 0
  fi
  log_info "Low RAM ($(( mem_kb / 1024 )) MB) and no swap — creating a 2 GB swapfile so builds cannot OOM."
  as_root fallocate -l 2G /swapfile 2>/dev/null || as_root dd if=/dev/zero of=/swapfile bs=1M count=2048
  as_root chmod 600 /swapfile
  as_root mkswap /swapfile
  as_root swapon /swapfile
  if ! grep -qs '^/swapfile' /etc/fstab; then
    printf '/swapfile none swap sw 0 0\n' | as_root tee -a /etc/fstab >/dev/null
  fi
}

stage_repo_sync() {
  if [[ "${GIAPHA_SKIP_SYNC}" == "1" ]]; then
    log_detail "Repository was already synchronised by the caller (GIAPHA_SKIP_SYNC=1)."
    return 0
  fi
  if [[ "$RESUME_MODE" -eq 1 ]]; then
    log_detail "Resume mode keeps the current revision (no git pull)."
    return 0
  fi
  if [[ ! -d .git ]]; then
    log_detail "Not a git checkout — deploying the code as present on disk."
    return 0
  fi
  if ! have_cmd git; then
    log_detail "git not available — skipping repository sync."
    return 0
  fi

  # Root often differs from the clone owner on a VPS.
  if ! git config --global --get-all safe.directory 2>/dev/null | grep -qxF "$PROJECT_DIR"; then
    git config --global --add safe.directory "$PROJECT_DIR" 2>/dev/null || true
  fi

  local pre_hash
  pre_hash="$(file_sha256 "${SCRIPT_DIR}/bootstrap-vps.sh" "${SCRIPT_DIR}"/lib/*.sh)"

  # The production database and any local edits must survive every sync.
  local db="database/family-heritage.db" db_backup=""
  if [[ -f "$db" ]]; then
    db_backup=".deploy/pre-sync-db.backup"
    cp -f "$db" "$db_backup"
  fi
  if ! git diff --quiet HEAD 2>/dev/null; then
    local patch=".deploy/local-changes-$(date +%Y%m%d-%H%M%S).patch"
    git diff HEAD > "$patch" 2>/dev/null || true
    log_warning "Local changes to tracked files were found; saved to ${patch} before resetting to origin/main."
  fi

  if ! retry_backoff 3 5 git fetch origin main; then
    log_plain "Could not reach the git remote; deploying the code as present on disk."
    return 1
  fi
  # Clear the legacy skip-worktree bit so git behaves predictably.
  git update-index --no-skip-worktree "$db" 2>/dev/null || true
  git checkout -f -B main origin/main
  git reset --hard origin/main

  # If the sync deleted the database (e.g. the commit that untracked it),
  # restore it immediately. git may also have pruned the empty directory.
  if [[ -n "$db_backup" && ! -f "$db" ]]; then
    mkdir -p "$(dirname "$db")"
    cp -f "$db_backup" "$db"
    log_info "Restored ${db} after git removed it from version control."
  fi
  chmod +x scripts/production/*.sh 2>/dev/null || true

  local post_hash
  post_hash="$(file_sha256 "${SCRIPT_DIR}/bootstrap-vps.sh" "${SCRIPT_DIR}"/lib/*.sh)"
  if [[ -n "$pre_hash" && "$pre_hash" != "$post_hash" ]]; then
    touch .deploy/needs-reexec
    log_info "Deployment scripts changed during sync — the deployment will restart with the new version."
  fi
  log_detail "Now at revision $(git rev-parse --short HEAD 2>/dev/null || echo '?')."
}

stage_env_files() {
  local env_file="backend/.env"

  # Preserve secrets across runs: explicit environment > existing file > generated.
  local jwt_secret admin_email admin_password family_name
  jwt_secret="${JWT_SECRET:-}"
  if [[ -z "$jwt_secret" ]]; then
    jwt_secret="$(env_file_get "$env_file" JWT_SECRET || true)"
  fi
  if [[ -z "$jwt_secret" || "$jwt_secret" == *change* || "$jwt_secret" == *dev-only* ]]; then
    jwt_secret="$(random_secret_hex 48)"
    log_info "Generated a new JWT_SECRET (stored in backend/.env)."
  fi

  admin_email="${ADMIN_EMAIL:-}"
  if [[ -z "$admin_email" ]]; then
    admin_email="$(env_file_get "$env_file" ADMIN_EMAIL || true)"
  fi
  if [[ -z "$admin_email" ]]; then
    admin_email="admin@example.com"
  fi

  admin_password="${ADMIN_PASSWORD:-}"
  if [[ -z "$admin_password" ]]; then
    admin_password="$(env_file_get "$env_file" ADMIN_PASSWORD || true)"
  fi
  if [[ -z "$admin_password" ]]; then
    admin_password="$(random_password)"
    log_info "Generated an initial admin password (stored in backend/.env — read it with: grep ADMIN_PASSWORD backend/.env)."
  fi

  family_name="$DEFAULT_FAMILY_NAME"
  if [[ "$family_name" == "Họ Triệu Văn" ]]; then
    local file_family
    file_family="$(env_file_get "$env_file" DEFAULT_FAMILY_NAME || true)"
    if [[ -n "$file_family" ]]; then
      family_name="$file_family"
    fi
  fi

  local client_urls="https://${DOMAIN}"
  if [[ -n "$WWW_DOMAIN" ]]; then
    client_urls="${client_urls},https://${WWW_DOMAIN}"
  fi

  cat > "$env_file" <<EOF_ENV
# Generated by scripts/production/bootstrap-vps.sh — values are preserved
# across deployments (edit here, then run: pm2 startOrReload ecosystem.config.cjs --env production).
NODE_ENV="production"
DATABASE_URL="file:${PROJECT_DIR}/database/family-heritage.db"
JWT_SECRET="${jwt_secret}"
JWT_EXPIRES_IN="7d"
HOST="${APP_HOST}"
PORT=${APP_PORT}
CLIENT_URL="${client_urls}"
UPLOAD_DIR="${PROJECT_DIR}/uploads"
ADMIN_EMAIL="${admin_email}"
ADMIN_PASSWORD="${admin_password}"
DEFAULT_FAMILY_NAME="${family_name}"
EOF_ENV
  chmod 600 "$env_file"
  log_detail "backend/.env written (mode 600)."

  cat > frontend/.env.production <<'EOF_ENV'
VITE_API_URL="/api"
EOF_ENV
  log_detail "frontend/.env.production written."
}

stage_dependencies() {
  if ! retry_backoff 2 10 pnpm install --frozen-lockfile; then
    log_warning "pnpm install --frozen-lockfile failed; retrying without the frozen lockfile."
    pnpm install
  fi
}

database_has_data() {
  [[ -f database/family-heritage.db ]] \
    && [[ "$(sqlite3 database/family-heritage.db "select count(*) from sqlite_master where type='table' and name='User';" 2>/dev/null || echo 0)" == "1" ]] \
    && [[ "$(sqlite3 database/family-heritage.db "select count(*) from User;" 2>/dev/null || echo 0)" -gt 0 ]]
}

stage_database() {
  mkdir -p database database/backups uploads

  if [[ -f database/family-heritage.db ]]; then
    local backup="database/backups/pre-deploy-$(date +%Y%m%d-%H%M%S).db"
    if have_cmd sqlite3; then
      sqlite3 database/family-heritage.db ".backup '${backup}'" 2>/dev/null \
        || cp -f database/family-heritage.db "$backup"
    else
      cp -f database/family-heritage.db "$backup"
    fi
    log_detail "Database backed up to ${backup}."
    # Keep the 14 most recent automatic backups.
    (cd database/backups 2>/dev/null && ls -1t pre-deploy-*.db 2>/dev/null | tail -n +15 | while read -r old; do rm -f "$old"; done) || true
  fi

  pnpm db:migrate
  if database_has_data; then
    log_detail "Database already contains data — seed skipped (existing data preserved)."
  else
    log_info "Empty database detected — loading seed data."
    pnpm db:seed
  fi
  pnpm admin:ensure
}

stage_build() {
  pnpm build
  [[ -f backend/dist/src/server.js ]] || { echo "backend build artifact missing: backend/dist/src/server.js"; return 1; }
  [[ -f frontend/dist/index.html ]]   || { echo "frontend build artifact missing: frontend/dist/index.html"; return 1; }
  log_detail "Build artifacts verified."
}

stage_frontend_assets() {
  ensure_dir_root "$DEPLOY_ROOT/frontend/dist" "$ACME_WEBROOT"
  as_root rsync -a --delete frontend/dist/ "$DEPLOY_ROOT/frontend/dist/"
  if id www-data >/dev/null 2>&1; then
    as_root chown -R www-data:www-data "$DEPLOY_ROOT" "$ACME_WEBROOT"
  fi
  log_detail "Frontend published to ${DEPLOY_ROOT}/frontend/dist."
}

stage_nginx_site() {
  local mode="http"
  if ssl_cert_exists; then
    mode="https"
    log_detail "Existing certificate found — keeping the site on HTTPS."
  fi
  nginx_render_site "$mode"
  nginx_test_and_reload
}

stage_pm2_service() {
  pm2 startOrReload ecosystem.config.cjs --env production --update-env
  pm2 save

  # Survive reboots. `pm2 startup` executes the systemd setup itself when
  # running as root; for sudo users we pass the PATH through explicitly.
  local user home
  user="$(id -un)"
  home="${HOME:-$(eval echo "~${user}")}"
  if [[ "$GIAPHA_IS_ROOT" -eq 1 ]]; then
    pm2 startup systemd -u "$user" --hp "$home" >/dev/null 2>&1 \
      || log_warning "pm2 startup could not configure systemd (container without systemd?). The app will not auto-start after a reboot."
  else
    sudo env PATH="$PATH" pm2 startup systemd -u "$user" --hp "$home" >/dev/null 2>&1 \
      || log_warning "pm2 startup could not configure systemd. The app will not auto-start after a reboot."
  fi
  pm2 save

  # Log rotation for PM2 logs (best effort — not critical for serving traffic).
  if [[ ! -d "${home}/.pm2/modules/pm2-logrotate" ]]; then
    if pm2 install pm2-logrotate >/dev/null 2>&1; then
      pm2 set pm2-logrotate:max_size 10M >/dev/null 2>&1 || true
      pm2 set pm2-logrotate:retain 14 >/dev/null 2>&1 || true
    else
      log_warning "pm2-logrotate could not be installed; PM2 logs will grow unbounded until it is added."
    fi
  fi
}

stage_firewall() {
  if ! have_cmd ufw; then
    log_plain "ufw is not installed — firewall left unchanged."
    return 1
  fi
  as_root ufw allow OpenSSH >/dev/null 2>&1 || as_root ufw allow 22/tcp
  as_root ufw allow "Nginx Full" >/dev/null 2>&1 || { as_root ufw allow 80/tcp; as_root ufw allow 443/tcp; }
  as_root ufw --force enable
  log_detail "Firewall active: OpenSSH + HTTP/HTTPS allowed."
}

stage_dns_check() {
  rm -f .deploy/dns.env

  detect_public_ipv4 || true
  detect_public_ipv6 || true

  local ready=0 www_ready=0 verdict="UNKNOWN"
  if [[ -z "${SERVER_IPV4:-}" ]]; then
    log_warning "Server public IPv4 unknown — cannot verify DNS. Set SERVER_IPV4=<ip> and re-run, or run 'pnpm ssl:enable' later."
  elif ! dns_tools_available; then
    dns_inspect "$DOMAIN" "${SERVER_IPV4}" || true   # produces the NO_TOOLS verdict
    verdict="$DNS_VERDICT"
    dns_print_report "$DOMAIN" "${SERVER_IPV4}" || true
  else
    log_info "Verifying DNS for ${DOMAIN} → ${SERVER_IPV4} (up to ${DNS_MAX_ATTEMPTS} attempts, exponential backoff from ${DNS_INITIAL_DELAY}s)..."
    if dns_wait_until_ready "$DOMAIN" "$SERVER_IPV4" "$DNS_MAX_ATTEMPTS" "$DNS_INITIAL_DELAY"; then
      ready=1
    fi
    verdict="$DNS_VERDICT"
    dns_print_report "$DOMAIN" "$SERVER_IPV4" || true

    if [[ "$ready" -eq 1 && -n "$WWW_DOMAIN" ]]; then
      dns_inspect "$WWW_DOMAIN" "$SERVER_IPV4" || true
      if [[ "$DNS_VERDICT" == "OK" ]]; then
        www_ready=1
      else
        log_warning "${WWW_DOMAIN} is not ready (${DNS_VERDICT}) — the certificate will cover ${DOMAIN} only. Re-run 'pnpm ssl:enable' after adding the www A record to include it."
      fi
    fi
  fi

  {
    printf 'DNS_READY=%s\n' "$ready"
    printf 'WWW_READY=%s\n' "$www_ready"
    printf 'DNS_LAST_VERDICT=%s\n' "$verdict"
    printf 'DETECTED_IPV4=%s\n' "${SERVER_IPV4:-}"
  } > .deploy/dns.env

  # Not ready → report the stage as WARNING (never fatal by design).
  [[ "$ready" -eq 1 ]]
}

stage_ssl() {
  # Re-read the DNS results (the dns_check stage ran in a subshell).
  DNS_READY=0; WWW_READY=0
  if [[ -f .deploy/dns.env ]]; then
    # shellcheck disable=SC1091
    source .deploy/dns.env
  fi

  if [[ "$SKIP_SSL" == "1" ]]; then
    log_detail "SKIP_SSL=1 — certificate issuance skipped on request."
    return 0
  fi
  if [[ "${DNS_READY:-0}" != "1" ]]; then
    if ssl_cert_exists; then
      log_detail "DNS is not verifiable right now, but a certificate already exists — HTTPS stays active."
      return 0
    fi
    log_plain "DNS is not ready — the site stays on HTTP for now. Run 'pnpm ssl:enable' once DNS points here."
    return 1
  fi

  local names=("$DOMAIN")
  if [[ -n "$WWW_DOMAIN" && "${WWW_READY:-0}" == "1" ]]; then
    names+=("$WWW_DOMAIN")
  fi
  log_info "Requesting Let's Encrypt certificate for: ${names[*]}"
  ssl_issue_certificate "${names[@]}"
  ssl_install_renewal_hook
  ssl_activate_https
  log_detail "HTTPS is active for ${names[*]}."
}

stage_verify() {
  local i healthy=0
  log_detail "Waiting for the API on 127.0.0.1:${APP_PORT}..."
  for i in $(seq 1 30); do
    if curl -fsS --max-time 4 "http://127.0.0.1:${APP_PORT}/api/health" >/dev/null 2>&1; then
      healthy=1
      break
    fi
    sleep 2
  done
  if [[ "$healthy" -ne 1 ]]; then
    echo "The API did not become healthy within 60s. PM2 status and recent logs:"
    pm2 describe "$PM2_APP_NAME" 2>/dev/null || true
    pm2 logs "$PM2_APP_NAME" --nostream --lines 40 2>/dev/null || true
    return 1
  fi
  log_detail "API healthy on 127.0.0.1:${APP_PORT}."

  curl -fsS --max-time 8 -H "Host: ${DOMAIN}" "http://127.0.0.1/api/health" >/dev/null
  log_detail "API reachable through nginx."

  local front
  front="$(curl -fsS --max-time 8 -H "Host: ${DOMAIN}" "http://127.0.0.1/")"
  printf '%s' "$front" | grep -q "Digital Family Heritage Platform" \
    || { echo "The frontend served by nginx does not look like the app (missing title)."; return 1; }
  log_detail "Frontend served by nginx."

  if nginx_site_is_https && ssl_cert_exists; then
    curl -fsS --max-time 10 --resolve "${DOMAIN}:443:127.0.0.1" "https://${DOMAIN}/api/health" >/dev/null \
      && log_detail "HTTPS endpoint verified (certificate valid for ${DOMAIN})." \
      || log_warning "HTTPS is configured but the local HTTPS check failed — inspect 'nginx -t' and the certificate."
  fi

  # Login smoke test — non-fatal: the admin may have changed the password.
  local admin_email admin_password login_out=""
  admin_email="$(env_file_get backend/.env ADMIN_EMAIL || true)"
  admin_password="$(env_file_get backend/.env ADMIN_PASSWORD || true)"
  if [[ -n "$admin_email" && -n "$admin_password" ]]; then
    login_out="$(curl -fsS --max-time 8 -X POST "http://127.0.0.1:${APP_PORT}/api/auth/login" \
      -H "Content-Type: application/json" \
      -d "{\"email\":\"${admin_email}\",\"password\":\"${admin_password}\"}" 2>/dev/null || true)"
    if printf '%s' "$login_out" | grep -q '"success":true'; then
      log_detail "Admin login verified (${admin_email})."
    else
      log_warning "Admin login smoke test failed for ${admin_email}. If the password was changed in the app this is expected."
    fi
  fi
}

# =============================================================================
# Summary
# =============================================================================

print_summary() {
  local https_active=0
  if nginx_site_is_https && ssl_cert_exists; then
    https_active=1
  fi
  DNS_READY="${DNS_READY:-0}"
  # shellcheck disable=SC1091
  [[ -f .deploy/dns.env ]] && source .deploy/dns.env

  echo
  hr
  log_plain "${C_BOLD}DEPLOYMENT SUMMARY — ${DOMAIN} (deploy scripts v${GIAPHA_DEPLOY_VERSION})${C_RESET}"
  hr
  print_stage_results
  hr

  if [[ -n "$GIAPHA_FATAL_STAGE" ]]; then
    log_failed "Deployment FAILED at stage '${GIAPHA_FATAL_STAGE}'."
    log_plain  "  Full log : ${GIAPHA_LOG_FILE:-logs/}"
    log_plain  "  Fix the cause above, then continue with:  pnpm deploy:resume"
    return 0
  fi

  local warning_count=0
  if [[ -n "${GIAPHA_LOG_FILE:-}" && -f "${GIAPHA_LOG_FILE:-}" ]]; then
    warning_count="$(grep -c '\[WARNING\]' "$GIAPHA_LOG_FILE" 2>/dev/null || echo 0)"
  fi
  if [[ "$warning_count" -gt 0 ]]; then
    log_plain "${C_YELLOW}${warning_count} warning(s) occurred — details above in the log.${C_RESET}"
  fi

  if [[ "$https_active" -eq 1 ]]; then
    log_success "Deployment completed — the site is LIVE on HTTPS."
    log_plain   ""
    log_plain   "  ${C_BOLD}https://${DOMAIN}${C_RESET}"
  elif [[ "${DNS_READY:-0}" != "1" ]]; then
    log_success "Deployment completed (HTTP mode)."
    log_plain ""
    log_plain "${C_BOLD}DNS is not propagated yet."
    log_plain "HTTP deployment completed successfully."
    log_plain "Run 'pnpm ssl:enable' after DNS becomes available.${C_RESET}"
    log_plain ""
    if [[ -n "${DETECTED_IPV4:-${SERVER_IPV4:-}}" ]]; then
      log_plain "  Until then the site is reachable at:  http://${DETECTED_IPV4:-${SERVER_IPV4}}"
      log_plain "  Required DNS records (at your DNS provider):"
      log_plain "      A    @      ${DETECTED_IPV4:-${SERVER_IPV4}}"
      log_plain "      A    www    ${DETECTED_IPV4:-${SERVER_IPV4}}"
    fi
  else
    log_warning "Deployment completed on HTTP, but certificate issuance failed although DNS looks ready."
    log_plain   "  Retry with:  pnpm ssl:enable   (details in the log: ${GIAPHA_LOG_FILE:-logs/})"
  fi

  local admin_email
  admin_email="$(env_file_get backend/.env ADMIN_EMAIL 2>/dev/null || true)"
  log_plain ""
  log_plain "  Admin login   : ${admin_email:-see backend/.env} (password: grep ADMIN_PASSWORD backend/.env)"
  log_plain "  App status    : pm2 status ${PM2_APP_NAME}   |   logs: pm2 logs ${PM2_APP_NAME}"
  log_plain "  Deployment log: ${GIAPHA_LOG_FILE:-logs/}"
  hr
}

# =============================================================================
# Main
# =============================================================================

main() {
  cd "$PROJECT_DIR"
  mkdir -p logs .deploy
  init_logging "$PROJECT_DIR" "deploy"
  trap 'log_failed "Deployment interrupted."; exit 130' INT TERM

  echo
  hr
  log_plain "${C_BOLD}Gia Pha Ho Trieu — production deployment v${GIAPHA_DEPLOY_VERSION}${C_RESET}"
  log_plain "  Domain : ${DOMAIN}${WWW_DOMAIN:+ (+ ${WWW_DOMAIN})}"
  log_plain "  Mode   : $([[ "$RESUME_MODE" -eq 1 ]] && echo resume || echo full)$([[ "$SKIP_SSL" == "1" ]] && echo ' (ssl skipped)')"
  log_plain "  User   : $(id -un)  |  Host: $(hostname 2>/dev/null || echo '?')  |  $(date)"
  hr

  require_root_or_sudo || exit 1

  if [[ "${GIAPHA_FORCE_STATE_CLEAR:-0}" == "1" ]]; then
    state_clear
    log_info "Saved stage state cleared (--force)."
  fi

  stage_register preflight        required "Preflight checks"
  stage_register system_packages  required "System packages (nginx, certbot, node, pnpm, pm2)"
  stage_register swap             optional "Swap space"
  stage_register repo_sync        optional "Repository sync"
  stage_register env_files        required "Environment files"
  stage_register dependencies     required "Node dependencies"
  stage_register database         required "Database migration and seed"
  stage_register build            required "Build (backend + frontend)"
  stage_register frontend_assets  required "Publish frontend assets"
  stage_register nginx_site       required "Nginx site configuration"
  stage_register pm2_service      required "PM2 service and boot persistence"
  stage_register firewall         optional "Firewall (ufw)"
  stage_register dns_check        optional "DNS readiness check"
  stage_register ssl              optional "Let's Encrypt certificate"
  stage_register verify           required "Health verification"
  GIAPHA_STAGE_TOTAL=${#GIAPHA_STAGES[@]}

  local entry id mode desc fatal=0 stage_rc=0
  for entry in "${GIAPHA_STAGES[@]}"; do
    id="${entry%%|*}"
    desc="${entry##*|}"
    mode="${entry#*|}"; mode="${mode%%|*}"
    # Plain call + $? capture: `if ! run_stage` would disable `set -e` inside
    # the stage subshell (bash ignores errexit in condition contexts).
    run_stage "$id" "$mode" "$desc"
    stage_rc=$?
    if [[ "$stage_rc" -ne 0 ]]; then
      fatal=1
      break
    fi
    if [[ "$id" == "repo_sync" && -f .deploy/needs-reexec ]]; then
      rm -f .deploy/needs-reexec
      if [[ "${GIAPHA_REEXEC:-0}" != "1" ]]; then
        log_info "Restarting the deployment with the updated scripts..."
        exec env GIAPHA_REEXEC=1 GIAPHA_SKIP_SYNC=1 bash "${SCRIPT_DIR}/bootstrap-vps.sh" ${ORIGINAL_ARGS[@]+"${ORIGINAL_ARGS[@]}"}
      fi
    fi
  done

  print_summary
  exit "$fatal"
}

main
