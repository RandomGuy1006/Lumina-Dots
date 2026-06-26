#!/usr/bin/env bash
# Synchronize active desktop surfaces after Matugen writes theme outputs.
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "${DOTFILES_DIR}/lib/log.sh"

bash "${DOTFILES_DIR}/scripts/theme/render-visual-tokens.sh"

if command -v jq >/dev/null 2>&1; then
  LOQDOTS_ROOT="${DOTFILES_DIR}" bash "${DOTFILES_DIR}/scripts/bootstrap-hyprpanel.sh" &&
    log::success "Hyprpanel runtime config rebuilt"
else
  log::warn "jq not installed; Hyprpanel runtime config was not rebuilt"
fi

if command -v hyprctl >/dev/null 2>&1 && hyprctl monitors >/dev/null 2>&1; then
  if hyprctl keyword source ~/.config/hypr/colors.conf 2>/dev/null &&
    hyprctl keyword source ~/.config/hypr/tokens.conf 2>/dev/null; then
    log::success "Hyprland colors sourced (no flicker)"
  else
    hyprctl reload && log::success "Hyprland config reloaded (fallback)"
  fi
fi

if systemctl --user is-active loq-hyprpanel.service >/dev/null 2>&1; then
  systemctl --user restart loq-hyprpanel.service &&
    log::success "Hyprpanel user service restarted with new colors"
elif pgrep -x hyprpanel >/dev/null 2>&1; then
  pkill -x hyprpanel 2>/dev/null || true
  for ((i = 0; i < 30; i++)); do
    if ! pgrep -x hyprpanel >/dev/null 2>&1; then break; fi
    sleep 0.1
  done
  hyprpanel >/dev/null 2>&1 &
  disown
  log::success "Hyprpanel restarted with new colors"
fi

if command -v gsettings >/dev/null 2>&1; then
  gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3-dark 2>/dev/null || true
fi

touch "${XDG_CACHE_HOME:-${HOME}/.cache}/lumina-theme-synced"
log::success "Theme surfaces synchronized"
