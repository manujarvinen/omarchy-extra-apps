#!/usr/bin/env bash
set -euo pipefail

APP_ID="nano"
APP_NAME="Nano"
APP_DESC="Nano"
APP_REBOOT_REQUIRED="0"

app_install() {
  # shellcheck disable=SC1091
  source "$(dirname "${BASH_SOURCE[0]}")/../lib/core.sh"

  info "Installing $APP_NAME..."
  pacman_install nano
  ok "$APP_NAME installed."
}
