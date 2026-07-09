# =============================================================================
# nginx.sh — render and activate the nginx site from the templates in
# deploy/nginx/. Sourced by bootstrap-vps.sh and enable-ssl.sh
# (requires common.sh + config.sh first).
# =============================================================================

nginx_site_conf() { printf '%s\n' "${NGINX_AVAILABLE_DIR}/${DOMAIN}.conf"; }

nginx_server_names() {
  printf '%s' "$DOMAIN"
  if [[ -n "$WWW_DOMAIN" ]]; then
    printf ' %s' "$WWW_DOMAIN"
  fi
  printf '\n'
}

nginx_site_is_https() {
  local conf
  conf="$(nginx_site_conf)"
  [[ -f "$conf" ]] && grep -q 'listen 443' "$conf"
}

# nginx_render_site <http|https>
# Renders the matching template to sites-available and enables it.
# Safe to re-run; validates with `nginx -t` before reloading.
nginx_render_site() {
  local mode="$1"
  local template="${PROJECT_DIR}/deploy/nginx/site-${mode}.conf.template"
  [[ -f "$template" ]] || { log_failed "nginx template not found: ${template}"; return 1; }

  local server_names listen80_v6="" listen443_v6=""
  server_names="$(nginx_server_names)"
  # Only emit IPv6 listeners when the kernel has an IPv6 stack.
  if [[ -f /proc/net/if_inet6 || -n "${GIAPHA_FORCE_IPV6_LISTEN:-}" ]]; then
    listen80_v6='listen [::]:80;'
    listen443_v6='listen [::]:443 ssl http2;'
  fi

  local rendered
  rendered="$(sed \
    -e "s|__SERVER_NAMES__|${server_names}|g" \
    -e "s|__DOMAIN__|${DOMAIN}|g" \
    -e "s|__DEPLOY_ROOT__|${DEPLOY_ROOT}|g" \
    -e "s|__ACME_WEBROOT__|${ACME_WEBROOT}|g" \
    -e "s|__APP_PORT__|${APP_PORT}|g" \
    -e "s|__CERT_DIR__|${LETSENCRYPT_LIVE_DIR}/${DOMAIN}|g" \
    -e "s|__LISTEN_80_V6__|${listen80_v6}|g" \
    -e "s|__LISTEN_443_V6__|${listen443_v6}|g" \
    "$template")"

  if printf '%s' "$rendered" | grep -q '__[A-Z_]*__'; then
    log_failed "nginx template rendering left unresolved placeholders"
    printf '%s\n' "$rendered" | grep '__[A-Z_]*__' | head -n 5
    return 1
  fi

  ensure_dir_root "$NGINX_AVAILABLE_DIR" "$NGINX_ENABLED_DIR"
  printf '%s\n' "$rendered" | as_root tee "$(nginx_site_conf)" >/dev/null
  as_root ln -sf "$(nginx_site_conf)" "${NGINX_ENABLED_DIR}/${DOMAIN}.conf"
  as_root rm -f "${NGINX_ENABLED_DIR}/default"
  log_detail "nginx site (${mode}) written to $(nginx_site_conf)"
}

nginx_test_and_reload() {
  as_root nginx -t
  as_root systemctl enable nginx >/dev/null 2>&1 || true
  if as_root systemctl is-active nginx >/dev/null 2>&1; then
    as_root systemctl reload nginx
  else
    as_root systemctl start nginx
  fi
}
