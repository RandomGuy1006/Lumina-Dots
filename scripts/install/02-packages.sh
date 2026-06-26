#!/usr/bin/env bash
# scripts/install/02-packages.sh — Package installation
# Installs all packages from manifests in order
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "${DOTFILES_DIR}/lib/log.sh"
source "${DOTFILES_DIR}/lib/pkg.sh"
source "${DOTFILES_DIR}/lib/safety.sh"

log::header "Step 2: Package Installation"

PKG_DIR="${DOTFILES_DIR}/packages"

safety::require_snapshot "lumina pre-package-install $(date +%Y-%m-%d)"

# ─── Pacman packages ──────────────────────────────────────────────────────────
log::section "Installing base packages"
pkg::from_file "${PKG_DIR}/pacman-base.txt"

log::section "Installing Hyprland ecosystem"
pkg::from_file "${PKG_DIR}/pacman-desktop.txt"

log::section "Installing applications"
pkg::from_file "${PKG_DIR}/pacman-media.txt"
bash "${DOTFILES_DIR}/scripts/system/install-swww-compat.sh"

log::section "Installing developer tools"
pkg::from_file "${PKG_DIR}/pacman-dev.txt"

# ─── Hardware-specific packages ───────────────────────────────────────────────
if [[ "${HOST_PROFILE:-}" == "loq-15irx9" ]]; then
  log::section "Installing LOQ 15IRX9 hardware packages"
  pkg::from_file "${PKG_DIR}/pacman-loq.txt"
fi

# ─── AUR packages ─────────────────────────────────────────────────────────────
log::section "Installing AUR packages"
pkg::from_file "${PKG_DIR}/aur.txt" "true"

# ─── Conflict check ───────────────────────────────────────────────────────────
log::section "Checking for daemon conflicts"
pkg::conflict_check "dunst" "mako" "notification-daemon" "xfce4-notifyd" || true

# ─── Zsh as default shell ─────────────────────────────────────────────────────
log::section "Setting Zsh as default shell"
ZSH_PATH="$(command -v zsh || true)"
if [[ -z "${ZSH_PATH}" ]]; then
  log::warn "zsh command not found; skipping default shell change"
elif [[ "${SHELL}" != "${ZSH_PATH}" ]]; then
  if ! grep -q "${ZSH_PATH}" /etc/shells; then
    echo "${ZSH_PATH}" | sudo tee -a /etc/shells >/dev/null
  fi
  sudo chsh -s "${ZSH_PATH}" "${USER}"
  log::success "Default shell set to Zsh"
else
  log::dim "Zsh already default shell"
fi

# ─── Enable NetworkManager ─────────────────────────────────────────────────────
log::section "Enabling NetworkManager"
sudo systemctl enable --now NetworkManager &&
  log::success "NetworkManager enabled" ||
  log::warn "NetworkManager enable failed"

# ─── Enable Bluetooth ─────────────────────────────────────────────────────────
log::section "Enabling Bluetooth"
sudo systemctl enable --now bluetooth &&
  log::success "Bluetooth enabled" ||
  log::warn "Bluetooth enable failed"

log::success "Package installation complete"
