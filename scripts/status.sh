#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "${DOTFILES_DIR}/lib/log.sh"
source "${DOTFILES_DIR}/lib/host.sh"

host_profile="${HOST_PROFILE:-$(host::detect)}"
host_profile="$(host::canonical "${host_profile}")"
host::load "${host_profile}" >/dev/null 2>&1 || true
wallpaper_file="${HOME}/Pictures/Wallpapers/.current"
state_file="${XDG_RUNTIME_DIR:-/tmp}/lumina-gaming-mode"

log::header "Lumina Status"
log::info "Host: ${host_profile}"
log::info "NVIDIA mode: ${NVIDIA_MODE:-integrated}"
if command -v matugen >/dev/null 2>&1; then
  log::info "Matugen: $(matugen --version 2>/dev/null | head -1)"
else
  log::warn "Matugen: not installed"
fi
if command -v swww >/dev/null 2>&1; then
  log::info "Wallpaper API: swww"
else
  log::warn "Wallpaper API: swww missing"
fi
if [[ -s "${wallpaper_file}" ]]; then
  log::info "Wallpaper: $(cat "${wallpaper_file}")"
else
  log::warn "Wallpaper: none recorded"
fi
if [[ -f "${state_file}" ]]; then
  log::info "Gaming mode: enabled"
else
  log::info "Gaming mode: disabled"
fi

for svc in loq-session.target loq-hyprpanel.service lumina-shell.service loq-swww.service loq-hypridle.service; do
  if systemctl --user is-active "${svc}" >/dev/null 2>&1; then
    log::success "Active: ${svc}"
  else
    log::warn "Inactive: ${svc}"
  fi
done
