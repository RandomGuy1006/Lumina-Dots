#!/usr/bin/env bash
# Legacy compatibility wrapper. The maintenance backup script is canonical.
set -euo pipefail

ROOT="${LOQDOTS_ROOT:-${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}}"
exec bash "${ROOT}/scripts/maintenance/backup.sh" "$@"
