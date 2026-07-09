#!/usr/bin/env bash
# =============================================================================
# install.sh — zero-to-production entrypoint for a brand-new Ubuntu 24.04 VPS.
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/020giaphahotrieu/giaphahotrieu/main/scripts/production/install.sh)
#
# What it does:
#   1. installs the bare minimum (git, curl) needed to obtain the repository
#   2. finds an existing clone of the repository, or clones it to /opt/giaphahotrieu
#   3. synchronises the clone with origin/main WITHOUT ever losing the
#      production SQLite database or local .env files
#   4. hands over to scripts/production/bootstrap-vps.sh, which does the rest
#      (packages, build, nginx, PM2, firewall, DNS-aware SSL, health checks)
#
# Safe to run repeatedly. Standalone by design: do not source repo files here —
# this script runs before the repository exists.
# =============================================================================
set -uo pipefail

REPO_URL="${REPO_URL:-https://github.com/020giaphahotrieu/giaphahotrieu.git}"
REPO_BRANCH="${REPO_BRANCH:-main}"
DEFAULT_CLONE_DIR="${REPO_DIR:-/opt/giaphahotrieu}"

say()  { printf '%s [install] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
fail() { say "FAILED: $*"; exit 1; }

SUDO=""
if [[ "$(id -u)" -ne 0 ]]; then
  if command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
    SUDO="sudo"
  else
    fail "run this script as root (or as a user with passwordless sudo)."
  fi
fi

retry() { # <attempts> <delay> <cmd...>
  local attempts="$1" delay="$2" n=1
  shift 2
  while true; do
    "$@" && return 0
    [[ $n -ge $attempts ]] && return 1
    say "attempt ${n}/${attempts} failed, retrying in ${delay}s: $*"
    sleep "$delay"
    delay=$(( delay * 2 ))
    n=$(( n + 1 ))
  done
}

ensure_base_tools() {
  if command -v git >/dev/null 2>&1 && command -v curl >/dev/null 2>&1; then
    return 0
  fi
  say "installing base tools (git, curl)..."
  command -v apt-get >/dev/null 2>&1 || fail "apt-get not found — this installer supports Ubuntu/Debian."
  retry 3 5 $SUDO env DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=600 update
  $SUDO env DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=600 install -y git curl ca-certificates
}

repo_matches() { # <dir> → 0 when dir is a clone of our repository
  local dir="$1" url=""
  [[ -d "$dir/.git" ]] || return 1
  url="$(git -C "$dir" remote get-url origin 2>/dev/null || true)"
  case "$url" in
    *020giaphahotrieu/giaphahotrieu*) return 0 ;;
    *) return 1 ;;
  esac
}

find_repo() {
  if [[ -n "${REPO_DIR:-}" ]]; then
    printf '%s\n' "$REPO_DIR"
    return 0
  fi
  local candidate
  for candidate in /opt/giaphahotrieu /root/giaphahotrieu /var/www/giaphahotrieu /home/*/giaphahotrieu "$PWD"; do
    if repo_matches "$candidate"; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

main() {
  say "Gia Pha Ho Trieu — VPS installer"
  ensure_base_tools

  local repo_dir=""
  if repo_dir="$(find_repo)"; then
    say "using existing repository: ${repo_dir}"
  else
    repo_dir="$DEFAULT_CLONE_DIR"
    say "cloning ${REPO_URL} to ${repo_dir}..."
    $SUDO mkdir -p "$(dirname "$repo_dir")"
    retry 3 5 $SUDO git clone --branch "$REPO_BRANCH" "$REPO_URL" "$repo_dir" \
      || fail "could not clone ${REPO_URL}"
  fi

  cd "$repo_dir" || fail "cannot enter ${repo_dir}"

  # Git refuses to operate on clones owned by another user without this.
  if ! git config --global --get-all safe.directory 2>/dev/null | grep -qxF "$repo_dir"; then
    git config --global --add safe.directory "$repo_dir" 2>/dev/null || true
  fi

  # --- Synchronise with origin/main, preserving production data -------------
  # The SQLite database used to be tracked in git; the commit that untracked
  # it makes git delete the working-tree copy on checkout. Back it up first
  # and restore it afterwards, no matter what git does.
  local db="database/family-heritage.db" db_backup=""
  if [[ -f "$db" ]]; then
    db_backup="$(mktemp /tmp/giapha-db-backup.XXXXXX)"
    cp -f "$db" "$db_backup"
    say "database backed up to ${db_backup}"
  fi

  if retry 3 5 git fetch origin "$REPO_BRANCH"; then
    git update-index --no-skip-worktree "$db" 2>/dev/null || true
    if ! git diff --quiet HEAD 2>/dev/null; then
      mkdir -p .deploy
      git diff HEAD > ".deploy/local-changes-$(date +%Y%m%d-%H%M%S).patch" 2>/dev/null || true
      say "local changes were saved to .deploy/ before resetting to origin/${REPO_BRANCH}"
    fi
    git checkout -f -B "$REPO_BRANCH" "origin/${REPO_BRANCH}" || fail "git checkout failed"
    git reset --hard "origin/${REPO_BRANCH}" || fail "git reset failed"
    say "repository is at $(git rev-parse --short HEAD)"
  else
    say "WARNING: could not reach the git remote — continuing with the code already on disk."
  fi

  if [[ -n "$db_backup" && ! -f "$db" ]]; then
    mkdir -p database
    cp -f "$db_backup" "$db"
    say "database restored (git had removed it from the working tree)"
  fi

  [[ -f scripts/production/bootstrap-vps.sh ]] || fail "scripts/production/bootstrap-vps.sh not found after sync."
  chmod +x scripts/production/*.sh 2>/dev/null || true

  say "handing over to bootstrap-vps.sh..."
  exec env GIAPHA_SKIP_SYNC=1 bash scripts/production/bootstrap-vps.sh "$@"
}

main "$@"
