#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/lumina-presentation-mode"
LOG_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}/lumina"
mkdir -p "${LOG_DIR}"

notify() {
  command -v lumina-toast >/dev/null 2>&1 && lumina-toast "Presentation Mode" "$1" info 2>/dev/null || true
  command -v lumina-shell >/dev/null 2>&1 && lumina-shell popup mode --body "$1" >/dev/null 2>&1 || true
}

if [[ -f "${STATE_FILE}" ]]; then
  inhibitor_pid="$(cat "${STATE_FILE}" 2>/dev/null || true)"
  [[ "${inhibitor_pid}" =~ ^[0-9]+$ ]] && kill "${inhibitor_pid}" 2>/dev/null || true
  rm -f "${STATE_FILE}"
  lumina-glass reload >/dev/null 2>&1 || true
  hyprctl keyword general:gaps_in 5 >/dev/null 2>&1 || true
  hyprctl keyword general:gaps_out 10 >/dev/null 2>&1 || true
  printf '%s off\n' "$(date --iso-8601=seconds)" >>"${LOG_DIR}/presentation-mode.log"
  notify "Off"
  exit 0
fi

if command -v systemd-inhibit >/dev/null 2>&1; then
  systemd-inhibit --what=idle --who="Lumina Presentation Mode" --why="Presentation active" sleep infinity &
  echo "$!" >"${STATE_FILE}"
else
  echo "" >"${STATE_FILE}"
fi
lumina-glass set minimal --battery >/dev/null 2>&1 || true
hyprctl keyword general:gaps_in 2 >/dev/null 2>&1 || true
hyprctl keyword general:gaps_out 4 >/dev/null 2>&1 || true
printf '%s on\n' "$(date --iso-8601=seconds)" >>"${LOG_DIR}/presentation-mode.log"
notify "On - idle lock reduced"
