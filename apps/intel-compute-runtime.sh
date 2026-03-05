#!/usr/bin/env bash
set -euo pipefail

APP_ID="intel-compute-runtime"
APP_NAME="Intel Compute Runtime"
APP_DESC="Intel Compute Runtime"
APP_REBOOT_REQUIRED="1"

app_install() {
  # shellcheck disable=SC1091
  source "$(dirname "${BASH_SOURCE[0]}")/../lib/core.sh"

  info "Installing $APP_NAME..."
  pacman_install intel-compute-runtime level-zero-loader clinfo intel-media-driver intel-gmmlib intel-graphics-compiler
  aur_install intel-level-zero-gpu
  ok "$APP_NAME installed."
}
