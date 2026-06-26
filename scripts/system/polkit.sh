#!/usr/bin/env bash
# scripts/system/polkit.sh
# Start the Hyprland-native polkit agent.
# Runs via exec-once in exec.conf — ensures exactly one instance.
set -euo pipefail

# Kill any stale instance first (idempotent)
pkill -f '/hyprpolkitagent($| )' 2>/dev/null || true

# Brief wait then launch via UWSM app wrapper
# (ensures correct cgroup and env for the session)
if command -v hyprpolkitagent >/dev/null 2>&1; then
  exec uwsm app -- hyprpolkitagent
fi

exec uwsm app -- /usr/lib/hyprpolkitagent/hyprpolkitagent
