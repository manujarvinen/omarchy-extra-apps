#!/usr/bin/env bash
set -euo pipefail

# ---- basic UX ----
LOG_DIR="${LOG_DIR:-./logs}"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_FILE:-$LOG_DIR/install-$(date +%F_%H%M%S).log}"

log_emit() {
  local prefix="$1"
  shift
  local msg="$*"

  if [[ "${LOG_CAPTURE_MODE:-0}" == "1" ]]; then
    printf "%b %s\n" "$prefix" "$msg" >&2
  else
    printf "%b %s\n" "$prefix" "$msg" | tee -a "$LOG_FILE" >&2
  fi
}

info()  { log_emit "\033[1;34m[i]\033[0m" "$*"; }
ok()    { log_emit "\033[1;32m[✓]\033[0m" "$*"; }
warn()  { log_emit "\033[1;33m[!]\033[0m" "$*"; }
err()   { log_emit "\033[1;31m[x]\033[0m" "$*"; }

die() { err "$*"; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing command: $1"
}

# ---- system helpers ----
is_root() { [[ "${EUID:-$(id -u)}" -eq 0 ]]; }

sudo_wrap() {
  if is_root; then
    "$@"
  else
    sudo "$@"
  fi
}

# ---- package install helpers ----
PACMAN="${PACMAN:-pacman}"
AUR_HELPER="${AUR_HELPER:-yay}"   # change to paru if you prefer

pacman_install() {
  local pkgs=("$@")
  sudo_wrap "$PACMAN" -S --needed --noconfirm "${pkgs[@]}"
}

aur_install() {
  local pkgs=("$@")
  if command -v "$AUR_HELPER" >/dev/null 2>&1; then
    "$AUR_HELPER" -S --needed --noconfirm "${pkgs[@]}"
  else
    die "AUR helper '$AUR_HELPER' not found. Install it or set AUR_HELPER."
  fi
}

# Optional: quick check
has_pkg() {
  pacman -Q "$1" >/dev/null 2>&1
}
