#!/usr/bin/env bash
set -euo pipefail

hyprctl dispatch togglespecialworkspace scratch >/dev/null 2>&1 || true

if pgrep -f 'class=lumina-scratch' >/dev/null 2>&1; then
  exit 0
fi

if command -v uwsm >/dev/null 2>&1; then
  uwsm app -- ghostty --class=lumina-scratch >/dev/null 2>&1 &
  disown
else
  ghostty --class=lumina-scratch >/dev/null 2>&1 &
  disown
fi
