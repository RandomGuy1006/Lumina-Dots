#!/usr/bin/env bash
# scripts/apply-theme.sh — LEGACY WRAPPER
# Redirects to the canonical lumina-theme API.
# Kept for backward compatibility with older scripts that reference this path.
set -euo pipefail

ROOT="${LOQDOTS_ROOT:-${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}}"
DOTFILES_DIR="${DOTFILES_DIR:-$ROOT}"
LOQDOTS_ROOT="${LOQDOTS_ROOT:-$DOTFILES_DIR}"
export DOTFILES_DIR LOQDOTS_ROOT
source "$ROOT/lib/common.sh"

load_host_profile

# Determine wallpaper from argument or state file
wallpaper="${1:-}"
if [[ -z "${wallpaper}" ]]; then
  state_file="$(current_wallpaper_file)"
  if [[ -s "$state_file" ]]; then
    wallpaper="$(cat "$state_file")"
  else
    wallpaper="$(find "$WALLPAPER_DIR" -type f \
      \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) |
      sort | head -n1 || true)"
  fi
fi

if [[ -z "${wallpaper:-}" || ! -f "$wallpaper" ]]; then
  warn "No wallpaper available yet. Generated themes were not refreshed."
  exit 0
fi

PYTHONPATH="$ROOT/apps/lib${PYTHONPATH:+:${PYTHONPATH}}"
export PYTHONPATH
if command -v lumina-theme >/dev/null 2>&1; then
  exec lumina-theme apply --wallpaper="$wallpaper"
fi
exec "$ROOT/local-bin/.local/bin/lumina-theme" apply --wallpaper="$wallpaper"
