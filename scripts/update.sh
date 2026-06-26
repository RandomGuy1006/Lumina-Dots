#!/usr/bin/env bash
# Legacy compatibility wrapper. The root update.sh is the canonical update flow.
set -euo pipefail

ROOT="${LOQDOTS_ROOT:-${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}}"
exec bash "${ROOT}/update.sh" "$@"
