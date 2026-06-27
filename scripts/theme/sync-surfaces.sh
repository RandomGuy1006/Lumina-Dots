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

if pgrep -x hyprpanel >/dev/null 2>&1; then
  pkill -SIGUSR1 -x hyprpanel 2>/dev/null || true
  log::success "Hyprpanel reload signal sent"
fi

if command -v hyprctl >/dev/null 2>&1 && hyprctl monitors >/dev/null 2>&1; then
  hyprctl keyword source ~/.config/hypr/colors.conf
  hyprctl keyword source ~/.config/hypr/tokens.conf
  hyprctl keyword source ~/.config/hypr/conf.d/tokens-colors.conf
  log::success "Hyprland colors sourced"
fi

if command -v gsettings >/dev/null 2>&1; then
  gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3-dark 2>/dev/null || true
fi

touch "${XDG_CACHE_HOME:-${HOME}/.cache}/lumina-theme-synced"
log::success "Theme surfaces synchronized"
