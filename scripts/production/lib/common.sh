# =============================================================================
# common.sh — logging, stage runner, retries and system helpers.
#
# Sourced by bootstrap-vps.sh and enable-ssl.sh. Never executed directly.
#
# Error-handling contract:
#   * This file NEVER enables `set -e`. The entry scripts run with
#     `set -uo pipefail` only, so a failing command cannot abort a deployment
#     unless a stage explicitly decides so.
#   * Stage bodies are executed inside a subshell with `set -Eeo pipefail`
#     (see run_stage), so a stage fails fast internally, while the caller
#     decides whether that failure is fatal (required) or a warning (optional).
#   * Compatible with bash 3.2+ (no associative arrays, no ${var,,}).
# =============================================================================

# --- Privileges ---------------------------------------------------------------
if [[ "$(id -u)" -eq 0 ]]; then
  GIAPHA_IS_ROOT=1
else
  GIAPHA_IS_ROOT=0
fi

as_root() {
  if [[ "$GIAPHA_IS_ROOT" -eq 1 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

require_root_or_sudo() {
  if [[ "$GIAPHA_IS_ROOT" -eq 1 ]]; then
    return 0
  fi
  if command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
    return 0
  fi
  log_failed "This script needs root privileges (or a user with passwordless sudo)."
  log_plain  "Re-run it as root, e.g.:  sudo bash $0"
  return 1
}

# --- Logging ------------------------------------------------------------------
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  C_RESET=$'\033[0m';  C_BOLD=$'\033[1m';   C_DIM=$'\033[2m'
  C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_RED=$'\033[31m'; C_BLUE=$'\033[34m'
else
  C_RESET=''; C_BOLD=''; C_DIM=''; C_GREEN=''; C_YELLOW=''; C_RED=''; C_BLUE=''
fi

GIAPHA_WARNINGS=()

_ts() { date "+%Y-%m-%d %H:%M:%S"; }

log_plain()   { printf '%s\n' "$*"; }
log_info()    { printf '%s %s[INFO]%s    %s\n' "$(_ts)" "$C_BLUE"   "$C_RESET" "$*"; }
log_detail()  { printf '%s %s[....]%s    %s\n' "$(_ts)" "$C_DIM"    "$C_RESET" "$*"; }
log_start()   { printf '%s %s[START]%s   %s%s%s\n' "$(_ts)" "$C_BOLD" "$C_RESET" "$C_BOLD" "$*" "$C_RESET"; }
log_success() { printf '%s %s[SUCCESS]%s %s\n' "$(_ts)" "$C_GREEN"  "$C_RESET" "$*"; }
log_warning() {
  printf '%s %s[WARNING]%s %s\n' "$(_ts)" "$C_YELLOW" "$C_RESET" "$*"
  GIAPHA_WARNINGS+=("$*")
}
log_failed()  { printf '%s %s[FAILED]%s  %s\n' "$(_ts)" "$C_RED" "$C_RESET" "$*"; }

hr() { printf '%s\n' "----------------------------------------------------------------------"; }

# init_logging <project_dir> <basename>
# Mirrors all output of the calling script into logs/<basename>-<timestamp>.log
# and keeps a stable symlink at <basename>.log plus deploy-production.log.
init_logging() {
  local project_dir="$1" base="$2"
  GIAPHA_LOGS_DIR="${project_dir}/logs"
  mkdir -p "$GIAPHA_LOGS_DIR"
  GIAPHA_LOG_FILE="${GIAPHA_LOGS_DIR}/${base}-$(date +%Y%m%d-%H%M%S).log"
  : >"$GIAPHA_LOG_FILE"
  # Stable pointers to the latest log of this kind.
  ln -sf "$GIAPHA_LOG_FILE" "${GIAPHA_LOGS_DIR}/${base}-latest.log" 2>/dev/null || true
  ln -sf "$GIAPHA_LOG_FILE" "${project_dir}/deploy-production.log" 2>/dev/null || true
  # Keep the 20 most recent logs of this kind.
  (cd "$GIAPHA_LOGS_DIR" 2>/dev/null && ls -1t "${base}"-2*.log 2>/dev/null | tail -n +21 | while read -r old; do rm -f "$old"; done) || true
  exec > >(tee -a "$GIAPHA_LOG_FILE") 2>&1
}

# --- Retries --------------------------------------------------------------------
# retry_backoff <attempts> <initial_delay_seconds> <command...>
# Exponential backoff (delay doubles each retry, capped at 120s).
retry_backoff() {
  local attempts="$1" delay="$2"
  shift 2
  local n=1 rc=0
  while true; do
    "$@" && return 0
    rc=$?
    if (( n >= attempts )); then
      return "$rc"
    fi
    log_detail "attempt ${n}/${attempts} failed (exit ${rc}); retrying in ${delay}s: $*"
    sleep "$delay"
    delay=$(( delay * 2 ))
    if (( delay > 120 )); then delay=120; fi
    n=$(( n + 1 ))
  done
}

# --- apt helpers -----------------------------------------------------------------
# Non-interactive, resilient to concurrent apt/dpkg activity (waits for locks
# up to 10 minutes instead of failing), keeps existing config files.
apt_env() {
  as_root env DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a NEEDRESTART_SUSPEND=1 "$@"
}

apt_update() {
  apt_env apt-get -o DPkg::Lock::Timeout=600 update
}

apt_install() {
  apt_env apt-get -o DPkg::Lock::Timeout=600 \
    -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold \
    install -y "$@"
}

# --- Misc helpers ------------------------------------------------------------------
have_cmd() { command -v "$1" >/dev/null 2>&1; }

ensure_dir_root() {
  local dir
  for dir in "$@"; do
    as_root mkdir -p "$dir"
  done
}

file_sha256() {
  if have_cmd sha256sum; then
    sha256sum "$@" 2>/dev/null | awk '{print $1}' | paste -sd- - 2>/dev/null || true
  else
    shasum -a 256 "$@" 2>/dev/null | awk '{print $1}' | paste -sd- - 2>/dev/null || true
  fi
}

lowercase() { tr '[:upper:]' '[:lower:]'; }

# Read KEY="value" (or KEY=value) from an env file. Prints the raw value.
env_file_get() {
  local file="$1" key="$2" line=""
  [[ -f "$file" ]] || return 1
  line="$(grep -E "^${key}=" "$file" 2>/dev/null | tail -n 1)" || true
  [[ -n "$line" ]] || return 1
  line="${line#"${key}"=}"
  line="${line%\"}" ; line="${line#\"}"
  line="${line%\'}" ; line="${line#\'}"
  printf '%s\n' "$line"
}

random_secret_hex() { openssl rand -hex "${1:-48}"; }

random_password() {
  # base64 without ambiguous shell/URL characters, 20 chars.
  openssl rand -base64 24 | tr -d '/+=' | cut -c1-20
}

# --- Deployment state ----------------------------------------------------------------
# One line per stage in .deploy/state:  <stage>|<status>|<git-sha>|<epoch>
# Used for `--resume` (skip expensive stages already completed for the same
# revision) and for the final summary.

git_head_sha() {
  git -C "$PROJECT_DIR" rev-parse HEAD 2>/dev/null || echo "unknown"
}

state_file() { printf '%s\n' "$PROJECT_DIR/.deploy/state"; }

state_record() { # <stage> <status>
  local f tmp
  f="$(state_file)"
  mkdir -p "$(dirname "$f")"
  tmp="${f}.tmp"
  { [[ -f "$f" ]] && grep -v "^${1}|" "$f"; true; } > "$tmp" 2>/dev/null
  printf '%s|%s|%s|%s\n' "$1" "$2" "$(git_head_sha)" "$(date +%s)" >> "$tmp"
  mv "$tmp" "$f"
}

state_lookup() { # <stage> → prints "stage|status|sha|epoch", rc=1 when absent
  local f line
  f="$(state_file)"
  [[ -f "$f" ]] || return 1
  line="$(grep "^${1}|" "$f" 2>/dev/null | tail -n 1)"
  [[ -n "$line" ]] || return 1
  printf '%s\n' "$line"
}

state_clear() { rm -f "$(state_file)"; }

# --- Stage runner ----------------------------------------------------------------------
# Stages are registered as "id|mode|description" where mode is:
#   required  — a failure aborts the deployment (after printing FAILED)
#   optional  — a failure is downgraded to WARNING and the deployment continues
GIAPHA_STAGES=()
GIAPHA_STAGE_RESULTS=()
GIAPHA_STAGE_INDEX=0
GIAPHA_FATAL_STAGE=""
RESUME_MODE="${RESUME_MODE:-0}"
RESUME_SKIPPABLE_STAGES="${RESUME_SKIPPABLE_STAGES:-}"

stage_register() { GIAPHA_STAGES+=("$1|$2|$3"); }

stage_can_skip_on_resume() { # <id>
  [[ "$RESUME_MODE" -eq 1 ]] || return 1
  case " ${RESUME_SKIPPABLE_STAGES} " in
    *" $1 "*) : ;;
    *) return 1 ;;
  esac
  local line status sha
  line="$(state_lookup "$1")" || return 1
  status="$(printf '%s' "$line" | cut -d'|' -f2)"
  sha="$(printf '%s' "$line" | cut -d'|' -f3)"
  [[ "$status" == "ok" && "$sha" == "$(git_head_sha)" ]]
}

# run_stage <id> <mode> <description>
# The stage body is the shell function stage_<id>.
run_stage() {
  local id="$1" mode="$2" desc="$3"
  local fn="stage_${id}"
  GIAPHA_STAGE_INDEX=$(( GIAPHA_STAGE_INDEX + 1 ))
  local label="[${GIAPHA_STAGE_INDEX}/${GIAPHA_STAGE_TOTAL:-?}] ${desc}"

  echo
  hr
  if stage_can_skip_on_resume "$id"; then
    log_info "${label} — SKIPPED (already completed for this revision, resume mode)"
    GIAPHA_STAGE_RESULTS+=("${id}|skipped")
    return 0
  fi

  log_start "${label} — START"
  # NOTE: the subshell must be invoked as a plain statement — wrapping it in
  # `if`/`||` would put it in a "condition context" where bash ignores the
  # inner `set -e` entirely and failures inside the stage would go unnoticed.
  local rc=0
  (
    set -Eeo pipefail
    trap 'echo "  ! command failed at line ${LINENO}: ${BASH_COMMAND}" >&2' ERR
    "$fn"
  )
  rc=$?

  if [[ $rc -eq 0 ]]; then
    log_success "${label} — SUCCESS"
    GIAPHA_STAGE_RESULTS+=("${id}|ok")
    state_record "$id" ok
    return 0
  fi

  if [[ "$mode" == "optional" ]]; then
    log_warning "${label} — WARNING (exit ${rc}) — this stage is non-critical, the deployment continues"
    GIAPHA_STAGE_RESULTS+=("${id}|warned")
    state_record "$id" warned
    return 0
  fi

  log_failed "${label} — FAILED (exit ${rc})"
  GIAPHA_STAGE_RESULTS+=("${id}|failed")
  state_record "$id" failed
  GIAPHA_FATAL_STAGE="$id"
  return 1
}

print_stage_results() {
  local entry id result icon
  for entry in "${GIAPHA_STAGE_RESULTS[@]}"; do
    id="${entry%%|*}"
    result="${entry##*|}"
    case "$result" in
      ok)      icon="${C_GREEN}SUCCESS${C_RESET}" ;;
      warned)  icon="${C_YELLOW}WARNING${C_RESET}" ;;
      skipped) icon="${C_DIM}SKIPPED${C_RESET}" ;;
      failed)  icon="${C_RED}FAILED ${C_RESET}" ;;
      *)       icon="$result" ;;
    esac
    printf '  %b  %s\n' "$icon" "$id"
  done
}
