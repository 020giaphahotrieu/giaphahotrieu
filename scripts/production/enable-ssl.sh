#!/usr/bin/env bash
# =============================================================================
# enable-ssl.sh — upgrade an HTTP-only deployment to HTTPS.
#
#   pnpm ssl:enable        (or: ./scripts/production/enable-ssl.sh)
#
# Does exactly four things:
#   1. verifies DNS points at this server (with clear diagnosis when it doesn't)
#   2. obtains/renews the Let's Encrypt certificate (webroot challenge)
#   3. switches nginx to the HTTPS configuration
#   4. reloads nginx and verifies the HTTPS endpoint
#
# It never reinstalls or rebuilds the application. Safe to run repeatedly.
# Run scripts/production/bootstrap-vps.sh (pnpm deploy) first.
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

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

usage() {
  cat <<'EOF'
Usage: enable-ssl.sh [--help]

Verifies DNS, obtains a Let's Encrypt certificate and switches nginx to HTTPS.
Environment overrides: DOMAIN, WWW_DOMAIN, CERTBOT_EMAIL, SERVER_IPV4,
DNS_MAX_ATTEMPTS, DNS_INITIAL_DELAY (see scripts/production/lib/config.sh).
EOF
}

for arg in "$@"; do
  case "$arg" in
    --help|-h) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n\n' "$arg"; usage; exit 2 ;;
  esac
done

WWW_READY=0

stage_ssl_preflight() {
  cd "$PROJECT_DIR"
  mkdir -p logs .deploy

  if [[ ! -f "$(nginx_site_conf)" ]]; then
    echo "The nginx site for ${DOMAIN} is not configured yet."
    echo "Run the deployment first:  ./scripts/production/bootstrap-vps.sh"
    return 1
  fi
  if ! have_cmd certbot; then
    log_info "certbot is missing — installing it now."
    retry_backoff 3 5 apt_update
    apt_install certbot
  fi
  if ! dns_tools_available; then
    log_info "dig is missing — installing dnsutils."
    apt_install dnsutils
  fi
  ensure_dir_root "$ACME_WEBROOT"
  log_detail "Preconditions satisfied (nginx site present, certbot available)."
}

stage_ssl_dns_verify() {
  detect_public_ipv4 || true
  detect_public_ipv6 || true
  if [[ -z "${SERVER_IPV4:-}" ]]; then
    echo "Could not determine this server's public IPv4 address."
    echo "Re-run with the address set explicitly:  SERVER_IPV4=<ip> pnpm ssl:enable"
    return 1
  fi

  log_info "Verifying DNS for ${DOMAIN} → ${SERVER_IPV4} (up to ${DNS_MAX_ATTEMPTS} attempts, exponential backoff)..."
  if ! dns_wait_until_ready "$DOMAIN" "$SERVER_IPV4" "$DNS_MAX_ATTEMPTS" "$DNS_INITIAL_DELAY"; then
    dns_print_report "$DOMAIN" "$SERVER_IPV4" || true
    echo "DNS is not ready yet — no certificate was requested. Fix the records above and run 'pnpm ssl:enable' again."
    return 1
  fi
  dns_print_report "$DOMAIN" "$SERVER_IPV4" || true

  if [[ -n "$WWW_DOMAIN" ]]; then
    dns_inspect "$WWW_DOMAIN" "$SERVER_IPV4" || true
    if [[ "$DNS_VERDICT" == "OK" ]]; then
      WWW_READY=1
      echo "WWW_READY=1" > .deploy/ssl-www.env
    else
      rm -f .deploy/ssl-www.env
      log_warning "${WWW_DOMAIN} does not resolve to this server (${DNS_VERDICT}) — the certificate will cover ${DOMAIN} only. Add 'A www ${SERVER_IPV4}' and re-run 'pnpm ssl:enable' to include it."
    fi
  fi
}

stage_ssl_issue() {
  # Stage subshells cannot pass variables back — re-read the www decision.
  local www_ready=0
  if [[ -f .deploy/ssl-www.env ]]; then
    www_ready=1
  fi

  local names=("$DOMAIN")
  if [[ -n "$WWW_DOMAIN" && "$www_ready" -eq 1 ]]; then
    names+=("$WWW_DOMAIN")
  fi
  log_info "Requesting Let's Encrypt certificate for: ${names[*]} (email: ${CERTBOT_EMAIL})"
  ssl_issue_certificate "${names[@]}"
  ssl_install_renewal_hook
}

stage_ssl_activate() {
  ssl_activate_https
}

stage_ssl_verify() {
  if curl -fsS --max-time 10 --resolve "${DOMAIN}:443:127.0.0.1" "https://${DOMAIN}/api/health" >/dev/null 2>&1; then
    log_detail "Local HTTPS check passed (valid certificate for ${DOMAIN})."
  else
    echo "The local HTTPS health check failed after activation."
    return 1
  fi
  # Best effort through the public network path.
  curl -fsS --max-time 10 "https://${DOMAIN}/api/health" >/dev/null 2>&1 \
    || log_warning "Public HTTPS check did not succeed from this host (can be normal behind NAT/hairpin routing). Verify from a browser: https://${DOMAIN}"
}

main() {
  cd "$PROJECT_DIR"
  mkdir -p logs .deploy
  init_logging "$PROJECT_DIR" "ssl"
  trap 'log_failed "ssl:enable interrupted."; exit 130' INT TERM

  echo
  hr
  log_plain "${C_BOLD}Gia Pha Ho Trieu — enable HTTPS (deploy scripts v${GIAPHA_DEPLOY_VERSION})${C_RESET}"
  log_plain "  Domain: ${DOMAIN}${WWW_DOMAIN:+ (+ ${WWW_DOMAIN})}"
  hr

  require_root_or_sudo || exit 1

  stage_register ssl_preflight  required "SSL preconditions"
  stage_register ssl_dns_verify required "DNS verification"
  stage_register ssl_issue      required "Let's Encrypt certificate"
  stage_register ssl_activate   required "Activate HTTPS in nginx"
  stage_register ssl_verify     required "HTTPS health check"
  GIAPHA_STAGE_TOTAL=${#GIAPHA_STAGES[@]}

  local entry id mode desc stage_rc=0
  for entry in "${GIAPHA_STAGES[@]}"; do
    id="${entry%%|*}"
    desc="${entry##*|}"
    mode="${entry#*|}"; mode="${mode%%|*}"
    # Plain call + $? capture — see the note in lib/common.sh run_stage.
    run_stage "$id" "$mode" "$desc"
    stage_rc=$?
    if [[ "$stage_rc" -ne 0 ]]; then
      echo
      hr
      log_failed "HTTPS could not be enabled (stage '${id}'). The site remains available over HTTP."
      log_plain  "  Log: ${GIAPHA_LOG_FILE:-logs/}"
      exit 1
    fi
  done

  echo
  hr
  log_success "HTTPS is now active."
  log_plain   ""
  log_plain   "  ${C_BOLD}https://${DOMAIN}${C_RESET}"
  log_plain   ""
  log_plain   "  Certificates renew automatically (certbot.timer) and nginx reloads via"
  log_plain   "  the deploy hook. Check anytime with:  certbot renew --dry-run"
  hr
  exit 0
}

main
