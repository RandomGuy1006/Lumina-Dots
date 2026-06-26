#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
DOC="${DOTFILES_DIR}/docs/keybindings.md"

if command -v lumina-keybind-overlay >/dev/null 2>&1; then
  exec uwsm app -- lumina-keybind-overlay
fi

if command -v glow >/dev/null 2>&1; then
  exec ghostty --title="Keybinds" --window-width=900 --window-height=700 -e glow "${DOC}"
elif command -v bat >/dev/null 2>&1; then
  exec ghostty --title="Keybinds" --window-width=900 --window-height=700 -e bat --style=plain --color=always "${DOC}"
else
  exec ghostty --title="Keybinds" --window-width=900 --window-height=700 -e less "${DOC}"
fi
