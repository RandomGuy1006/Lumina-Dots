#!/usr/bin/env bash
# scripts/install/uninstall.sh — Gracefully remove lumina-dots
# Removes symlinks and restores basic backups if available.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${DOTFILES_DIR}/lib/log.sh"
source "${DOTFILES_DIR}/lib/link.sh"

log::header "lumina-dots Uninstaller"
log::warn "This will remove all symlinks created by lumina-dots."
read -rp "Are you sure you want to proceed? [y/N] " confirm
if [[ "${confirm,,}" != "y" ]]; then
  log::info "Uninstallation aborted."
  exit 0
fi

log::section "Removing dotfiles symlinks"
link::remove_all

log::section "Disabling user services"
systemctl --user disable --now \
  loq-hyprpanel.service \
  loq-swww.service \
  loq-cliphist-text.service \
  loq-cliphist-image.service \
  loq-hypridle.service \
  loq-hyprswitch.service \
  loq-hyprlock-boot.service \
  lumina-shell.service \
  lumina-welcome.service \
  2>/dev/null || true

log::success "Uninstallation complete. You can now safely delete the dotfiles directory."
