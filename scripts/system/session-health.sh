#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}/lumina"
LOG_FILE="${STATE_DIR}/session-health.log"
mkdir -p "${STATE_DIR}"

units=(
  loq-session.target
  loq-swww.service
  loq-hypridle.service
  loq-hyprpanel.service
  loq-hyprswitch.service
  lumina-shell.service
)

session_units_ready() {
  local unit
  for unit in "${units[@]}"; do
    if ! systemctl --user is-active "${unit}" >/dev/null 2>&1; then
      return 1
    fi
  done
  return 0
}

for ((i = 0; i < 50; i++)); do
  session_units_ready && break
  sleep 0.1
done

failed=()
for unit in "${units[@]}"; do
  if ! systemctl --user is-active "${unit}" >/dev/null 2>&1; then
    failed+=("${unit}")
  fi
done

if ((${#failed[@]})); then
  printf '%s failed: %s\n' "$(date --iso-8601=seconds)" "${failed[*]}" >>"${LOG_FILE}"
  command -v lumina-toast >/dev/null 2>&1 && lumina-toast "Lumina session health" "Failed units: ${failed[*]}" error 2>/dev/null || true
else
  printf '%s ok\n' "$(date --iso-8601=seconds)" >>"${LOG_FILE}"
fi
