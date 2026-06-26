#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}/lumina/focus-mode"
STATE_FILE="${STATE_DIR}/windows"
mkdir -p "${STATE_DIR}"

notify() {
  command -v lumina-toast >/dev/null 2>&1 && lumina-toast "Focus Mode" "$1" info 2>/dev/null || true
  command -v lumina-shell >/dev/null 2>&1 && lumina-shell popup mode --body "$1" >/dev/null 2>&1 || true
}

if [[ -s "${STATE_FILE}" ]]; then
  while IFS='|' read -r address workspace; do
    [[ -n "${address}" && -n "${workspace}" ]] || continue
    hyprctl dispatch movetoworkspacesilent "${workspace},address:${address}" >/dev/null 2>&1 || true
  done <"${STATE_FILE}"
  rm -f "${STATE_FILE}"
  hyprctl keyword general:gaps_in 5 >/dev/null 2>&1 || true
  hyprctl keyword general:gaps_out 10 >/dev/null 2>&1 || true
  notify "Off - windows restored"
  exit 0
fi

if ! command -v hyprctl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
  notify "Unavailable - hyprctl or jq missing"
  exit 1
fi

focused="$(hyprctl activewindow -j 2>/dev/null | jq -r '.address // empty')"
if [[ -z "${focused}" ]]; then
  notify "No focused window"
  exit 1
fi

hyprctl clients -j | jq -r --arg focused "${focused}" '.[] | select(.address != $focused and (.mapped // true)) | [.address, (.workspace.name // .workspace.id | tostring)] | @tsv' |
  while IFS=$'\t' read -r address workspace; do
    [[ -n "${address}" && -n "${workspace}" ]] || continue
    printf '%s|%s\n' "${address}" "${workspace}" >>"${STATE_FILE}"
    hyprctl dispatch movetoworkspacesilent "special:focus-hidden,address:${address}" >/dev/null 2>&1 || true
  done

hyprctl keyword general:gaps_in 0 >/dev/null 2>&1 || true
hyprctl keyword general:gaps_out 0 >/dev/null 2>&1 || true
notify "On - distractions hidden"
