# =============================================================================
# config.sh — central configuration for the production deployment scripts.
#
# Sourced by bootstrap-vps.sh and enable-ssl.sh. Every value can be overridden
# through the environment, e.g.:
#
#   DOMAIN=example.com WWW_DOMAIN= ./scripts/production/bootstrap-vps.sh
#
# This file must stay side-effect free (variable assignments only).
# =============================================================================

GIAPHA_DEPLOY_VERSION="2.0.0"

# --- Site -------------------------------------------------------------------
DOMAIN="${DOMAIN:-giaphahotrieu.vn}"
# www is included by default; set WWW_DOMAIN= (empty) to disable it entirely.
WWW_DOMAIN="${WWW_DOMAIN-www.${DOMAIN}}"
CERTBOT_EMAIL="${CERTBOT_EMAIL:-admin@${DOMAIN}}"

# --- Application ------------------------------------------------------------
APP_PORT="${APP_PORT:-4000}"
APP_HOST="${APP_HOST:-127.0.0.1}"
PM2_APP_NAME="${PM2_APP_NAME:-giaphahotrieu-api}"
DEFAULT_FAMILY_NAME="${DEFAULT_FAMILY_NAME:-Họ Triệu Văn}"
# Admin bootstrap credentials. When empty, existing values in backend/.env are
# kept; a strong random password is generated on the very first deployment.
ADMIN_EMAIL="${ADMIN_EMAIL:-}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-}"

# --- Toolchain --------------------------------------------------------------
NODE_MAJOR="${NODE_MAJOR:-22}"
PNPM_VERSION="${PNPM_VERSION:-11.7.0}"

# --- Filesystem layout ------------------------------------------------------
DEPLOY_ROOT="${DEPLOY_ROOT:-/var/www/${DOMAIN}}"
ACME_WEBROOT="${ACME_WEBROOT:-/var/www/letsencrypt}"
NGINX_AVAILABLE_DIR="${NGINX_AVAILABLE_DIR:-/etc/nginx/sites-available}"
NGINX_ENABLED_DIR="${NGINX_ENABLED_DIR:-/etc/nginx/sites-enabled}"
LETSENCRYPT_LIVE_DIR="${LETSENCRYPT_LIVE_DIR:-/etc/letsencrypt/live}"
LETSENCRYPT_HOOK_DIR="${LETSENCRYPT_HOOK_DIR:-/etc/letsencrypt/renewal-hooks/deploy}"

# --- DNS checking -----------------------------------------------------------
# Space separated list of public resolvers used to observe propagation.
DNS_RESOLVERS="${DNS_RESOLVERS:-1.1.1.1 8.8.8.8}"
# Exponential backoff: attempts and initial delay (seconds, doubles, capped).
DNS_MAX_ATTEMPTS="${DNS_MAX_ATTEMPTS:-4}"
DNS_INITIAL_DELAY="${DNS_INITIAL_DELAY:-10}"
DNS_MAX_DELAY="${DNS_MAX_DELAY:-60}"
# Public IPv4 of this server. Auto-detected when empty.
SERVER_IPV4="${SERVER_IPV4:-}"
SERVER_IPV6="${SERVER_IPV6:-}"

# --- Behaviour toggles ------------------------------------------------------
SKIP_SSL="${SKIP_SSL:-0}"          # 1 = never attempt certificate issuance
GIAPHA_SKIP_SYNC="${GIAPHA_SKIP_SYNC:-0}"  # 1 = do not git-sync (set by install.sh)
