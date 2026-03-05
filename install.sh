#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
APPS_DIR="$ROOT_DIR/apps"

# shellcheck disable=SC1091
source "$ROOT_DIR/lib/core.sh"

require_cmd bash

declare -a APP_IDS=()
declare -a APP_NAMES=()
declare -a APP_DESCS=()
declare -a APP_REBOOTS=()
declare -a APP_SCRIPTS=()
declare -A APP_INDEX=()

discover_apps() {
  local f
  for f in "$APPS_DIR"/*.sh; do
    [[ -e "$f" ]] || continue
    [[ "$(basename "$f")" == "_template.sh" ]] && continue
    echo "$f"
  done
}

# Load metadata from each app script without installing yet
load_app_meta() {
  local script="$1"
  (
    unset APP_ID APP_NAME APP_DESC APP_REBOOT_REQUIRED
    unset -f app_install 2>/dev/null || true

    # shellcheck disable=SC1090
    source "$script"

    [[ -n "${APP_ID:-}" ]]   || die "Missing APP_ID in $(basename "$script")"
    [[ -n "${APP_NAME:-}" ]] || die "Missing APP_NAME in $(basename "$script")"
    [[ -n "${APP_DESC:-}" ]] || die "Missing APP_DESC in $(basename "$script")"
    declare -F app_install >/dev/null || die "Missing app_install() in $(basename "$script")"

    local reboot_required="${APP_REBOOT_REQUIRED:-0}"
    if [[ "$reboot_required" != "0" && "$reboot_required" != "1" ]]; then
      die "Invalid APP_REBOOT_REQUIRED in $(basename "$script"): expected 0 or 1, got '$reboot_required'"
    fi

    # id|name|desc|reboot_required|scriptpath
    printf "%s|%s|%s|%s|%s\n" "$APP_ID" "$APP_NAME" "$APP_DESC" "$reboot_required" "$script"
  )
}

build_app_registry() {
  APP_IDS=()
  APP_NAMES=()
  APP_DESCS=()
  APP_REBOOTS=()
  APP_SCRIPTS=()
  APP_INDEX=()

  local -A seen_ids=()
  local script meta id name desc reboot_required script_path idx

  while IFS= read -r script; do
    meta="$(load_app_meta "$script")"
    IFS='|' read -r id name desc reboot_required script_path <<<"$meta"

    if [[ -n "${seen_ids[$id]:-}" ]]; then
      die "Duplicate APP_ID '$id' in $script_path (already defined in ${seen_ids[$id]})."
    fi

    idx="${#APP_IDS[@]}"
    APP_IDS+=("$id")
    APP_NAMES+=("$name")
    APP_DESCS+=("$desc")
    APP_REBOOTS+=("$reboot_required")
    APP_SCRIPTS+=("$script_path")
    APP_INDEX["$id"]="$idx"
    seen_ids["$id"]="$script_path"
  done < <(discover_apps)

  ((${#APP_IDS[@]} > 0)) || die "No app scripts found in $APPS_DIR"
}

emit_line() {
  local line="$1"
  printf "%b\n" "$line" | tee -a "$LOG_FILE" >&2
}

show_reboot_banner() {
  local red_bg_white_fg=$'\033[1;30;41m'
  local reset=$'\033[0m'

  emit_line ""
  emit_line "${red_bg_white_fg}                                                          ${reset}"
  emit_line "${red_bg_white_fg}                 !!! REBOOT REQUIRED !!!                  ${reset}"
  emit_line "${red_bg_white_fg}                                                          ${reset}"
  emit_line "${red_bg_white_fg}    Intel runtime components were installed.              ${reset}"
  emit_line "${red_bg_white_fg}    Reboot now to fully load the updated driver stack.    ${reset}"
  emit_line "${red_bg_white_fg}                                                          ${reset}"
  emit_line ""
}

# Whiptail selection with a "Select all" item that:
# - when checked -> reopens with ALL items ON
# - when unchecked (from an all-on state) -> reopens with ALL items OFF
tui_select_whiptail() {
  require_cmd whiptail

  # Current ON/OFF state for each app item
  local -a on=()
  local i
  for i in "${!APP_IDS[@]}"; do on+=("OFF"); done

  # Tracks whether we are currently in an "all selected" state
  local all_on=0

  while true; do
    local -a items=()

    # __ALL__ reflects current all_on state
    if ((all_on == 1)); then
      items+=("__ALL__" "Select all apps" "ON")
    else
      items+=("__ALL__" "Select all apps" "OFF")
    fi

    # Append app items
    for i in "${!APP_IDS[@]}"; do
      items+=("${APP_IDS[$i]}" "${APP_NAMES[$i]} - ${APP_DESCS[$i]}" "${on[$i]}")
    done

    local selection
    selection="$(whiptail --title "Omarchy App Installer" \
      --checklist "Toggle Select all, then press OK to apply. Press OK again to proceed." \
      20 78 12 \
      "${items[@]}" \
      3>&1 1>&2 2>&3)" || exit 1

    selection="$(echo "$selection" | tr -d '"')"
    local -a selected=()
    read -r -a selected <<<"$selection"

    # Helper: is __ALL__ checked in this submission?
    local all_checked=0
    local w
    for w in "${selected[@]}"; do
      [[ "$w" == "__ALL__" ]] && all_checked=1
    done

    # If user checked Select all and we weren't all-on => apply all-on and reopen
    if ((all_checked == 1 && all_on == 0)); then
      all_on=1
      for i in "${!on[@]}"; do on[$i]="ON"; done
      whiptail --msgbox "Selected all apps. Press OK to continue." 8 52
      continue
    fi

    # If user unchecked Select all and we were all-on => apply all-off and reopen
    if ((all_checked == 0 && all_on == 1)); then
      all_on=0
      for i in "${!on[@]}"; do on[$i]="OFF"; done
      whiptail --msgbox "Unselected all apps. Press OK to continue." 8 54
      continue
    fi

    # Normal case: update per-item state and return final selection (excluding __ALL__)
    for i in "${!APP_IDS[@]}"; do
      local found=0
      for w in "${selected[@]}"; do
        [[ "$w" == "${APP_IDS[$i]}" ]] && found=1
      done
      if ((found == 1)); then
        on[$i]="ON"
      else
        on[$i]="OFF"
      fi
    done

    # Build output without __ALL__
    local -a out=()
    for w in "${selected[@]}"; do
      [[ "$w" == "__ALL__" ]] && continue
      out+=("$w")
    done

    printf "%s\n" "${out[*]}"
    return 0
  done
}

tui_select_fzf() {
  require_cmd fzf

  local -a rows=()
  local i
  for i in "${!APP_IDS[@]}"; do
    rows+=("${APP_IDS[$i]}\t${APP_NAMES[$i]} - ${APP_DESCS[$i]}")
  done

  # --multi: multi-select
  # --with-nth: display name/desc, but keep id in field 1
  # --bind: add deterministic select-all / clear-all
  local out
  out="$(printf "%b\n" "${rows[@]}" | \
    fzf --multi --prompt="Select apps > " \
        --delimiter=$'\t' --with-nth=2.. \
        --bind 'ctrl-a:select-all' \
        --bind 'ctrl-d:deselect-all' \
        --bind 'ctrl-t:toggle-all' \
        --header $'TAB=toggle  ENTER=confirm  Ctrl-A=all  Ctrl-D=none  Ctrl-T=toggle-all' \
  )" || exit 1

  # Return just IDs (field 1)
  awk -F'\t' '{print $1}' <<<"$out" | paste -sd' ' -
}

tui_select_fallback() {
  warn "whiptail not found; using fallback menu."

  printf "\nSelect apps (e.g. 1 3 5), or 'a' for all:\n\n"
  local idx
  for idx in "${!APP_IDS[@]}"; do
    printf "  %2d) %-16s  %s\n" "$((idx+1))" "${APP_NAMES[$idx]}" "${APP_DESCS[$idx]}"
  done
  printf "\n> "
  read -r line

  if [[ "$line" == "a" || "$line" == "A" ]]; then
    printf "%s\n" "${APP_IDS[*]}"
    return
  fi

  local -a chosen_ids=()
  local -A chosen_set=()
  local n
  for n in $line; do
    [[ "$n" =~ ^[0-9]+$ ]] || continue
    ((n>=1 && n<=${#APP_IDS[@]})) || continue
    local chosen_id="${APP_IDS[$((n-1))]}"
    [[ -n "${chosen_set[$chosen_id]:-}" ]] && continue
    chosen_set["$chosen_id"]=1
    chosen_ids+=("$chosen_id")
  done

  echo "${chosen_ids[*]}"
}

install_selected() {
  local -a selected_ids=("$@")
  ((${#selected_ids[@]} > 0)) || die "No selections made."

  info "Selections: ${selected_ids[*]}"
  info "Log file: $LOG_FILE"

  local -A seen_selected=()
  local sel idx id name script reboot_required
  local installed_any=0
  local needs_reboot=0

  for sel in "${selected_ids[@]}"; do
    [[ -n "${seen_selected[$sel]:-}" ]] && continue
    seen_selected["$sel"]=1

    idx="${APP_INDEX[$sel]-}"
    if [[ -z "$idx" ]]; then
      warn "Ignoring unknown app ID: $sel"
      continue
    fi

    id="${APP_IDS[$idx]}"
    name="${APP_NAMES[$idx]}"
    reboot_required="${APP_REBOOTS[$idx]}"
    script="${APP_SCRIPTS[$idx]}"

    info "==> $name ($id)"

    unset APP_ID APP_NAME APP_DESC APP_REBOOT_REQUIRED
    unset -f app_install 2>/dev/null || true
    # shellcheck disable=SC1090
    source "$script"
    declare -F app_install >/dev/null || die "Missing app_install() in $(basename "$script")"

    LOG_CAPTURE_MODE=1 app_install |& tee -a "$LOG_FILE"
    installed_any=1

    if [[ "$reboot_required" == "1" ]]; then
      needs_reboot=1
    fi
  done

  ((installed_any==1)) || die "None of the selected IDs matched available apps."
  ok "All selected installs completed."

  if ((needs_reboot == 1)); then
    show_reboot_banner
  fi
}

main() {
  local selection

  build_app_registry

  if command -v fzf >/dev/null 2>&1; then
    selection="$(tui_select_fzf)"
  elif command -v whiptail >/dev/null 2>&1; then
    selection="$(tui_select_whiptail)"
  else
    selection="$(tui_select_fallback)"
  fi

  read -r -a selected <<<"$selection"
  install_selected "${selected[@]}"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
