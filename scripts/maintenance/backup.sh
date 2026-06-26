#!/usr/bin/env bash
# scripts/maintenance/backup.sh — Filesystem-aware recovery snapshot creation
# Usage: dotfiles backup [description]
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "${DOTFILES_DIR}/lib/log.sh"
source "${DOTFILES_DIR}/lib/safety.sh"

DESCRIPTION="${1:-manual-$(date +%Y%m%d)}"
STATE_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}/loqdots"
BACKUP_DIR="${STATE_DIR}/backups"
STAMP="$(date +%Y-%m-%d_%H-%M-%S)"
BACKUP_ROOT="${BACKUP_DIR}/${STAMP}"

ROOT_FSTYPE="$(safety::root_fstype)"
BACKEND=""

case "${ROOT_FSTYPE}" in
  btrfs)
    safety::snapper_ready || log::fatal "Btrfs root requires Snapper and /etc/snapper/configs/root"
    log::section "Creating Btrfs snapshot"
    sudo snapper -c root create --description "${DESCRIPTION}" || log::fatal "Snapper snapshot creation failed"
    BACKEND="snapper"
    sudo snapper -c root list | tail -5
    ;;
  ext4)
    safety::timeshift_ready || log::fatal "ext4 root requires Timeshift"
    log::section "Creating Timeshift snapshot"
    sudo timeshift --create --comments "${DESCRIPTION}" --tags D --scripted ||
      log::fatal "Timeshift snapshot creation failed"
    BACKEND="timeshift"
    sudo timeshift --list | tail -10
    ;;
  *)
    log::fatal "Unsupported root filesystem for backup: ${ROOT_FSTYPE:-unknown}"
    ;;
esac

mkdir -p "${BACKUP_ROOT}"
if command -v pacman &>/dev/null; then
  pacman -Qqe | sort >"${BACKUP_ROOT}/packages.txt"
fi
if git -C "${DOTFILES_DIR}" rev-parse HEAD &>/dev/null; then
  git -C "${DOTFILES_DIR}" rev-parse HEAD >"${BACKUP_ROOT}/lumina-dots-commit.txt"
fi
if systemctl --user show-environment >/dev/null 2>&1; then
  systemctl --user list-unit-files --state=enabled --no-legend >"${BACKUP_ROOT}/user-services-enabled.txt" || true
fi
if [[ -f "${STATE_DIR}/current-wallpaper" ]]; then
  cp "${STATE_DIR}/current-wallpaper" "${BACKUP_ROOT}/current-wallpaper.txt"
elif [[ -f "${HOME}/Pictures/Wallpapers/.current" ]]; then
  cp "${HOME}/Pictures/Wallpapers/.current" "${BACKUP_ROOT}/current-wallpaper.txt"
fi
printf '%s\n' "${HOST_PROFILE:-${HOST:-unknown}}" >"${BACKUP_ROOT}/host-profile.txt"
cat >"${BACKUP_ROOT}/manifest.json" <<EOF
{
  "schema_version": 1,
  "created_at": "$(date --iso-8601=seconds)",
  "description": "${DESCRIPTION//\"/\\\"}",
  "filesystem": "${ROOT_FSTYPE}",
  "backend": "${BACKEND}",
  "host": "${HOSTNAME:-unknown}"
}
EOF
log::success "Snapshot and recovery manifest created: ${BACKUP_ROOT}"
