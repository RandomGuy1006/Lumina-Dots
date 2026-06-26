#!/usr/bin/env bash
# scripts/system/battery-alert.sh
# Polls battery state and sends desktop notifications at critical levels.
# Runs as a persistent daemon via exec-once in exec.conf.
# Requires: dunst/hyprpanel (for notifications), upower
set -euo pipefail

INTERVAL=60   # Seconds between checks
WARN_LEVEL=20 # % to trigger "Low battery" warning
CRIT_LEVEL=10 # % to trigger "Critical battery" alert
SENT_WARN=0
SENT_CRIT=0

battery_percent() {
  # Try upower first (most accurate), fall back to sysfs
  if command -v upower &>/dev/null; then
    local bat
    bat="$(upower -e | grep -i battery | head -1)"
    if [[ -n "${bat}" ]]; then
      upower -i "${bat}" | awk '/percentage/{gsub(/%/,"",$2); print $2}' | head -1
      return
    fi
  fi
  # Fallback: read from sysfs
  cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo "100"
}

is_charging() {
  local status
  status="$(cat /sys/class/power_supply/BAT0/status 2>/dev/null || echo "Unknown")"
  [[ "${status}" == "Charging" || "${status}" == "Full" ]]
}

notify() {
  local urgency="$1"
  local title="$2"
  local body="$3"
  if command -v lumina-shell >/dev/null 2>&1; then
    lumina-shell popup battery --body "${title}: ${body}" --urgency "${urgency}" >/dev/null 2>&1 || true
  else
    lumina-toast "${title}" "${body}" warning 2>/dev/null || true
  fi
}

while true; do
  sleep "${INTERVAL}"

  if is_charging; then
    SENT_WARN=0
    SENT_CRIT=0
    continue
  fi

  PERCENT="$(battery_percent)"
  PERCENT="${PERCENT%%.*}" # strip decimals

  if ((PERCENT <= CRIT_LEVEL && SENT_CRIT == 0)); then
    notify "critical" "Critical Battery" "${PERCENT}% - Plug in now or data will be lost"
    SENT_CRIT=1
    SENT_WARN=1
  elif ((PERCENT <= WARN_LEVEL && SENT_WARN == 0)); then
    notify "normal" "Low Battery" "${PERCENT}% remaining - Consider plugging in"
    SENT_WARN=1
  elif ((PERCENT > WARN_LEVEL)); then
    SENT_WARN=0
    SENT_CRIT=0
  fi
done
