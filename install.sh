#!/usr/bin/env bash
#
# Samsung Galaxy Book 4 fingerprint fix — Fedora installer.
#
# Uses the COPR repository "hichambel/libfprint-galaxybook", which ships
# a patched libfprint with Focaltech MoC support (sensor 2808:6553)
# rebuilt for Fedora — the proper Fedora equivalent of the upstream
# Debian .deb fix.

set -e

# ---------- pretty output --------------------------------------------------
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

# ---------- pre-flight -----------------------------------------------------
if [[ $EUID -ne 0 ]]; then
  err "Run as root: sudo $0"
  exit 1
fi

# Detect Fedora
if [[ ! -r /etc/os-release ]]; then
  err "Cannot read /etc/os-release. Is this Linux?"
  exit 1
fi
# shellcheck disable=SC1091
. /etc/os-release
if [[ "${ID:-}" != "fedora" ]]; then
  err "This installer is for Fedora only (detected: ${ID:-unknown})."
  exit 1
fi
FEDORA_VER="${VERSION_ID:-unknown}"

# Detect the Galaxy Book 4 fingerprint sensor
if ! command -v lsusb >/dev/null 2>&1; then
  warn "lsusb not found; installing usbutils..."
  dnf install -y usbutils
fi
if ! lsusb | grep -q '2808:6553'; then
  err "Focaltech sensor 2808:6553 not detected."
  echo "  This installer only targets Samsung Galaxy Book 4 hardware."
  echo
  echo "  Output of lsusb:"
  lsusb | sed 's/^/    /'
  echo
  err "Aborting."
  exit 1
fi
ok "Detected Focaltech sensor 2808:6553 (Samsung Galaxy Book 4)."

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOTAL_STEPS=10

# ---------- 1. cleanup -----------------------------------------------------
step 1 "$TOTAL_STEPS" "Cleaning up leftovers from any previous manual install"
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

# ---------- 2. dnf-plugins-core --------------------------------------------
step 2 "$TOTAL_STEPS" "Ensuring dnf-plugins-core is available"
dnf install -y dnf-plugins-core

# ---------- 3. enable COPR -------------------------------------------------
step 3 "$TOTAL_STEPS" "Enabling COPR hichambel/libfprint-galaxybook"
COPR_OWNER="hichambel"
COPR_PROJECT="libfprint-galaxybook"
COPR_REPO_ID="copr:copr.fedorainfracloud.org:${COPR_OWNER}:${COPR_PROJECT}"
COPR_REPO_FILE="/etc/yum.repos.d/_copr_${COPR_OWNER}-${COPR_PROJECT}.repo"

if dnf copr enable -y "${COPR_OWNER}/${COPR_PROJECT}" 2>&1 | tee /tmp/copr-enable.log \
   | grep -q "Chroot não encontrado\|Chroot not found"; then
  COPR_NATIVE_OK=0
else
  COPR_NATIVE_OK=1
fi

# Re-check: dnf copr enable can also succeed silently. Trust the .repo file.
if [[ "$COPR_NATIVE_OK" -eq 1 && -f "/etc/yum.repos.d/_copr:copr.fedorainfracloud.org:${COPR_OWNER}:${COPR_PROJECT}.repo" ]] \
   || [[ "$COPR_NATIVE_OK" -eq 1 && -f "${COPR_REPO_FILE}" ]]; then
  ok "Native chroot enabled for Fedora ${FEDORA_VER}."
else
  warn "COPR has no native build for Fedora ${FEDORA_VER}."
  warn "Falling back to fedora-43-x86_64 (ABI-compatible)."
  echo "  If installation fails, please request a fedora-${FEDORA_VER} build at:"
  echo "    https://copr.fedorainfracloud.org/coprs/${COPR_OWNER}/${COPR_PROJECT}/"
  CHROOT="fedora-43-x86_64"
  cat > "${COPR_REPO_FILE}" <<EOF
[${COPR_REPO_ID}]
name=Copr repo for ${COPR_PROJECT} owned by ${COPR_OWNER} (using ${CHROOT})
baseurl=https://download.copr.fedorainfracloud.org/results/${COPR_OWNER}/${COPR_PROJECT}/${CHROOT}/
type=rpm-md
skip_if_unavailable=False
gpgcheck=1
gpgkey=https://download.copr.fedorainfracloud.org/results/${COPR_OWNER}/${COPR_PROJECT}/pubkey.gpg
repo_gpgcheck=0
enabled=1
enabled_metadata=1
EOF
  dnf -y --refresh makecache --repo "${COPR_REPO_ID}"
fi

# ---------- 4. install patched packages ------------------------------------
step 4 "$TOTAL_STEPS" "Installing fprintd, fprintd-pam and the patched libfprint"
dnf install -y fprintd fprintd-pam libfprint
COPR_NVR="$(dnf --disablerepo='*' --enablerepo="${COPR_REPO_ID}" \
            repoquery --qf '%{name}-%{version}-%{release}' libfprint 2>/dev/null | head -n1 || true)"
if [[ -n "$COPR_NVR" ]]; then
  CURRENT_NVR="$(rpm -q --qf '%{name}-%{version}-%{release}' libfprint 2>/dev/null || true)"
  if [[ "$COPR_NVR" != "$CURRENT_NVR" ]]; then
    warn "Forcing the COPR build (${COPR_NVR}) over the stock one..."
    dnf install -y --allowerasing "${COPR_NVR}" || dnf reinstall -y "${COPR_NVR}" || true
  else
    ok "COPR build is already installed (${CURRENT_NVR})."
  fi
fi

# ---------- 5. authselect --------------------------------------------------
step 5 "$TOTAL_STEPS" "Enabling PAM fingerprint feature (login / sudo / GDM)"
# `authselect apply-changes` rewrites /etc/pam.d/*. GDM watches those files
# and may force-logout the active graphical session when they change. To
# avoid that surprise, we only apply when the feature is not already active.
if authselect current 2>/dev/null | grep -q '^- with-fingerprint'; then
  ok "Fingerprint login is already enabled — nothing to change."
else
  echo
  warn "IMPORTANT — read this before continuing:"
  echo
  echo "  The next step turns ON fingerprint login for sudo and the login"
  echo "  screen. To do that, this installer changes some system files."
  echo
  echo "  ${C_BOLD}Possible side effect:${C_RESET} your desktop may close itself and send"
  echo "  you back to the login screen, AS IF YOU CLICKED LOG OUT."
  echo "  You will NOT lose any saved files, but UNSAVED work in open"
  echo "  apps (browser tabs, text editors, etc.) ${C_BOLD}will be lost${C_RESET}."
  echo
  echo "  → Save your work first."
  echo "  → Close apps you don't want to lose state from."
  echo "  → Then come back and answer 'y'."
  echo
  echo "  This only happens once. Future runs of this installer will skip"
  echo "  this step automatically."
  echo
  read -rp "Ready to continue? [y/N] " ans
  case "${ans,,}" in
    y|yes)
      authselect enable-feature with-fingerprint || true
      authselect apply-changes || true
      ok "Fingerprint login enabled."
      ;;
    *)
      warn "Skipped. To enable later, run:"
      echo "    sudo authselect enable-feature with-fingerprint"
      echo "    sudo authselect apply-changes"
      echo "  (or simply re-run this installer — it will offer it again)"
      ;;
  esac
fi

# ---------- 6. systemd resume drop-in --------------------------------------
step 6 "$TOTAL_STEPS" "Installing systemd unit to restart fprintd after suspend/resume"
install -D -m 0644 "$REPO_DIR/systemd/fprintd-resume.service" \
  /etc/systemd/system/fprintd-resume.service
systemctl daemon-reload
systemctl enable fprintd-resume.service >/dev/null 2>&1 || true
ok "fprintd-resume.service enabled."

# ---------- 7. version-lock ------------------------------------------------
step 7 "$TOTAL_STEPS" "Locking libfprint version to prevent future upgrades from breaking it"
if ! rpm -q python3-dnf-plugin-versionlock >/dev/null 2>&1; then
  dnf install -y python3-dnf-plugin-versionlock
fi
dnf versionlock add libfprint || true
ok "libfprint is now version-locked."
warn "If you ever need to unlock it (at your own risk):"
echo "    sudo dnf versionlock delete libfprint"

# ---------- 8. udev + service refresh --------------------------------------
step 8 "$TOTAL_STEPS" "Refreshing linker cache, udev rules and fprintd service"
ldconfig
udevadm control --reload-rules || true
udevadm trigger || true
systemctl restart fprintd || true
ok "Service restarted."

# ---------- 9. summary -----------------------------------------------------
step 9 "$TOTAL_STEPS" "Installation summary"
INSTALLED_NVR="$(rpm -qf /usr/lib64/libfprint-2.so.2 2>/dev/null || echo unknown)"
echo "  libfprint package : ${INSTALLED_NVR}"
echo "  fprintd service   : $(systemctl is-active fprintd 2>/dev/null || echo unknown)"
echo "  Resume hook       : $(systemctl is-enabled fprintd-resume.service 2>/dev/null || echo unknown)"
echo "  Version lock      : active (libfprint)"
echo
ok "All done."

# ---------- 10. next steps -------------------------------------------------
step 10 "$TOTAL_STEPS" "Next step: enroll a fingerprint"

cat <<EOF

Fedora has no graphical interface for fingerprint enrollment, so it must
be done from the terminal. The installer does NOT do it for you because
the enrollment must run as your normal user (not root / sudo) so that
the desktop's authentication agent can authorise it.

${C_BOLD}To enroll your fingerprint, open a NEW terminal as your normal user
(without sudo) and run:${C_RESET}

    cd "$REPO_DIR"
    ./fingerprint-enroll.sh

That helper offers an interactive menu to:
  * enroll one or more fingers
  * test (verify) a finger
  * list and delete enrolled fingers

You can also run it any time later to add more fingers.

----------------------------------------
Useful commands (run as your user, no sudo):
  fprintd-list \$USER          # show enrolled fingers
  fprintd-verify              # test
  ./fingerprint-enroll.sh     # enroll/verify/delete (interactive)

To uninstall everything (and remove enrollments):
  sudo ./uninstall.sh
----------------------------------------
EOF
