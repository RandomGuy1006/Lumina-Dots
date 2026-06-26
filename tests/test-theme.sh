#!/usr/bin/env bash
# tests/test-theme.sh — Verify Matugen template rendering
set -euo pipefail
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${DOTFILES_DIR}/lib/log.sh"
log::header "Test: Matugen Theme Pipeline"
ERRORS=0

if grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null || systemd-detect-virt --wsl >/dev/null 2>&1; then
  log::warn "WSL detected; checking theme sources only"
  for file in \
    "${DOTFILES_DIR}/matugen/.config/matugen/config.toml" \
    "${DOTFILES_DIR}/matugen/.config/matugen/templates/visual-tokens.json" \
    "${DOTFILES_DIR}/scripts/theme/render-visual-tokens.sh" \
    "${DOTFILES_DIR}/scripts/theme/sync-surfaces.sh"; do
    if [[ -f "${file}" ]]; then
      log::success "Exists: ${file##"${DOTFILES_DIR}/"}"
    else
      log::error "Missing: ${file##"${DOTFILES_DIR}/"}"
      ((ERRORS++)) || true
    fi
  done
  exit "${ERRORS}"
fi

check_file() {
  if [[ -f "$1" ]]; then log::success "Exists: ${1##"$HOME/"}"; else
    log::error "Missing: $1"
    ((ERRORS++)) || true
  fi
}
command -v matugen &>/dev/null && log::success "matugen installed" || {
  log::error "matugen not installed"
  ((ERRORS++)) || true
}
check_file "${HOME}/.config/hypr/colors.conf"
check_file "${HOME}/.config/hypr/tokens.conf"
check_file "${HOME}/.config/hypr/hyprlock-colors.conf"
check_file "${HOME}/.config/ghostty/themes/LoqDynamic"
check_file "${HOME}/.config/ghostty/lumina-tokens.conf"
check_file "${HOME}/.config/walker/themes/generated.css"
check_file "${HOME}/.cache/matugen/wallpaper-cache"
[[ $ERRORS -eq 0 ]] && log::success "Theme pipeline OK" || log::error "${ERRORS} issue(s)"
exit "${ERRORS}"
