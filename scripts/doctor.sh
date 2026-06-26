#!/usr/bin/env bash
# scripts/doctor.sh — Health-check and diagnostic tool
# Run with: dotfiles doctor
# Checks 15+ system conditions and reports status
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "${DOTFILES_DIR}/lib/log.sh"
source "${DOTFILES_DIR}/lib/link.sh"

PORCELAIN=false
GUI=false
FULL=false
for arg in "$@"; do
  case "$arg" in
    --porcelain) PORCELAIN=true ;;
    --gui) GUI=true ;;
    --full) FULL=true ;;
  esac
done

if [[ "${GUI}" == "true" ]]; then
  exec python3 "${DOTFILES_DIR}/apps/doctor-dashboard/lumina-doctor-dashboard.py"
fi

if [[ "${PORCELAIN}" == "true" ]]; then
  log::header() { :; }
  log::section() { :; }
  log::sep() { :; }
fi

LOG_FILE="${DOTFILES_DIR}/logs/doctor-$(date +%Y%m%d-%H%M%S).log"

log::header "lumina-dots Doctor — System Health Check"

ERRORS=0
WARNINGS=0

pass() {
  if [[ "${PORCELAIN}" == "true" ]]; then
    printf 'PASS|%s\n' "$1"
  else
    log::success "$1"
  fi
}
fail() {
  if [[ "${PORCELAIN}" == "true" ]]; then
    printf 'FAIL|%s\n' "$1"
  else
    log::error "$1"
  fi
  ((ERRORS++)) || true
}
warn() {
  if [[ "${PORCELAIN}" == "true" ]]; then
    printf 'WARN|%s\n' "$1"
  else
    log::warn "$1"
  fi
  ((WARNINGS++)) || true
}
info() {
  if [[ "${PORCELAIN}" == "true" ]]; then
    printf 'INFO|%s\n' "$1"
  else
    log::info "$1"
  fi
}

# ─── 1. Symlinks ──────────────────────────────────────────────────────────────
log::section "1. Config Symlinks"
if [[ "${PORCELAIN}" == "true" ]]; then
  if link::verify >/dev/null 2>&1; then
    pass "All managed dotfile links are healthy"
  else
    fail "Managed dotfile link verification failed"
  fi
else
  if link::verify; then
    pass "All managed dotfile links are healthy"
  else
    fail "Managed dotfile link verification failed"
  fi
fi

# ─── 2. Required packages ─────────────────────────────────────────────────────
log::section "2. Required Packages"
declare -a REQUIRED_PKGS=(
  hyprland uwsm hypridle hyprlock ags-hyprpanel-git
  walker-bin ghostty zsh starship neovim
  gtk4 libadwaita gtk4-layer-shell python-gobject python-cairo python-dbus-next
  pipewire wireplumber matugen-bin
  brightnessctl playerctl wl-clipboard
  cliphist grimblast-git satty wlogout
  xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
  hyprpolkitagent libgtop
)

for pkg in "${REQUIRED_PKGS[@]}"; do
  if pacman -Qi "${pkg}" &>/dev/null; then
    pass "Package: ${pkg}"
  else
    fail "Not installed: ${pkg}"
  fi
done

if command -v swww >/dev/null 2>&1 && command -v swww-daemon >/dev/null 2>&1; then
  pass "Wallpaper API: swww"
else
  fail "swww command wrappers missing — run scripts/system/install-swww-compat.sh after package install"
fi

if pacman -Qi awww &>/dev/null || pacman -Qi swww &>/dev/null; then
  pass "Wallpaper package provider installed"
else
  fail "Wallpaper package provider missing"
fi

if command -v paru &>/dev/null; then
  pass "AUR helper: paru"
else
  fail "paru command not found"
fi

if pacman -Qi linux-lts &>/dev/null; then
  pass "Recommended fallback kernel: linux-lts"
else
  warn "Recommended fallback kernel missing: linux-lts"
fi

# ─── 3. Systemd user services ─────────────────────────────────────────────────
log::section "3. Systemd User Services"
declare -a USER_SERVICES=(
  "pipewire.service"
  "wireplumber.service"
  "lumina-shell.service"
)

for svc in "${USER_SERVICES[@]}"; do
  if systemctl --user is-active "${svc}" &>/dev/null; then
    pass "Service active: ${svc}"
  else
    warn "Service not active: ${svc}"
  fi
done

# ─── 4. Daemon conflict check ────────────────────────────────────────────────
log::section "4. Conflicting Daemons"
declare -a CONFLICT_PKGS=(dunst mako notification-daemon)
FOUND_CONFLICT=false
for pkg in "${CONFLICT_PKGS[@]}"; do
  if pacman -Qi "${pkg}" &>/dev/null; then
    fail "Conflicting notification daemon installed: ${pkg} (conflicts with Hyprpanel)"
    FOUND_CONFLICT=true
  fi
done
if [[ "${FOUND_CONFLICT}" == "false" ]]; then
  pass "No conflicting notification daemons"
fi

# ─── 5. NVIDIA KMS check ──────────────────────────────────────────────────────
log::section "5. NVIDIA Configuration (LOQ 15IRX9)"
if lsmod | grep -q nvidia 2>/dev/null; then
  # Check KMS is enabled
  if cat /sys/module/nvidia_drm/parameters/modeset 2>/dev/null | grep -q "Y"; then
    pass "NVIDIA DRM modeset enabled"
  else
    fail "NVIDIA DRM modeset NOT enabled — run: scripts/install/05-hardware.sh"
  fi

  # Check S0ix power management
  if [[ -f /etc/modprobe.d/nvidia.conf ]] && grep -q "NVreg_EnableS0ixPowerManagement=1" /etc/modprobe.d/nvidia.conf; then
    pass "NVIDIA S0ix power management configured"
  else
    warn "NVIDIA S0ix not configured — suspend/resume may fail"
  fi
else
  info "NVIDIA not loaded (may be normal if in iGPU-only mode)"
fi

# ─── 6. Backup (filesystem-aware) ────────────────────────────────────────────
log::section "6. Backup"
ROOT_FSTYPE="$(findmnt -n -o FSTYPE /)"
if [[ "${ROOT_FSTYPE}" == "btrfs" ]]; then
  if [[ -f /etc/snapper/configs/root ]]; then
    pass "Snapper root config exists"
    if sudo snapper -c root list &>/dev/null 2>&1; then
      SNAPSHOT_COUNT="$(sudo snapper -c root list | grep -c "^[0-9]" || echo 0)"
      [[ "${SNAPSHOT_COUNT}" -gt 0 ]] &&
        pass "Snapshots exist: ${SNAPSHOT_COUNT}" ||
        warn "No snapshots found — run snapper manually"
    fi
  else
    warn "Snapper not configured for btrfs root"
  fi
elif [[ "${ROOT_FSTYPE}" == "ext4" ]]; then
  if command -v timeshift &>/dev/null; then
    pass "timeshift installed"
    if sudo timeshift --list &>/dev/null 2>&1; then
      SNAP_COUNT="$(sudo timeshift --list 2>/dev/null | grep -c "^[0-9]" || echo 0)"
      [[ "${SNAP_COUNT}" -gt 0 ]] &&
        pass "Timeshift snapshots exist: ${SNAP_COUNT}" ||
        warn "No Timeshift snapshots yet — run: sudo timeshift --create"
    fi
  else
    warn "timeshift not installed — install from packages/pacman-desktop.txt"
  fi
else
  warn "Unknown root filesystem (${ROOT_FSTYPE}); backup check skipped"
fi

# ─── 7. XDG Portals ──────────────────────────────────────────────────────────
log::section "7. XDG Portals"
if [[ -f "${HOME}/.config/xdg-desktop-portal/hyprland-portals.conf" ]]; then
  pass "XDG portal config present"
else
  warn "XDG portal config missing — run: scripts/install/06-services.sh"
fi

# Check both portal implementations are installed
for portal in xdg-desktop-portal-hyprland xdg-desktop-portal-gtk; do
  if pacman -Qi "${portal}" &>/dev/null; then
    pass "Portal: ${portal}"
  else
    fail "Portal not installed: ${portal}"
  fi
done

# ─── 8. Matugen Theme Pipeline ────────────────────────────────────────────────
log::section "8. Matugen Theme Pipeline"
if command -v matugen &>/dev/null; then
  pass "matugen installed"

  # BUG 2 FIX: Templates use `hex_stripped` which requires matugen >= 0.10.0.
  # Older versions silently produce empty color values in all configs.
  MATUGEN_VERSION="$(matugen --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1 || echo "0.0.0")"
  MATUGEN_MAJOR="$(echo "${MATUGEN_VERSION}" | cut -d. -f1)"
  MATUGEN_MINOR="$(echo "${MATUGEN_VERSION}" | cut -d. -f2)"

  if [[ "${MATUGEN_MAJOR}" -gt 0 ]] || [[ "${MATUGEN_MAJOR}" -eq 0 && "${MATUGEN_MINOR}" -ge 10 ]]; then
    pass "matugen version ${MATUGEN_VERSION} (>= 0.10.0 — hex_stripped API supported)"
  else
    fail "matugen version ${MATUGEN_VERSION} is too old — requires >= 0.10.0 for hex_stripped template API. Upgrade: paru -S matugen-bin"
  fi
else
  fail "matugen not installed"
fi

if [[ -f "${HOME}/.config/hypr/colors.conf" ]]; then
  pass "Hyprland colors.conf exists (theme applied)"
else
  warn "colors.conf missing — run: dotfiles theme <wallpaper>"
fi

# ─── 9. Colors.conf fallback ──────────────────────────────────────────────────
log::section "9. Hyprland Config Validity"
if command -v hyprctl &>/dev/null; then
  if hyprctl monitors &>/dev/null 2>&1; then
    pass "Hyprland is running"
    # Validate config (hyprctl doesn't have --check but we can try reload)
    info "Hyprland session active"
  else
    info "Not in Hyprland session (OK during install)"
  fi
fi

# Check colors.conf is sourced
if grep -q "colors.conf" "${HOME}/.config/hypr/hyprland.conf" 2>/dev/null; then
  pass "colors.conf is sourced in hyprland.conf"
else
  warn "colors.conf not sourced — theme colors won't apply"
fi

# ─── 10. TTY autologin ────────────────────────────────────────────────────────
log::section "10. TTY Autologin"
AUTOLOGIN_CONF=""
for candidate in \
  "/etc/systemd/system/getty@tty1.service.d/override.conf" \
  "/etc/systemd/system/getty@tty1.service.d/autologin.conf"; do
  if [[ -f "${candidate}" ]]; then
    AUTOLOGIN_CONF="${candidate}"
    break
  fi
done

if [[ -n "${AUTOLOGIN_CONF}" ]]; then
  if grep -q "autologin ${USER}" "${AUTOLOGIN_CONF}"; then
    pass "TTY1 autologin configured for ${USER}"
  else
    warn "TTY1 autologin exists but may be for different user"
  fi
else
  warn "TTY1 autologin not configured — run: scripts/configure-autologin.sh"
fi

# ─── 11. UWSM ────────────────────────────────────────────────────────────────
log::section "11. UWSM Session Management"
if command -v uwsm &>/dev/null; then
  pass "uwsm installed"
  if grep -q "uwsm start" "${HOME}/.zprofile" 2>/dev/null; then
    pass "UWSM launch in .zprofile"
  else
    fail "UWSM not configured in .zprofile — Hyprland won't auto-start"
  fi
else
  fail "uwsm not installed"
fi

# ─── 12. Polkit ───────────────────────────────────────────────────────────────
log::section "12. Polkit"
if pacman -Qi hyprpolkitagent &>/dev/null; then
  pass "hyprpolkitagent installed"
else
  fail "hyprpolkitagent not installed — GUI apps needing auth will fail"
fi

# ─── 13. Battery health ──────────────────────────────────────────────────────
log::section "13. Battery Health"
BATTERY_DIR="$(find /sys/class/power_supply -maxdepth 1 -type l -name 'BAT*' 2>/dev/null | head -n1 || true)"
if [[ -n "${BATTERY_DIR}" ]]; then
  FULL_FILE="${BATTERY_DIR}/charge_full"
  DESIGN_FILE="${BATTERY_DIR}/charge_full_design"
  [[ -f "${FULL_FILE}" ]] || FULL_FILE="${BATTERY_DIR}/energy_full"
  [[ -f "${DESIGN_FILE}" ]] || DESIGN_FILE="${BATTERY_DIR}/energy_full_design"

  if [[ -f "${FULL_FILE}" && -f "${DESIGN_FILE}" ]]; then
    BAT_FULL="$(cat "${FULL_FILE}")"
    BAT_DESIGN="$(cat "${DESIGN_FILE}")"
    if [[ "${BAT_FULL}" =~ ^[0-9]+$ && "${BAT_DESIGN}" =~ ^[0-9]+$ && "${BAT_DESIGN}" -gt 0 ]]; then
      HEALTH=$((BAT_FULL * 100 / BAT_DESIGN))
      if ((HEALTH >= 80)); then
        pass "Battery health: ${HEALTH}%"
      elif ((HEALTH >= 60)); then
        warn "Battery health degraded: ${HEALTH}%"
      else
        fail "Battery health critical: ${HEALTH}%"
      fi
    fi
  else
    warn "Battery health files unavailable"
  fi
else
  info "No battery detected"
fi

# ─── 14. Disk health ─────────────────────────────────────────────────────────
log::section "14. Disk Health (SMART)"
if command -v smartctl &>/dev/null; then
  DISK="$(lsblk -dn -o NAME,TYPE 2>/dev/null | awk '$2=="disk"{print "/dev/"$1}' | head -1 || true)"
  if [[ -n "${DISK}" ]]; then
    STATUS="$(sudo smartctl -H "${DISK}" 2>/dev/null | grep -oP '(?<=result: )\S+' || echo "UNKNOWN")"
    if [[ "${STATUS}" == "PASSED" ]]; then
      pass "SMART: ${DISK} — PASSED"
    else
      warn "SMART: ${DISK} — ${STATUS} (run: sudo smartctl -a ${DISK})"
    fi
  else
    warn "No disk found for SMART check"
  fi
else
  warn "smartctl not installed"
fi

# ─── 15. Firmware ────────────────────────────────────────────────────────────
log::section "15. Firmware"
if command -v fwupdmgr &>/dev/null; then
  UPDATE_COUNT="$(fwupdmgr get-updates 2>/dev/null | grep -c "Update" || true)"
  if [[ "${UPDATE_COUNT:-0}" -eq 0 ]]; then
    pass "Firmware: up to date"
  else
    warn "Firmware: ${UPDATE_COUNT} update(s) available — run: fwupdmgr update"
  fi
else
  warn "fwupdmgr not installed — firmware updates unmanaged"
fi

# ─── 16. Enhanced shell tools ────────────────────────────────────────────────
log::section "16. Enhanced Shell Tools"
for tool in eza bat fd rg zoxide atuin glow; do
  command -v "${tool}" &>/dev/null && pass "Shell tool: ${tool}" || warn "Missing: ${tool}"
done

# ─── 17. Portal sanity ───────────────────────────────────────────────────────
log::section "17. Portal Sanity"
if systemctl --user is-active xdg-desktop-portal-hyprland.service &>/dev/null; then
  pass "xdg-desktop-portal-hyprland active"
else
  fail "xdg-desktop-portal-hyprland not running — screen share / file pickers may break"
fi

if [[ "${FULL}" == "true" ]]; then
  log::section "18. Lumina App Entry Points"
  for app in \
    lumina-shell \
    lumina-welcome \
    lumina-keybind-overlay \
    lumina-control-center \
    lumina-doctor-dashboard \
    lumina-snapshot-manager \
    lumina-activity-history \
    lumina-theme-studio \
    lumina-hub \
    lumina-mission-control \
    lumina-ai; do
    if command -v "${app}" >/dev/null 2>&1; then
      pass "Lumina app command: ${app}"
    else
      fail "Lumina app command missing: ${app}"
    fi
  done

  log::section "19. Runtime Validator"
  if [[ -x "${DOTFILES_DIR}/scripts/validate.sh" ]]; then
    pass "Runtime validator script exists"
  else
    fail "Runtime validator script missing or not executable"
  fi
fi

if [[ "${PORCELAIN}" == "true" ]]; then
  printf 'INFO|Summary: errors=%s, warnings=%s, log=%s\n' "${ERRORS}" "${WARNINGS}" "${LOG_FILE}"
  exit "${ERRORS}"
fi

# ─── Summary ──────────────────────────────────────────────────────────────────
echo ""
log::sep
echo ""
if [[ ${ERRORS} -eq 0 ]] && [[ ${WARNINGS} -eq 0 ]]; then
  echo -e "  \033[1;32m✓  All checks passed — your system is healthy!\033[0m"
elif [[ ${ERRORS} -eq 0 ]]; then
  echo -e "  \033[1;33m⚠  ${WARNINGS} warning(s) — system functional but not fully optimized\033[0m"
else
  echo -e "  \033[1;31m✗  ${ERRORS} error(s), ${WARNINGS} warning(s) — action required\033[0m"
fi
echo ""
echo -e "  \033[2m  Full log: ${LOG_FILE}\033[0m"
echo ""

exit "${ERRORS}"
