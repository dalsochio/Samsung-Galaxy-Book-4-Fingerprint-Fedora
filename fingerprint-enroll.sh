#!/usr/bin/env bash
#
# fingerprint-enroll.sh
# Standalone fingerprint manager for Fedora.
#
# Usage:
#   ./fingerprint-enroll.sh                          # interactive menu
#   ./fingerprint-enroll.sh list
#   ./fingerprint-enroll.sh enroll <finger> [<finger> ...]
#   ./fingerprint-enroll.sh verify [<finger>]
#   ./fingerprint-enroll.sh delete <finger>
#   ./fingerprint-enroll.sh delete-all
#
# Valid finger names:
#   left-thumb         right-thumb
#   left-index-finger  right-index-finger
#   left-middle-finger right-middle-finger
#   left-ring-finger   right-ring-finger
#   left-little-finger right-little-finger

set -u

# ---------- pretty output --------------------------------------------------
if [[ -t 1 ]]; then
  C_RESET="\033[0m"
  C_BOLD="\033[1m"
  C_RED="\033[31m"
  C_GREEN="\033[32m"
  C_YELLOW="\033[33m"
  C_BLUE="\033[34m"
  C_DIM="\033[2m"
else
  C_RESET=""; C_BOLD=""; C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""; C_DIM=""
fi

info()  { printf "${C_BLUE}==>${C_RESET} %s\n" "$*"; }
ok()    { printf "${C_GREEN}✓${C_RESET} %s\n" "$*"; }
warn()  { printf "${C_YELLOW}!${C_RESET} %s\n" "$*"; }
err()   { printf "${C_RED}✗${C_RESET} %s\n" "$*" >&2; }
title() { printf "\n${C_BOLD}%s${C_RESET}\n" "$*"; }

# ---------- constants ------------------------------------------------------
FINGERS=(
  left-thumb          right-thumb
  left-index-finger   right-index-finger
  left-middle-finger  right-middle-finger
  left-ring-finger    right-ring-finger
  left-little-finger  right-little-finger
)

# Determine which user to manage fingerprints for.
# Priority: the actual current EUID, then $USER, then $SUDO_USER.
# We deliberately do NOT trust $SUDO_USER first because the helper may
# have been launched via `sudo -u someuser` from a root shell, in which
# case $SUDO_USER still points at root.
USER_NAME="$(id -un 2>/dev/null || echo "${USER:-${SUDO_USER:-}}")"

# Refuse to run for the root account: enrolling fingerprints under root is
# almost never what the user wants, and fprintd's DBus policy denies it
# anyway (PermissionDenied: setusername).
if [[ "$USER_NAME" == "root" || "$EUID" -eq 0 ]]; then
  printf "${C_RED}✗${C_RESET} This script must run as your normal user, not root.\n" >&2
  echo "" >&2
  echo "  If you launched it via 'sudo', exit and run it again WITHOUT sudo:" >&2
  echo "      ./fingerprint-enroll.sh" >&2
  echo "" >&2
  echo "  To target a specific user from a root shell:" >&2
  echo "      sudo -u <username> ./fingerprint-enroll.sh" >&2
  exit 1
fi

# ---------- helpers --------------------------------------------------------
require_fprintd() {
  if ! command -v fprintd-enroll >/dev/null 2>&1; then
    err "fprintd is not installed. Run install.sh first."
    exit 1
  fi
  if ! systemctl is-active --quiet fprintd 2>/dev/null; then
    info "Starting fprintd service..."
    if ! systemctl start fprintd 2>/dev/null; then
      warn "Could not auto-start fprintd. You may need: sudo systemctl start fprintd"
    fi
    sleep 1
  fi
}

is_valid_finger() {
  local f="$1"
  for valid in "${FINGERS[@]}"; do
    [[ "$f" == "$valid" ]] && return 0
  done
  return 1
}

list_finger_names() {
  printf "${C_DIM}Valid finger names:${C_RESET}\n"
  local i=1
  for f in "${FINGERS[@]}"; do
    printf "  %2d) %s\n" "$i" "$f"
    i=$((i + 1))
  done
}

# Returns enrolled fingers (one per line) by parsing fprintd-list.
get_enrolled() {
  fprintd-list "$USER_NAME" 2>/dev/null \
    | grep -oE '(left|right)-(thumb|index-finger|middle-finger|ring-finger|little-finger)' \
    | sort -u
}

is_enrolled() {
  local f="$1"
  get_enrolled | grep -qx "$f"
}

prompt_finger() {
  local prompt="${1:-Pick a finger}"
  local i=1
  echo
  for f in "${FINGERS[@]}"; do
    printf "  %2d) %s\n" "$i" "$f"
    i=$((i + 1))
  done
  echo
  local choice
  while true; do
    read -rp "$prompt [1-${#FINGERS[@]}]: " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#FINGERS[@]} )); then
      echo "${FINGERS[$((choice - 1))]}"
      return 0
    fi
    err "Invalid choice."
  done
}

explain_enroll() {
  cat <<EOF

${C_BOLD}How fingerprint enrollment works${C_RESET}
  * Place your finger ${C_BOLD}flat${C_RESET} and ${C_BOLD}centered${C_RESET} on the sensor.
  * ${C_BOLD}Lift${C_RESET} your finger completely between touches.
  * Expect 8 to 15 touches until you see ${C_GREEN}enroll-completed${C_RESET}.
  * Status messages mean:
      ${C_GREEN}enroll-stage-passed${C_RESET}        keep going, that touch was OK
      ${C_YELLOW}enroll-finger-not-centered${C_RESET} reposition and try again
      ${C_YELLOW}enroll-retry-scan${C_RESET}          lift and touch again
      ${C_GREEN}enroll-completed${C_RESET}           done, finger is registered

EOF
}

# ---------- subcommands ----------------------------------------------------
cmd_list() {
  title "Enrolled fingerprints for user: $USER_NAME"
  local enrolled
  enrolled="$(get_enrolled)"
  if [[ -z "$enrolled" ]]; then
    warn "No fingerprints enrolled yet."
    echo "  Enroll one with: ${C_BOLD}$0 enroll right-index-finger${C_RESET}"
    return 0
  fi
  while IFS= read -r f; do
    printf "  ${C_GREEN}●${C_RESET} %s\n" "$f"
  done <<< "$enrolled"
}

cmd_enroll_one() {
  local finger="$1"

  if ! is_valid_finger "$finger"; then
    err "Invalid finger name: $finger"
    list_finger_names
    return 2
  fi

  if is_enrolled "$finger"; then
    warn "$finger is already enrolled."
    read -rp "Overwrite? [y/N] " ans
    case "${ans,,}" in
      y|yes)
        info "Deleting old enrollment for $finger..."
        fprintd-delete "$USER_NAME" -f "$finger" >/dev/null 2>&1 || true
        ;;
      *)
        warn "Skipping $finger."
        return 0
        ;;
    esac
  fi

  title "Enrolling: $finger"
  explain_enroll
  read -rp "Press ENTER to start (or Ctrl+C to cancel)..." _

  if fprintd-enroll -f "$finger"; then
    ok "$finger enrolled."

    read -rp "Test it now? [Y/n] " ans
    case "${ans,,}" in
      ""|y|yes)
        cmd_verify "$finger"
        ;;
    esac
    return 0
  else
    err "Enrollment failed for $finger."
    return 1
  fi
}

cmd_enroll() {
  local fingers=("$@")

  if [[ ${#fingers[@]} -eq 0 ]]; then
    fingers=( "$(prompt_finger 'Which finger to enroll?')" )
  fi

  local f rc=0
  declare -A results
  for f in "${fingers[@]}"; do
    if cmd_enroll_one "$f"; then
      results["$f"]="enrolled"
    else
      results["$f"]="FAILED"
      rc=1
    fi
  done

  if [[ ${#fingers[@]} -gt 1 ]]; then
    title "Enrollment summary"
    for f in "${fingers[@]}"; do
      printf "  %-22s %s\n" "$f" "${results[$f]}"
    done
  fi
  return "$rc"
}

cmd_verify() {
  local finger="${1:-}"

  if [[ -z "$finger" ]]; then
    local enrolled
    enrolled="$(get_enrolled)"
    if [[ -z "$enrolled" ]]; then
      err "No fingerprints enrolled. Enroll one first."
      return 1
    fi
    if [[ "$(echo "$enrolled" | wc -l)" -eq 1 ]]; then
      finger="$enrolled"
    else
      title "Which finger to verify?"
      mapfile -t opts <<< "$enrolled"
      local i=1
      for f in "${opts[@]}"; do
        printf "  %2d) %s\n" "$i" "$f"
        i=$((i + 1))
      done
      local choice
      read -rp "Pick [1-${#opts[@]}]: " choice
      if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#opts[@]} )); then
        finger="${opts[$((choice - 1))]}"
      else
        err "Invalid choice."
        return 1
      fi
    fi
  fi

  if ! is_enrolled "$finger"; then
    err "$finger is not enrolled."
    return 1
  fi

  title "Verifying: $finger"
  echo "  Touch the sensor with your $finger..."
  if fprintd-verify -f "$finger"; then
    ok "Match. Fingerprint works."
    return 0
  else
    err "No match (or scan failed)."
    return 1
  fi
}

cmd_delete() {
  local finger="${1:-}"

  if [[ -z "$finger" ]]; then
    local enrolled
    enrolled="$(get_enrolled)"
    if [[ -z "$enrolled" ]]; then
      warn "Nothing to delete."
      return 0
    fi
    title "Which finger to delete?"
    mapfile -t opts <<< "$enrolled"
    local i=1
    for f in "${opts[@]}"; do
      printf "  %2d) %s\n" "$i" "$f"
      i=$((i + 1))
    done
    local choice
    read -rp "Pick [1-${#opts[@]}]: " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#opts[@]} )); then
      finger="${opts[$((choice - 1))]}"
    else
      err "Invalid choice."
      return 1
    fi
  fi

  if ! is_valid_finger "$finger"; then
    err "Invalid finger name: $finger"
    return 2
  fi

  read -rp "Delete enrollment for $finger? [y/N] " ans
  case "${ans,,}" in
    y|yes) ;;
    *) warn "Cancelled."; return 0 ;;
  esac

  if fprintd-delete "$USER_NAME" -f "$finger"; then
    ok "Deleted $finger."
  else
    err "Could not delete $finger."
    return 1
  fi
}

cmd_delete_all() {
  read -rp "Delete ALL enrolled fingerprints for $USER_NAME? [y/N] " ans
  case "${ans,,}" in
    y|yes) ;;
    *) warn "Cancelled."; return 0 ;;
  esac
  if fprintd-delete "$USER_NAME"; then
    ok "All fingerprints deleted."
  else
    err "Failed to delete fingerprints."
    return 1
  fi
}

# ---------- interactive menu ----------------------------------------------
interactive_menu() {
  while true; do
    title "Fingerprint manager (user: $USER_NAME)"

    local enrolled
    enrolled="$(get_enrolled)"
    echo
    if [[ -z "$enrolled" ]]; then
      printf "  ${C_DIM}Currently enrolled: (none)${C_RESET}\n"
    else
      echo "  Currently enrolled:"
      while IFS= read -r f; do
        printf "    ${C_GREEN}●${C_RESET} %s\n" "$f"
      done <<< "$enrolled"
    fi
    echo
    cat <<EOF
  e) Enroll a new finger
  v) Verify a finger (test)
  d) Delete a finger
  D) Delete ALL fingers
  l) List enrolled fingers
  q) Quit
EOF
    echo
    local action
    read -rp "> " action
    echo
    case "$action" in
      e|E) cmd_enroll ;;
      v) cmd_verify ;;
      d) cmd_delete ;;
      D) cmd_delete_all ;;
      l|L) cmd_list ;;
      q|Q|"") info "Bye."; return 0 ;;
      *) err "Unknown option: $action" ;;
    esac
  done
}

# ---------- main -----------------------------------------------------------
usage() {
  cat <<EOF
Usage:
  $0                                   interactive menu
  $0 list
  $0 enroll <finger> [<finger> ...]
  $0 verify [<finger>]
  $0 delete <finger>
  $0 delete-all

$(list_finger_names)
EOF
}

main() {
  require_fprintd

  if [[ $# -eq 0 ]]; then
    interactive_menu
    return $?
  fi

  local sub="$1"
  shift
  case "$sub" in
    list)        cmd_list "$@" ;;
    enroll)      cmd_enroll "$@" ;;
    verify)      cmd_verify "$@" ;;
    delete)      cmd_delete "$@" ;;
    delete-all)  cmd_delete_all "$@" ;;
    -h|--help|help) usage ;;
    *) err "Unknown subcommand: $sub"; usage; return 2 ;;
  esac
}

main "$@"
