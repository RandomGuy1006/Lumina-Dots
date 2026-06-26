#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "${DOTFILES_DIR}/lib/log.sh"

seed_file() {
  local src="$1"
  local dest="$2"
  if [[ -L "${dest}" ]]; then
    rm -f "${dest}"
  fi
  if [[ ! -s "${dest}" ]]; then
    install -Dm0644 "${src}" "${dest}"
    log::success "Seeded: ${dest##"${HOME}/"}"
  fi
}

seed_file "${DOTFILES_DIR}/themes/defaults/hypr/colors.conf" "${HOME}/.config/hypr/colors.conf"
seed_file "${DOTFILES_DIR}/themes/defaults/hypr/tokens.conf" "${HOME}/.config/hypr/tokens.conf"
seed_file "${DOTFILES_DIR}/themes/defaults/hypr/hyprlock-colors.conf" "${HOME}/.config/hypr/hyprlock-colors.conf"
seed_file "${DOTFILES_DIR}/themes/defaults/ghostty/LoqDynamic" "${HOME}/.config/ghostty/themes/LoqDynamic"
seed_file "${DOTFILES_DIR}/themes/defaults/ghostty/lumina-tokens.conf" "${HOME}/.config/ghostty/lumina-tokens.conf"
seed_file "${DOTFILES_DIR}/themes/defaults/btop/loq.theme" "${HOME}/.config/btop/themes/loq.theme"
seed_file "${DOTFILES_DIR}/themes/defaults/walker/generated.css" "${HOME}/.config/walker/themes/generated.css"
seed_file "${DOTFILES_DIR}/themes/defaults/hyprpanel/theme.generated.json" "${HOME}/.config/hyprpanel/theme.generated.json"
seed_file "${DOTFILES_DIR}/themes/defaults/wlogout/colors.css" "${HOME}/.config/wlogout/colors.css"
seed_file "${DOTFILES_DIR}/shell/.config/starship.toml" "${HOME}/.config/starship.toml"
seed_file "${DOTFILES_DIR}/modules/yazi/theme.toml" "${HOME}/.config/yazi/theme.toml"

if [[ -f "${DOTFILES_DIR}/themes/defaults/wallpaper.jpg" ]]; then
  mkdir -p "${HOME}/Pictures/Wallpapers" "${HOME}/.cache/matugen"
  cp "${DOTFILES_DIR}/themes/defaults/wallpaper.jpg" "${HOME}/Pictures/Wallpapers/lumina-default.jpg"
  cp "${DOTFILES_DIR}/themes/defaults/wallpaper.jpg" "${HOME}/.cache/matugen/wallpaper-cache"
fi
