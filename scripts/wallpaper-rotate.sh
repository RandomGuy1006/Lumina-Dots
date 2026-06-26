#!/usr/bin/env bash
set -euo pipefail
CONFIG="${XDG_CONFIG_HOME:-${HOME}/.config}/lumina/wallpaper.json"
STATE="${XDG_STATE_HOME:-${HOME}/.local/state}/lumina/wallpaper-rotate.stamp"
directory="$(jq -r '.directory // empty' "${CONFIG}" 2>/dev/null || true)"
interval="$(jq -r '.rotation_interval // 30' "${CONFIG}" 2>/dev/null || printf 30)"
[[ -n "${directory}" ]] || directory="${HOME}/Pictures/Wallpapers"
mkdir -p "$(dirname "${STATE}")"
last=0; [[ -f "${STATE}" ]] && last="$(cat "${STATE}" 2>/dev/null || printf 0)"
now="$(date +%s)"
((now - last >= interval * 60)) || exit 0
mapfile -t images < <(find "${directory}" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.avif' \) 2>/dev/null)
((${#images[@]})) || { lumina-toast "Wallpaper rotation failed" "No images in ${directory}" error; exit 1; }
lumina-wallpaper "${images[RANDOM % ${#images[@]}]}"
printf '%s\n' "${now}" >"${STATE}.tmp"; mv "${STATE}.tmp" "${STATE}"
