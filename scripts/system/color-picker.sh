#!/usr/bin/env bash
set -euo pipefail

notify() {
  local body="$1"
  command -v lumina-shell >/dev/null 2>&1 && lumina-shell popup color --body "${body}" >/dev/null 2>&1 || true
  command -v lumina-toast >/dev/null 2>&1 && lumina-toast "Color picked" "${body}" success 2>/dev/null || true
}

if ! command -v hyprpicker >/dev/null 2>&1; then
  notify "Unavailable - hyprpicker missing"
  exit 1
fi

color="$(hyprpicker 2>/dev/null || true)"
if [[ -z "${color}" ]]; then
  notify "Cancelled"
  exit 1
fi

if command -v wl-copy >/dev/null 2>&1; then
  printf '%s' "${color}" | wl-copy
fi

notify "${color}"
printf '%s\n' "${color}"
