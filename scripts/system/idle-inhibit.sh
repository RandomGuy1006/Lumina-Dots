#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/lumina-idle-inhibit.pid"

notify() {
  command -v lumina-toast >/dev/null 2>&1 && lumina-toast "Idle Inhibitor" "$1" info 2>/dev/null || true
  command -v lumina-shell >/dev/null 2>&1 && lumina-shell popup mode --body "$1" >/dev/null 2>&1 || true
}

if [[ -s "${STATE_FILE}" ]]; then
  pid="$(cat "${STATE_FILE}" 2>/dev/null || true)"
  [[ "${pid}" =~ ^[0-9]+$ ]] && kill "${pid}" 2>/dev/null || true
  rm -f "${STATE_FILE}"
  notify "Off"
  exit 0
fi

if command -v systemd-inhibit >/dev/null 2>&1; then
  systemd-inhibit --what=idle --who="Lumina Idle Inhibitor" --why="Manual Lumina idle inhibit" sleep infinity &
  echo "$!" >"${STATE_FILE}"
  notify "On"
else
  notify "Unavailable - systemd-inhibit missing"
  exit 1
fi
