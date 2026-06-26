#!/usr/bin/env bash
# Toggle gaming mode: max performance, minimal compositor effects.
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "${DOTFILES_DIR}/lib/log.sh"

STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/lumina-gaming-mode"
CPU_GOVERNOR="/sys/devices/system/cpu/cpu*/cpufreq/scaling_governor"

set_governor() {
  local governor="$1"
  local -a governor_files=()
  mapfile -t governor_files < <(compgen -G "${CPU_GOVERNOR}" || true)
  if [[ "${#governor_files[@]}" -gt 0 ]]; then
    printf '%s\n' "${governor}" | sudo tee "${governor_files[@]}" >/dev/null
  fi
}

if [[ -f "${STATE_FILE}" ]]; then
  log::step "Disabling gaming mode..."
  lumina-glass reload >/dev/null 2>&1 || true
  hyprctl keyword animations:enabled true >/dev/null 2>&1 || true
  hyprctl keyword decoration:shadow:enabled true >/dev/null 2>&1 || true
  set_governor "powersave"
  if command -v lumina-shell >/dev/null 2>&1; then
    lumina-shell mode auto >/dev/null 2>&1 || true
    lumina-shell popup mode --body "Auto Mode" >/dev/null 2>&1 || true
  else
    lumina-toast "Gaming Mode" "Disabled - power saving restored" info 2>/dev/null || true
  fi
  rm -f "${STATE_FILE}"
  log::success "Gaming mode off"
else
  log::step "Enabling gaming mode..."
  lumina-glass set minimal --battery >/dev/null 2>&1 || true
  hyprctl keyword animations:enabled false >/dev/null 2>&1 || true
  hyprctl keyword decoration:shadow:enabled false >/dev/null 2>&1 || true
  set_governor "performance"
  if command -v lumina-shell >/dev/null 2>&1; then
    lumina-shell mode performance >/dev/null 2>&1 || true
    lumina-shell popup mode --body "Performance Mode" >/dev/null 2>&1 || true
  else
    lumina-toast "Gaming Mode" "Enabled - max performance, compositor reduced" info 2>/dev/null || true
  fi
  touch "${STATE_FILE}"
  log::success "Gaming mode on"
fi
