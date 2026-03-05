#!/usr/bin/env bash
set -euo pipefail

APP_ID="krita"
APP_NAME="Krita"
APP_DESC="Digital painting"
APP_REBOOT_REQUIRED="0"

app_install() {
  # shellcheck disable=SC1091
  source "$(dirname "${BASH_SOURCE[0]}")/../lib/core.sh"

  info "Installing $APP_NAME..."
  pacman_install krita
  ok "$APP_NAME installed."
}
