#!/usr/bin/env bash
set -euo pipefail

APP_ID="sourcegit"
APP_NAME="SourceGit"
APP_DESC="SourceGit"
APP_REBOOT_REQUIRED="0"

app_install() {
  # shellcheck disable=SC1091
  source "$(dirname "${BASH_SOURCE[0]}")/../lib/core.sh"

  info "Installing $APP_NAME..."

  # Examples:
  # pacman_install package1 package2
  aur_install sourcegit-bin
  # sudo_wrap systemctl enable --now something.service

  ok "$APP_NAME installed."
}
