#!/usr/bin/env bash
# scripts/recovery/restore-config.sh — Restore a single config from git
# Usage: restore-config.sh <config-path-relative-to-dotfiles>
# Example: restore-config.sh modules/hypr/binds.conf
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "${DOTFILES_DIR}/lib/log.sh"

TARGET="${1:-}"
if [[ -z "${TARGET}" ]]; then
  log::fatal "Usage: restore-config.sh <path-relative-to-dotfiles>"
fi

if [[ "${TARGET}" == /* || "${TARGET}" == *".."* ]]; then
  log::fatal "Config path must stay within the dotfiles repository: ${TARGET}"
fi

tmp_file="$(mktemp)"
chmod 600 "${tmp_file}"
trap 'rm -f "${tmp_file}"' EXIT

log::section "Restoring ${TARGET} from git"

if [[ ! -d "${DOTFILES_DIR}/.git" ]]; then
  log::fatal "Dotfiles directory is not a git repo"
fi

cd "${DOTFILES_DIR}"
git cat-file -e "HEAD:${TARGET}" 2>/dev/null || log::fatal "Path is not tracked at HEAD: ${TARGET}"
git show HEAD:"${TARGET}" >"${tmp_file}" &&
  log::success "File retrieved from git HEAD"

DEST="${DOTFILES_DIR}/${TARGET}"
if [[ -f "${DEST}" ]]; then
  cp "${DEST}" "${DEST}.bak-$(date +%Y%m%d%H%M%S)"
  log::info "Backed up existing: ${TARGET}"
fi

mkdir -p "$(dirname "${DEST}")"
install -m 0644 "${tmp_file}" "${DEST}.restore-new"
mv -f "${DEST}.restore-new" "${DEST}"
log::success "Restored: ${TARGET}"
