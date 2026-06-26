#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}/lumina"
NOTES_FILE="${STATE_DIR}/scratch-notes.md"

mkdir -p "${STATE_DIR}"
touch "${NOTES_FILE}"

if command -v uwsm >/dev/null 2>&1; then
  exec uwsm app -- ghostty --class=lumina-notes -e nvim "${NOTES_FILE}"
fi

exec ghostty --class=lumina-notes -e nvim "${NOTES_FILE}"
