#!/usr/bin/env bash
set -euo pipefail

ROOT="${LOQDOTS_ROOT:-${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}}"
exec bash "${ROOT}/scripts/theme/switch-wallpaper.sh" "$@"
