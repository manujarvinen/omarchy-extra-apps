#!/usr/bin/env bash
set -euo pipefail

APP_ID="blender"
APP_NAME="Blender"
APP_DESC="3D creation suite"
APP_REBOOT_REQUIRED="0"

app_install() {
  # shellcheck disable=SC1091
  source "$(dirname "${BASH_SOURCE[0]}")/../lib/core.sh"

  info "Installing $APP_NAME..."
  # pacman_install blender
  aur_install blender-bin
  ok "$APP_NAME installed."
}
