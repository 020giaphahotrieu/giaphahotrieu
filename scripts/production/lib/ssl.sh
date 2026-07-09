# =============================================================================
# ssl.sh — Let's Encrypt issuance and HTTPS activation helpers.
# Sourced by bootstrap-vps.sh and enable-ssl.sh
# (requires common.sh + config.sh + nginx.sh first).
# =============================================================================

ssl_cert_dir() { printf '%s\n' "${LETSENCRYPT_LIVE_DIR}/${DOMAIN}"; }

ssl_cert_exists() {
  as_root test -f "$(ssl_cert_dir)/fullchain.pem" 2>/dev/null \
    && as_root test -f "$(ssl_cert_dir)/privkey.pem" 2>/dev/null
}

# ssl_issue_certificate <domain> [extra domains...]
# Uses the webroot challenge through the already-running HTTP nginx site.
# --keep-until-expiring makes re-runs free; --expand adds new names.
ssl_issue_certificate() {
  local args
  args=(certonly --webroot -w "$ACME_WEBROOT"
    --non-interactive --agree-tos
    --keep-until-expiring --expand
    --cert-name "$DOMAIN"
    --email "$CERTBOT_EMAIL"
    --no-eff-email)
  local d
  for d in "$@"; do
    args+=(-d "$d")
  done
  ensure_dir_root "$ACME_WEBROOT"
  log_detail "certbot ${args[*]}"
  retry_backoff 3 10 as_root certbot "${args[@]}"
}

# Reload nginx automatically after every future certbot renewal.
ssl_install_renewal_hook() {
  ensure_dir_root "$LETSENCRYPT_HOOK_DIR"
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    '# Installed by giaphahotrieu deployment — reload nginx after cert renewal.' \
    'systemctl reload nginx || true' \
    | as_root tee "${LETSENCRYPT_HOOK_DIR}/giaphahotrieu-reload-nginx.sh" >/dev/null
  as_root chmod +x "${LETSENCRYPT_HOOK_DIR}/giaphahotrieu-reload-nginx.sh"
  # The apt certbot package ships a systemd timer for renewals.
  as_root systemctl enable certbot.timer >/dev/null 2>&1 || \
    log_warning "certbot.timer could not be enabled; check 'systemctl list-timers | grep certbot'"
}

# ssl_activate_https — switch the nginx site to the HTTPS template and reload.
ssl_activate_https() {
  ssl_cert_exists || { log_failed "certificate files missing under $(ssl_cert_dir)"; return 1; }
  nginx_render_site https
  nginx_test_and_reload
}
