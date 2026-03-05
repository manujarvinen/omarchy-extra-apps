#!/usr/bin/env bash
set -euo pipefail

APP_ID="intel-level-zero-raytracing-support"
APP_NAME="Intel Level Zero Raytracing Support"
APP_DESC="Intel Level Zero Raytracing Support"
APP_REBOOT_REQUIRED="1"

app_install() {
  # shellcheck disable=SC1091
  source "$(dirname "${BASH_SOURCE[0]}")/../lib/core.sh"

  info "Installing $APP_NAME..."

  # Examples:
  # pacman_install package1 package2
  aur_install intel-level-zero-raytracing-support
  # sudo_wrap systemctl enable --now something.service

  ok "$APP_NAME installed."
}
