#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${SCRIPT_PATH}")/../.." && pwd)}"
source "${DOTFILES_DIR}/lib/log.sh"

clipboard_path="$(wl-paste 2>/dev/null | tr -d '\r' | head -n1 || true)"

if [[ -z "${clipboard_path}" ]]; then
  log::fatal "Clipboard does not contain a wallpaper path"
fi

clipboard_path="${clipboard_path/#\~/${HOME}}"

if [[ ! -f "${clipboard_path}" ]]; then
  log::fatal "Clipboard path is not a file: ${clipboard_path}"
fi

exec bash "${DOTFILES_DIR}/scripts/theme/switch-wallpaper.sh" "${clipboard_path}"
