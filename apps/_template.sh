#!/usr/bin/env bash
set -euo pipefail

APP_ID="myapp"
APP_NAME="My App"
APP_DESC="Short description"
APP_REBOOT_REQUIRED="0"

app_install() {
  # shellcheck disable=SC1091
  source "$(dirname "${BASH_SOURCE[0]}")/../lib/core.sh"

  info "Installing $APP_NAME..."

  # Examples:
  # pacman_install package1 package2
  # aur_install aurpkg1
  # sudo_wrap systemctl enable --now something.service

  ok "$APP_NAME installed."
}
