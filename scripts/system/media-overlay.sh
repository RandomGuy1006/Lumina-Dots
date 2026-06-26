#!/usr/bin/env bash
set -euo pipefail

status="unavailable"
artist=""
title=""
if command -v playerctl >/dev/null 2>&1; then
  status="$(playerctl status 2>/dev/null || echo unavailable)"
  artist="$(playerctl metadata artist 2>/dev/null || true)"
  title="$(playerctl metadata title 2>/dev/null || true)"
fi
body="${status}"
if [[ -n "${artist}${title}" ]]; then
  body="${status}: ${artist} - ${title}"
fi
if command -v lumina-shell >/dev/null 2>&1; then
  lumina-shell popup media --body "${body}" >/dev/null 2>&1 || true
elif command -v lumina-toast >/dev/null 2>&1; then
  lumina-toast "Media" "${body}" info 2>/dev/null || true
fi
printf '%s\n' "${body}"
