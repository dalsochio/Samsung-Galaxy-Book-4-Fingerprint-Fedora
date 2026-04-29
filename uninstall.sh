#!/usr/bin/env bash
#
# Full rollback of install.sh:
#   * deletes ALL enrolled fingerprints (per user)
#   * disables and removes the fprintd-resume systemd unit
#   * removes the libfprint version-lock
#   * disables PAM with-fingerprint feature
#   * removes the COPR repository
#   * reinstalls the stock Fedora libfprint
#
# Usage:
#   sudo ./uninstall.sh           # interactive confirmation
#   sudo ./uninstall.sh --yes     # non-interactive

set -e

if [[ -t 1 ]]; then
  C_RESET="\033[0m"; C_BOLD="\033[1m"
  C_RED="\033[31m"; C_GREEN="\033[32m"; C_YELLOW="\033[33m"; C_BLUE="\033[34m"
else
  C_RESET=""; C_BOLD=""; C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""
fi
step() { printf "\n${C_BOLD}${C_BLUE}[%s/%s]${C_RESET} ${C_BOLD}%s${C_RESET}\n" "$1" "$2" "$3"; }
ok()   { printf "${C_GREEN}✓${C_RESET} %s\n" "$*"; }
warn() { printf "${C_YELLOW}!${C_RESET} %s\n" "$*"; }
err()  { printf "${C_RED}✗${C_RESET} %s\n" "$*" >&2; }

if [[ $EUID -ne 0 ]]; then
  err "Run as root: sudo $0"
  exit 1
fi

ASSUME_YES=0
if [[ "${1:-}" == "--yes" || "${1:-}" == "-y" ]]; then
  ASSUME_YES=1
fi

cat <<EOF
${C_BOLD}This will:${C_RESET}
  * delete ALL enrolled fingerprints from every user on this system
  * disable and remove the fprintd-resume systemd unit
  * unlock the libfprint version-lock
  * disable the PAM with-fingerprint feature (login/sudo via finger)
  * remove the hichambel/libfprint-galaxybook COPR repository
  * reinstall the stock Fedora libfprint

EOF

if [[ "$ASSUME_YES" -ne 1 ]]; then
  read -rp "Continue? [y/N] " ans
  case "${ans,,}" in
    y|yes) ;;
    *) warn "Aborted."; exit 0 ;;
  esac
fi

TOTAL=8

# ---------- 1. delete enrollments -----------------------------------------
step 1 "$TOTAL" "Deleting all enrolled fingerprints"
if command -v fprintd-delete >/dev/null 2>&1; then
  if [[ -d /var/lib/fprint ]]; then
    for entry in /var/lib/fprint/*; do
      [[ -d "$entry" ]] || continue
      uname="$(basename "$entry")"
      if id "$uname" >/dev/null 2>&1; then
        warn "deleting fingerprints for user: $uname"
        fprintd-delete "$uname" >/dev/null 2>&1 || true
      fi
    done
    rm -rf /var/lib/fprint/* 2>/dev/null || true
  fi
  ok "Enrollments cleared."
else
  warn "fprintd-delete not available; skipping."
fi

# ---------- 2. disable resume drop-in -------------------------------------
step 2 "$TOTAL" "Removing fprintd-resume systemd unit"
systemctl disable --now fprintd-resume.service >/dev/null 2>&1 || true
rm -f /etc/systemd/system/fprintd-resume.service
systemctl daemon-reload
ok "Resume hook removed."

# ---------- 3. remove version-lock ----------------------------------------
step 3 "$TOTAL" "Removing libfprint version-lock"
if rpm -q python3-dnf-plugin-versionlock >/dev/null 2>&1; then
  dnf versionlock delete libfprint >/dev/null 2>&1 || true
  ok "Version-lock removed."
else
  warn "versionlock plugin not installed; skipping."
fi

# ---------- 4. disable PAM feature ----------------------------------------
step 4 "$TOTAL" "Disabling PAM with-fingerprint feature"
authselect disable-feature with-fingerprint >/dev/null 2>&1 || true
authselect apply-changes >/dev/null 2>&1 || true
ok "PAM feature disabled."

# ---------- 5. remove unmanaged files -------------------------------------
step 5 "$TOTAL" "Removing any unmanaged files left behind by manual installs"
for f in \
  /usr/lib64/libfprint-2.so.2.0.0 \
  /usr/lib64/libfprint-2.so.2 \
  /usr/lib64/libfprint-2.so \
  /usr/lib64/girepository-1.0/FPrint-2.0.typelib \
  /usr/lib64/pkgconfig/libfprint-2.pc \
  /usr/share/gir-1.0/FPrint-2.0.gir \
  /usr/lib/udev/rules.d/70-libfprint-2.rules; do
  if [[ -e "$f" ]] && ! rpm -qf "$f" >/dev/null 2>&1; then
    warn "removing unmanaged file: $f"
    rm -f "$f"
  fi
done
rm -f /usr/include/libfprint-2/*.h 2>/dev/null || true
rmdir /usr/include/libfprint-2 2>/dev/null || true
ok "Cleanup done."

# ---------- 6. remove COPR ------------------------------------------------
step 6 "$TOTAL" "Removing the COPR repository"
dnf copr remove -y hichambel/libfprint-galaxybook >/dev/null 2>&1 || true
rm -f /etc/yum.repos.d/_copr_hichambel-libfprint-galaxybook.repo
rm -f "/etc/yum.repos.d/_copr:copr.fedorainfracloud.org:hichambel:libfprint-galaxybook.repo"
dnf clean metadata >/dev/null 2>&1 || true
ok "COPR removed."

# ---------- 7. restore stock libfprint ------------------------------------
step 7 "$TOTAL" "Restoring stock Fedora libfprint"
# The COPR build may have a higher Epoch/Release than stock — use distro-sync
# to ensure we drop back to whatever Fedora currently ships.
if ! dnf distro-sync -y libfprint; then
  warn "distro-sync failed, trying reinstall..."
  dnf reinstall -y libfprint || true
fi
ok "Stock libfprint restored."

# ---------- 8. refresh ----------------------------------------------------
step 8 "$TOTAL" "Refreshing linker cache, udev rules and fprintd service"
ldconfig
udevadm control --reload-rules || true
udevadm trigger || true
systemctl restart fprintd || true

cat <<EOF

----------------------------------------
${C_GREEN}Uninstall complete.${C_RESET}

  libfprint package : $(rpm -q --qf '%{name}-%{version}-%{release}\n' libfprint 2>/dev/null || echo unknown)
  fprintd service   : $(systemctl is-active fprintd 2>/dev/null || echo unknown)
  Enrolled fingers  : (none)

The system is back to stock Fedora behaviour. The fingerprint sensor
is no longer supported.
----------------------------------------
EOF
