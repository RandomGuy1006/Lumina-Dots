#!/usr/bin/env bash
# Compatibility wrapper for the Lumina Theme Engine.
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PYTHONPATH="${DOTFILES_DIR}/apps/lib${PYTHONPATH:+:${PYTHONPATH}}"
export PYTHONPATH

WALLPAPER="${1:-}"
if [[ -z "${WALLPAPER}" ]]; then
  printf 'Usage: apply-theme.sh <path-to-wallpaper>\n' >&2
  exit 1
fi

if [[ ! -f "${WALLPAPER}" ]]; then
  printf 'Wallpaper file not found: %s\n' "${WALLPAPER}" >&2
  exit 1
fi

mkdir -p "${HOME}/.cache/matugen"
cp "$(realpath "${WALLPAPER}")" "${HOME}/.cache/matugen/wallpaper-cache" 2>/dev/null || true

if command -v lumina >/dev/null 2>&1; then
  exec lumina theme apply "$(realpath "${WALLPAPER}")"
fi

if command -v lumina-theme >/dev/null 2>&1; then
  exec lumina-theme apply --wallpaper="$(realpath "${WALLPAPER}")"
fi

exec "${DOTFILES_DIR}/local-bin/.local/bin/lumina-theme" apply --wallpaper="$(realpath "${WALLPAPER}")"
