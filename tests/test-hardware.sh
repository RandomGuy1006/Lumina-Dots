#!/usr/bin/env bash
# tests/test-hardware.sh — Verify LOQ 15IRX9 hardware configuration
set -euo pipefail
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${DOTFILES_DIR}/lib/log.sh"
log::header "Test: Hardware Configuration"
ERRORS=0
WARNINGS=0
check() { log::success "$1"; }
warn() {
  log::warn "$1"
  ((WARNINGS++)) || true
}
fail() {
  log::error "$1"
  ((ERRORS++)) || true
}

if grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null || systemd-detect-virt --wsl >/dev/null 2>&1; then
  log::warn "WSL detected; checking hardware config sources only"
  for file in \
    "${DOTFILES_DIR}/hosts/loq-15irx9/profile.sh" \
    "${DOTFILES_DIR}/hosts/loq-15irx9/kernel-params.conf" \
    "${DOTFILES_DIR}/hosts/loq-15irx9/modprobe-i915.conf" \
    "${DOTFILES_DIR}/hosts/loq-15irx9/sleep.conf" \
    "${DOTFILES_DIR}/docs/hardware-lenovo-loq-15irx9.md"; do
    if [[ -f "${file}" ]]; then
      check "Exists: ${file##"${DOTFILES_DIR}/"}"
    else
      fail "Missing: ${file##"${DOTFILES_DIR}/"}"
    fi
  done
  exit "${ERRORS}"
fi

# NVIDIA
lsmod | grep -q nvidia_drm && check "NVIDIA DRM loaded" || warn "NVIDIA DRM not loaded"
cat /sys/module/nvidia_drm/parameters/modeset 2>/dev/null | grep -q "Y" &&
  check "NVIDIA KMS enabled" || warn "NVIDIA KMS not enabled"
[[ -f /etc/modprobe.d/nvidia.conf ]] && check "/etc/modprobe.d/nvidia.conf exists" ||
  warn "nvidia.conf not found"

# Backlight
command -v brightnessctl &>/dev/null && check "brightnessctl installed" || fail "brightnessctl missing"
[[ -d /sys/class/backlight ]] && check "Backlight sysfs present" || warn "No backlight interface"

# AutoCPUFreq
systemctl is-active auto-cpufreq &>/dev/null && check "auto-cpufreq active" || warn "auto-cpufreq not active"

# Snapper
[[ -f /etc/snapper/configs/root ]] && check "Snapper configured" || warn "Snapper not configured"

echo ""
[[ $ERRORS -eq 0 ]] &&
  echo -e "  \033[1;32m✓ Hardware check passed (${WARNINGS} warning(s))\033[0m" ||
  echo -e "  \033[1;31m✗ ${ERRORS} error(s), ${WARNINGS} warning(s)\033[0m"
exit "${ERRORS}"
