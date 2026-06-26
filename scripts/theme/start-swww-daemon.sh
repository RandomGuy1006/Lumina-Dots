#!/usr/bin/env bash
# scripts/theme/start-swww-daemon.sh — Start swww daemon with host overrides
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${SCRIPT_PATH}")/../.." && pwd)}"
source "${DOTFILES_DIR}/lib/host.sh"

host::load "${HOST_PROFILE:-$(host::detect)}" >/dev/null 2>&1 || true

if ! command -v swww-daemon >/dev/null 2>&1; then
  echo "swww-daemon is not installed" >&2
  exit 1
fi

pixel_format="${SWWW_PIXEL_FORMAT:-}"
if [[ -n "${pixel_format}" ]]; then
  exec swww-daemon --format "${pixel_format}"
fi

exec swww-daemon
