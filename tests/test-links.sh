#!/usr/bin/env bash
# tests/test-links.sh — Verify all config symlinks
set -euo pipefail
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${DOTFILES_DIR}/lib/log.sh"
source "${DOTFILES_DIR}/lib/link.sh"
log::header "Test: Symlink Verification"

if grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null || systemd-detect-virt --wsl >/dev/null 2>&1; then
  log::warn "WSL detected; live home symlink verification is skipped"
  log::info "Static symlink coverage runs through tests/test-regressions.sh"
  exit 0
fi

link::verify
RET=$?
if [[ $RET -eq 0 ]]; then log::success "All symlinks OK"; else log::error "${RET} symlink issues"; fi
exit "${RET}"
