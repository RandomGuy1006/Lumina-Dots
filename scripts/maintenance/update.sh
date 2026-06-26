#!/usr/bin/env bash
# scripts/maintenance/update.sh — Full maintenance update
# Distinct from root update.sh: focuses on cleanup + health reporting
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "${DOTFILES_DIR}/lib/log.sh"

LOG_FILE="${DOTFILES_DIR}/logs/maintenance-$(date +%Y%m%d-%H%M%S).log"

log::header "lumina-dots Maintenance Update"

# 1. Remove orphaned packages
log::section "Removing orphaned packages"
ORPHANS="$(pacman -Qtdq 2>/dev/null || true)"
if [[ -n "${ORPHANS}" ]]; then
  echo "${ORPHANS}" | sudo pacman -Rns --noconfirm - &&
    log::success "Orphans removed" ||
    log::warn "Some orphans could not be removed"
else
  log::dim "No orphaned packages"
fi

# 2. Clean paru cache (keep last 2 versions)
log::section "Cleaning package cache"
if command -v paccache &>/dev/null; then
  sudo paccache -rk2 && log::success "Package cache cleaned (kept 2 versions)"
else
  log::warn "paccache not found — install pacman-contrib"
fi

# 3. Clean old snapshots
log::section "Cleaning old Btrfs snapshots"
if command -v snapper &>/dev/null; then
  sudo snapper -c root cleanup timeline &&
    log::success "Snapper timeline cleanup done"
fi

# 4. Clean old logs
log::section "Cleaning old logs"
find "${DOTFILES_DIR}/logs" -name "*.log" -mtime +14 -delete 2>/dev/null || true
log::success "Logs older than 14 days removed"

# 5. Re-verify symlinks
log::section "Verifying symlinks"
source "${DOTFILES_DIR}/lib/link.sh"
link::verify && log::success "All symlinks OK" || log::warn "Some symlink issues found"

# 6. Summary report
log::header "Maintenance Complete"
log::info "Log: ${LOG_FILE}"
log::info "Run 'dotfiles doctor' for full health check"
