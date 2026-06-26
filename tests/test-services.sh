#!/usr/bin/env bash
# tests/test-services.sh — Verify systemd user services
set -euo pipefail
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${DOTFILES_DIR}/lib/log.sh"
log::header "Test: Systemd Services"
ERRORS=0

if grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null || systemd-detect-virt --wsl >/dev/null 2>&1; then
  log::warn "WSL detected; skipping live user service activation checks"
  exit 0
fi

if [[ -z "${XDG_RUNTIME_DIR:-}" || ! -S "${XDG_RUNTIME_DIR}/bus" ]]; then
  log::warn "No user systemd bus detected; skipping runtime service checks"
  exit 0
fi

check_service() {
  if systemctl --user is-active "$1" &>/dev/null; then
    log::success "Active: $1"
  else
    log::error "Not active: $1"
    ((ERRORS++)) || true
  fi
}
check_service "pipewire.service"
check_service "wireplumber.service"
check_service "lumina-shell.service"
[[ $ERRORS -eq 0 ]] && log::success "All services OK" || log::error "${ERRORS} service(s) not active"
exit "${ERRORS}"
