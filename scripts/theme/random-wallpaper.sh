#!/usr/bin/env bash
set -euo pipefail

WALLPAPER_DIR="${WALLPAPER_DIR:-${HOME}/Pictures/Wallpapers}"
CURRENT_FILE="${WALLPAPER_DIR}/.current"
current=""
[[ -f "${CURRENT_FILE}" ]] && current="$(cat "${CURRENT_FILE}")"

mapfile -t images < <(find "${WALLPAPER_DIR}" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.avif' \) 2>/dev/null | sort)
if ((${#images[@]} == 0)); then
  echo "No wallpapers found in ${WALLPAPER_DIR}" >&2
  exit 1
fi

choices=()
for image in "${images[@]}"; do
  [[ "${image}" != "${current}" ]] && choices+=("${image}")
done
((${#choices[@]} == 0)) && choices=("${images[@]}")
selected="${choices[$RANDOM % ${#choices[@]}]}"
dotfiles theme "${selected}"
