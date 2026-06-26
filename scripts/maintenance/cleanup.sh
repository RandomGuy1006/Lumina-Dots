#!/usr/bin/env bash
# scripts/maintenance/cleanup.sh — Clean old snapshots and logs
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "${DOTFILES_DIR}/lib/log.sh"

log::section "Cleaning old logs"
find "${DOTFILES_DIR}/logs" -name "*.log" -mtime +30 -delete
log::success "Logs older than 30 days removed"

log::section "Running snapper cleanup"
if command -v snapper &>/dev/null; then
  sudo snapper -c root cleanup timeline && log::success "Snapper timeline cleanup done"
else
  log::warn "snapper not installed"
fi

log::section "Clearing pacman cache"
if command -v paccache &>/dev/null; then
  sudo paccache -rk2 && log::success "Pacman cache: kept 2 versions per package"
else
  log::warn "paccache not found (install pacman-contrib)"
fi

log::success "Cleanup complete"
