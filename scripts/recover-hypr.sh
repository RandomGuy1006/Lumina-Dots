#!/usr/bin/env bash
set -euo pipefail

ROOT="${LOQDOTS_ROOT:-${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}}"
DOTFILES_DIR="${DOTFILES_DIR:-$ROOT}"
LOQDOTS_ROOT="${LOQDOTS_ROOT:-$DOTFILES_DIR}"
export DOTFILES_DIR LOQDOTS_ROOT
source "$ROOT/lib/common.sh"

fallback="$ROOT/fallback/.config/hypr/hyprland-fallback.conf"

[[ -f "$fallback" ]] || {
  fail "Fallback Hyprland config not found: $fallback"
  exit 1
}

if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
  fail "Refusing to launch fallback Hyprland from inside an active Wayland session."
  note "Switch to a TTY first, then run this recovery command."
  exit 1
fi

note "Launching Hyprland directly with the fallback config outside the normal UWSM session stack"
exec Hyprland --config "$fallback"
