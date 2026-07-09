# =============================================================================
# dns.sh — DNS readiness detection and diagnosis for Let's Encrypt issuance.
#
# Sourced by bootstrap-vps.sh and enable-ssl.sh (requires common.sh first).
#
# Main entry points:
#   detect_public_ipv4                  → sets SERVER_IPV4 (best effort)
#   dns_inspect <domain> <expected_ip>  → sets DNS_VERDICT and detail globals
#   dns_wait_until_ready <domain> <ip> <attempts> <initial_delay>
#   dns_print_report <domain> <expected_ip>
#
# DNS_VERDICT values:
#   OK              domain resolves to this server, no blockers found
#   NO_NAMESERVERS  domain not delegated (no NS records anywhere)
#   NXDOMAIN        resolvers answer NXDOMAIN (zone missing at the provider)
#   SERVFAIL        resolvers answer SERVFAIL (broken delegation / DNSSEC)
#   NO_A_RECORD     zone exists but has no A record for the domain
#   WRONG_IP        A record(s) point to a different server
#   AAAA_MISMATCH   AAAA record exists but points to a different server
#   CAA_BLOCKED     CAA records forbid Let's Encrypt
#   NO_TOOLS        dig is not available (cannot verify)
#   UNREACHABLE     no resolver answered (network problem on this host)
#
# Every function here is defensive: no call may abort the calling script.
# =============================================================================

DNS_VERDICT=""
DNS_DETAIL=""
DNS_A_RECORDS=""
DNS_AAAA_RECORDS=""
DNS_AUTH_A_RECORDS=""
DNS_DELEGATED_NS=""
DNS_ZONE_NS=""
DNS_NS_MISMATCH=0
DNS_RCODE_SUMMARY=""
DNS_CAA_RECORDS=""
DNS_CAA_BLOCKING=0

_dig() { dig +time=3 +tries=2 "$@" 2>/dev/null; }

dns_tools_available() { have_cmd dig; }

# dns_rcode <name> <type> <server> → NOERROR|NXDOMAIN|SERVFAIL|REFUSED|TIMEOUT|UNKNOWN
dns_rcode() {
  local out status
  out="$(_dig +noall +comments "$2" "$1" @"$3")" || { echo "TIMEOUT"; return 0; }
  status="$(printf '%s\n' "$out" | sed -n 's/.*->>HEADER<<-.* status: \([A-Za-z]*\).*/\1/p' | head -n 1)"
  if [[ -n "$status" ]]; then
    printf '%s\n' "$status" | tr '[:lower:]' '[:upper:]'
  else
    echo "UNKNOWN"
  fi
}

# dns_records <name> <type> <server> → matching records, one per line
dns_records() {
  local name="$1" type="$2" server="$3" out
  out="$(_dig +short "$type" "$name" @"$server")" || out=""
  case "$type" in
    A)
      printf '%s\n' "$out" | grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}$' || true
      ;;
    AAAA)
      printf '%s\n' "$out" | grep -E '^[0-9a-fA-F:]+$' | grep ':' || true
      ;;
    NS)
      printf '%s\n' "$out" | grep -E '\.' | sed 's/\.$//' | lowercase || true
      ;;
    *)
      printf '%s\n' "$out" | grep -v '^$' || true
      ;;
  esac
}

_dns_uniq_join() { # stdin lines → space separated unique list (never fails)
  sort -u | sed '/^$/d' | tr '\n' ' ' | sed 's/ $//'
}

# Delegated NS: ask public resolvers; when they know nothing, walk to the
# parent zone and read the delegation directly (works even before any
# resolver has cached the zone).
dns_delegated_ns() { # <domain>
  local domain="$1" r ns parent pns pns_list out
  for r in $DNS_RESOLVERS; do
    ns="$(dns_records "$domain" NS "$r" | _dns_uniq_join)"
    if [[ -n "$ns" ]]; then
      printf '%s\n' "$ns"
      return 0
    fi
  done
  parent="${domain#*.}"
  if [[ "$parent" == "$domain" || -z "$parent" ]]; then
    return 0
  fi
  for r in $DNS_RESOLVERS; do
    pns_list="$(dns_records "$parent" NS "$r")"
    [[ -n "$pns_list" ]] || continue
    for pns in $pns_list; do
      out="$(_dig +noall +authority +answer NS "$domain" @"$pns" \
        | awk 'toupper($4) == "NS" { print $5 }' | sed 's/\.$//' | lowercase | _dns_uniq_join)"
      if [[ -n "$out" ]]; then
        printf '%s\n' "$out"
        return 0
      fi
    done
    break
  done
  return 0
}

# dns_inspect <domain> <expected_ipv4>
# Populates the DNS_* globals described in the header. Always returns 0;
# read DNS_VERDICT for the outcome.
dns_inspect() {
  local domain="$1" expected_ip="${2:-}"
  local r rcode a_list aaaa_list rcode_summary="" a_union="" aaaa_union=""
  local saw_noerror=0 saw_servfail=0 saw_nxdomain=0 saw_answer_from_any=0

  DNS_VERDICT=""; DNS_DETAIL=""; DNS_A_RECORDS=""; DNS_AAAA_RECORDS=""
  DNS_AUTH_A_RECORDS=""; DNS_DELEGATED_NS=""; DNS_ZONE_NS=""
  DNS_NS_MISMATCH=0; DNS_RCODE_SUMMARY=""; DNS_CAA_RECORDS=""; DNS_CAA_BLOCKING=0

  if ! dns_tools_available; then
    DNS_VERDICT="NO_TOOLS"
    DNS_DETAIL="'dig' is not installed; cannot verify DNS (package: dnsutils)."
    return 0
  fi

  # 1. What do public resolvers see?
  for r in $DNS_RESOLVERS; do
    rcode="$(dns_rcode "$domain" A "$r")"
    rcode_summary="${rcode_summary}${rcode_summary:+ }${r}=${rcode}"
    case "$rcode" in
      NOERROR)  saw_noerror=1 ;;
      SERVFAIL) saw_servfail=1 ;;
      NXDOMAIN) saw_nxdomain=1 ;;
    esac
    if [[ "$rcode" != "TIMEOUT" && "$rcode" != "UNKNOWN" ]]; then
      saw_answer_from_any=1
    fi
    a_list="$(dns_records "$domain" A "$r")"
    if [[ -n "$a_list" ]]; then
      a_union="$(printf '%s\n%s\n' "$a_union" "$a_list" | _dns_uniq_join)"
    fi
    aaaa_list="$(dns_records "$domain" AAAA "$r")"
    if [[ -n "$aaaa_list" ]]; then
      aaaa_union="$(printf '%s\n%s\n' "$aaaa_union" "$aaaa_list" | _dns_uniq_join)"
    fi
  done
  DNS_RCODE_SUMMARY="$rcode_summary"
  DNS_A_RECORDS="$a_union"
  DNS_AAAA_RECORDS="$aaaa_union"

  # 2. Delegation and the authoritative view (what Let's Encrypt will see).
  DNS_DELEGATED_NS="$(dns_delegated_ns "$domain")"
  if [[ -n "$DNS_DELEGATED_NS" ]]; then
    local ns count=0 auth_a zone_ns
    for ns in $DNS_DELEGATED_NS; do
      count=$(( count + 1 ))
      if [[ $count -gt 3 ]]; then break; fi
      auth_a="$(dns_records "$domain" A "$ns" | _dns_uniq_join)"
      zone_ns="$(dns_records "$domain" NS "$ns" | _dns_uniq_join)"
      if [[ -n "$auth_a" || -n "$zone_ns" ]]; then
        DNS_AUTH_A_RECORDS="$auth_a"
        DNS_ZONE_NS="$zone_ns"
        break
      fi
    done
    if [[ -n "$DNS_ZONE_NS" ]]; then
      local sorted_deleg sorted_zone
      sorted_deleg="$(printf '%s\n' $DNS_DELEGATED_NS | sort -u | tr '\n' ' ')"
      sorted_zone="$(printf '%s\n' $DNS_ZONE_NS | sort -u | tr '\n' ' ')"
      if [[ "$sorted_deleg" != "$sorted_zone" ]]; then
        DNS_NS_MISMATCH=1
      fi
    fi
  fi

  # 3. CAA (checked at the apex; certbot fails when LE is not allowed).
  DNS_CAA_RECORDS="$(dns_records "$domain" CAA "${DNS_RESOLVERS%% *}" | tr '\n' ' ' | sed 's/ $//')"
  if [[ -n "$DNS_CAA_RECORDS" ]] && printf '%s' "$DNS_CAA_RECORDS" | grep -q 'issue'; then
    if ! printf '%s' "$DNS_CAA_RECORDS" | grep -q 'letsencrypt.org'; then
      DNS_CAA_BLOCKING=1
    fi
  fi

  # 4. Verdict.
  local effective_a="$a_union"
  if [[ -z "$effective_a" ]]; then
    effective_a="$DNS_AUTH_A_RECORDS"
  fi

  if [[ $saw_answer_from_any -eq 0 ]]; then
    DNS_VERDICT="UNREACHABLE"
    DNS_DETAIL="No DNS resolver answered from this host (outbound UDP/53 blocked or no network)."
  elif [[ -n "$effective_a" ]]; then
    # Addresses exist (public or authoritative) — judge their correctness.
    # Note: subdomains (www.…) have no delegation of their own, so the
    # delegation checks below only apply when no address exists at all.
    if [[ -n "$expected_ip" ]] && ! printf '%s\n' $effective_a | grep -qxF "$expected_ip"; then
      DNS_VERDICT="WRONG_IP"
      DNS_DETAIL="A record(s) [${effective_a}] do not include this server (${expected_ip})."
    elif [[ -n "$expected_ip" ]] && printf '%s\n' $effective_a | grep -qvxF "$expected_ip"; then
      DNS_VERDICT="WRONG_IP"
      DNS_DETAIL="Extra A record(s) point elsewhere: [${effective_a}] while this server is ${expected_ip}. Let's Encrypt may validate against the wrong server."
    elif [[ $DNS_CAA_BLOCKING -eq 1 ]]; then
      DNS_VERDICT="CAA_BLOCKED"
      DNS_DETAIL="CAA records [${DNS_CAA_RECORDS}] do not authorise letsencrypt.org."
    elif [[ -n "$DNS_AAAA_RECORDS" ]] && [[ -n "${SERVER_IPV6:-}" ]] && ! printf '%s\n' $DNS_AAAA_RECORDS | grep -qxF "$SERVER_IPV6"; then
      DNS_VERDICT="AAAA_MISMATCH"
      DNS_DETAIL="AAAA record(s) [${DNS_AAAA_RECORDS}] do not match this server's IPv6 (${SERVER_IPV6}). Let's Encrypt prefers IPv6 and will validate against the wrong server. Fix or delete the AAAA record."
    elif [[ -n "$DNS_AAAA_RECORDS" && -z "${SERVER_IPV6:-}" ]]; then
      DNS_VERDICT="AAAA_MISMATCH"
      DNS_DETAIL="AAAA record(s) [${DNS_AAAA_RECORDS}] exist but this server has no public IPv6. Let's Encrypt prefers IPv6 and will fail. Delete the AAAA record or add the address to this server."
    else
      DNS_VERDICT="OK"
      if [[ -z "$a_union" && -n "$DNS_AUTH_A_RECORDS" ]]; then
        DNS_DETAIL="Authoritative nameservers already answer correctly; public resolvers have not caught up yet. Certificate issuance should work (Let's Encrypt queries the authoritative servers directly)."
      else
        DNS_DETAIL="${domain} resolves to this server."
      fi
    fi
  elif [[ -z "$DNS_DELEGATED_NS" ]]; then
    DNS_VERDICT="NO_NAMESERVERS"
    DNS_DETAIL="The domain has no NS delegation: the registry does not know any nameserver for ${domain}. It looks like the DNS zone was never created (or the registration is not active)."
  elif [[ $saw_servfail -eq 1 ]]; then
    DNS_VERDICT="SERVFAIL"
    DNS_DETAIL="Public resolvers return SERVFAIL. The delegation exists but the zone is broken (nameservers not answering for this zone, or an invalid DNSSEC/DS configuration)."
  elif [[ $saw_nxdomain -eq 1 && $saw_noerror -eq 0 ]]; then
    DNS_VERDICT="NXDOMAIN"
    DNS_DETAIL="Resolvers answer NXDOMAIN: the zone exists but does not contain ${domain} yet (missing A record / empty zone, possibly cached)."
  else
    DNS_VERDICT="NO_A_RECORD"
    DNS_DETAIL="The zone answers but contains no A record for ${domain}."
  fi
  return 0
}

# dns_wait_until_ready <domain> <expected_ip> <attempts> <initial_delay>
# Retries dns_inspect with exponential backoff until DNS_VERDICT=OK.
# Returns 0 when ready, 1 otherwise (never aborts the caller).
dns_wait_until_ready() {
  local domain="$1" expected_ip="$2" attempts="${3:-4}" delay="${4:-10}"
  local n=1
  while true; do
    dns_inspect "$domain" "$expected_ip"
    if [[ "$DNS_VERDICT" == "OK" ]]; then
      log_success "DNS check ${n}/${attempts}: ${domain} → ${DNS_A_RECORDS:-$DNS_AUTH_A_RECORDS} (${DNS_DETAIL})"
      return 0
    fi
    log_warning "DNS check ${n}/${attempts}: ${DNS_VERDICT} — ${DNS_DETAIL}"
    if (( n >= attempts )); then
      return 1
    fi
    log_info "Waiting ${delay}s before the next DNS check (exponential backoff)..."
    sleep "$delay"
    delay=$(( delay * 2 ))
    if (( delay > ${DNS_MAX_DELAY:-60} )); then delay="${DNS_MAX_DELAY:-60}"; fi
    n=$(( n + 1 ))
  done
}

# dns_print_report <domain> <expected_ip>
# Human-readable diagnosis + exact instructions. Uses the globals filled by
# the most recent dns_inspect call.
dns_print_report() {
  local domain="$1" expected_ip="${2:-<server-ip>}"
  echo
  hr
  log_plain "${C_BOLD}DNS diagnosis for ${domain}${C_RESET}"
  log_plain "  Expected server IPv4      : ${expected_ip}"
  log_plain "  Delegated nameservers     : ${DNS_DELEGATED_NS:-(none found — domain not delegated)}"
  log_plain "  Zone nameservers (NS)     : ${DNS_ZONE_NS:-(no answer)}"
  log_plain "  Resolver status           : ${DNS_RCODE_SUMMARY:-(not queried)}"
  log_plain "  A records (public)        : ${DNS_A_RECORDS:-(none)}"
  log_plain "  A records (authoritative) : ${DNS_AUTH_A_RECORDS:-(none)}"
  log_plain "  AAAA records              : ${DNS_AAAA_RECORDS:-(none)}"
  log_plain "  CAA records               : ${DNS_CAA_RECORDS:-(none — fine)}"
  if [[ "$DNS_NS_MISMATCH" -eq 1 ]]; then
    log_warning "Nameserver mismatch: the registry delegates to [${DNS_DELEGATED_NS}] but the zone claims [${DNS_ZONE_NS}]. Align both sides at your DNS provider."
  fi
  log_plain "  Verdict                   : ${DNS_VERDICT}"
  log_plain "  Detail                    : ${DNS_DETAIL}"
  hr

  if [[ "$DNS_VERDICT" == "OK" ]]; then
    return 0
  fi

  log_plain ""
  log_plain "${C_BOLD}What to do now (at your DNS provider / registrar panel):${C_RESET}"
  case "$DNS_VERDICT" in
    NO_NAMESERVERS|NXDOMAIN|SERVFAIL)
      log_plain "  1. Log in to the DNS panel that manages ${domain} (e.g. OneShield)."
      log_plain "  2. Create the DNS zone for ${domain} if the panel says the domain does not exist."
      log_plain "  3. Make sure the registrar points the domain to that panel's nameservers"
      log_plain "     (for .vn domains this is configured at the registrar where the domain was bought)."
      log_plain "  4. Add these records to the zone:"
      log_plain "       Type A     Host @      Value ${expected_ip}"
      log_plain "       Type A     Host www    Value ${expected_ip}"
      log_plain "  5. Wait for propagation (minutes up to a few hours for .vn)."
      ;;
    NO_A_RECORD)
      log_plain "  Add these records to the ${domain} zone:"
      log_plain "       Type A     Host @      Value ${expected_ip}"
      log_plain "       Type A     Host www    Value ${expected_ip}"
      ;;
    WRONG_IP)
      log_plain "  Update the A record(s) of ${domain} to point to this server:"
      log_plain "       Type A     Host @      Value ${expected_ip}"
      log_plain "       Type A     Host www    Value ${expected_ip}"
      log_plain "  Currently seen: ${DNS_A_RECORDS:-$DNS_AUTH_A_RECORDS}"
      ;;
    AAAA_MISMATCH)
      log_plain "  Delete the AAAA record(s) [${DNS_AAAA_RECORDS}] for ${domain},"
      log_plain "  or point them to this server's IPv6 address."
      ;;
    CAA_BLOCKED)
      log_plain "  Add a CAA record authorising Let's Encrypt:"
      log_plain "       Type CAA   Host @      Value 0 issue \"letsencrypt.org\""
      ;;
    NO_TOOLS)
      log_plain "  Install dnsutils on this server:  apt-get install -y dnsutils"
      ;;
    UNREACHABLE)
      log_plain "  This server cannot reach any DNS resolver. Check outbound networking"
      log_plain "  (UDP/TCP port 53) and /etc/resolv.conf."
      ;;
  esac
  log_plain ""
  log_plain "  You can watch propagation with:  dig +short A ${domain} @8.8.8.8"
  log_plain "  When DNS is ready, enable HTTPS with:  pnpm ssl:enable"
  return 0
}

# --- Public IP detection ---------------------------------------------------------
_fetch_ip() { # <curl-args...>
  curl -fsS --max-time 8 "$@" 2>/dev/null | tr -d '[:space:]'
}

detect_public_ipv4() {
  if [[ -n "${SERVER_IPV4:-}" ]]; then
    log_detail "Using SERVER_IPV4 from environment: ${SERVER_IPV4}"
    return 0
  fi
  local candidate service
  for service in "https://api.ipify.org" "https://ifconfig.me/ip" "https://icanhazip.com"; do
    candidate="$(_fetch_ip -4 "$service")" || candidate=""
    if printf '%s' "$candidate" | grep -qE '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; then
      SERVER_IPV4="$candidate"
      log_detail "Detected public IPv4 via ${service}: ${SERVER_IPV4}"
      return 0
    fi
  done
  if have_cmd ip; then
    candidate="$(ip -4 route get 1.1.1.1 2>/dev/null | sed -n 's/.*src \([0-9.]*\).*/\1/p' | head -n 1)"
    if [[ -n "$candidate" ]]; then
      SERVER_IPV4="$candidate"
      log_warning "Could not query a public IP service; using local address ${SERVER_IPV4} (may differ from the public IP behind NAT)."
      return 0
    fi
  fi
  log_warning "Could not detect this server's public IPv4. Set SERVER_IPV4=<ip> to make DNS verification exact."
  return 1
}

detect_public_ipv6() {
  if [[ -n "${SERVER_IPV6:-}" ]]; then
    return 0
  fi
  local candidate
  candidate="$(_fetch_ip -6 "https://api64.ipify.org")" || candidate=""
  if printf '%s' "$candidate" | grep -q ':'; then
    SERVER_IPV6="$candidate"
    log_detail "Detected public IPv6: ${SERVER_IPV6}"
    return 0
  fi
  if have_cmd ip; then
    candidate="$(ip -6 addr show scope global 2>/dev/null | sed -n 's/.*inet6 \([0-9a-f:]*\)\/.*/\1/p' | head -n 1)"
    if [[ -n "$candidate" ]]; then
      SERVER_IPV6="$candidate"
      return 0
    fi
  fi
  return 1
}
