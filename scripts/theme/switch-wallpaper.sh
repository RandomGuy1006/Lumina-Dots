#!/usr/bin/env bash
# scripts/theme/switch-wallpaper.sh — Switch wallpaper with transition + apply theme
# Usage: bash switch-wallpaper.sh <path> [--no-theme] [--no-mood] [--transition-type TYPE] [--transition-duration SEC]
# Transitions: fade, wipe, slide, grow, outer, any, wave (default: fade)
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${SCRIPT_PATH}")/../.." && pwd)}"
source "${DOTFILES_DIR}/lib/log.sh"
source "${DOTFILES_DIR}/lib/host.sh"
source "${DOTFILES_DIR}/lib/common.sh"

host::load "${HOST_PROFILE:-$(host::detect)}" >/dev/null 2>&1 || true

WALLPAPER="${1:-}"
shift || true
NO_THEME=0
NO_MOOD=0
PYTHONPATH="${DOTFILES_DIR}/apps/lib${PYTHONPATH:+:${PYTHONPATH}}"
TRANSITION="${LUMINA_WALLPAPER_TRANSITION:-}"
TRANSITION_DURATION="${LUMINA_WALLPAPER_DURATION:-}"
TRANSITION_FPS="${LUMINA_WALLPAPER_FPS:-120}"
while (($#)); do
  case "$1" in
    --no-theme) NO_THEME=1 ;;
    --no-mood) NO_MOOD=1 ;;
    --transition-type) shift; TRANSITION="${1:?Missing transition type}" ;;
    --transition-type=*) TRANSITION="${1#*=}" ;;
    --transition-duration) shift; TRANSITION_DURATION="${1:?Missing transition duration}" ;;
    --transition-duration=*) TRANSITION_DURATION="${1#*=}" ;;
    *) log::fatal "Unknown option: $1" ;;
  esac
  shift
done

transition_state="$(
  PYTHONPATH="${PYTHONPATH}" python3 - "${TRANSITION}" "${TRANSITION_DURATION}" <<'PY'
import sys
from lumina_core.wallpaper import effective_transition, swww_transition

requested_transition = sys.argv[1] or None
requested_duration = sys.argv[2] or None
transition, duration = effective_transition(requested_transition, requested_duration)
print(f"{transition}\t{swww_transition(transition)}\t{duration:.3f}")
PY
)"
IFS=$'\t' read -r _LUMINA_TRANSITION SWWW_TRANSITION TRANSITION_DURATION <<<"${transition_state}"

if [[ -z "${WALLPAPER}" ]]; then
  log::fatal "Usage: switch-wallpaper.sh <path-to-wallpaper> [transition]"
fi

if [[ ! -f "${WALLPAPER}" ]]; then
  log::fatal "File not found: ${WALLPAPER}"
fi

WALLPAPER="$(realpath "${WALLPAPER}")"

command -v swww >/dev/null 2>&1 || log::fatal "swww is not installed"

# ─── Set wallpaper with swww ─────────────────────────────────────────────────
if ! pgrep -x swww-daemon &>/dev/null; then
  log::step "Starting wallpaper daemon..."
  bash "${DOTFILES_DIR}/scripts/theme/start-swww-daemon.sh" &
  for ((i = 0; i < 50; i++)); do
    swww query &>/dev/null && break
    sleep 0.1
  done
fi

swww query &>/dev/null || log::fatal "swww daemon did not become ready"

log::step "Setting wallpaper: $(basename "${WALLPAPER}")"
swww img "${WALLPAPER}" \
  --transition-type "${SWWW_TRANSITION}" \
  --transition-duration "${TRANSITION_DURATION}" \
  --transition-fps "${TRANSITION_FPS}" \
  --transition-angle 30 \
  --transition-step 90 \
  --transition-bezier .22,1,.36,1

# Theme and mood start only after the compositor transition has completed.
sleep "${TRANSITION_DURATION}"

# ─── Remember current wallpaper ───────────────────────────────────────────────
WALLPAPER_DIR="${HOME}/Pictures/Wallpapers"
mkdir -p "${WALLPAPER_DIR}"
wallpaper_marker="${WALLPAPER_DIR}/.current"
wallpaper_marker_tmp="${wallpaper_marker}.tmp"
printf '%s\n' "${WALLPAPER}" >"${wallpaper_marker_tmp}"
mv -f "${wallpaper_marker_tmp}" "${wallpaper_marker}"
state_marker="$(current_wallpaper_file)"
mkdir -p "$(dirname "${state_marker}")"
state_marker_tmp="${state_marker}.tmp"
printf '%s\n' "${WALLPAPER}" >"${state_marker_tmp}"
mv -f "${state_marker_tmp}" "${state_marker}"

# ─── Apply Matugen theme ──────────────────────────────────────────────────────
if ((NO_THEME == 0)); then
  log::step "Applying adaptive theme..."
  lumina theme apply "${WALLPAPER}"
fi

if ((NO_MOOD == 0)); then
  auto_detect="$(jq -r '.auto_detect // true' "${XDG_CONFIG_HOME:-${HOME}/.config}/lumina/mood.json" 2>/dev/null || printf true)"
  [[ "${auto_detect}" == "true" ]] && lumina-mood detect --wallpaper="${WALLPAPER}" >/dev/null
fi

lumina-ipc wallpaper "${WALLPAPER}"

THUMB_DIR="${XDG_CACHE_HOME:-${HOME}/.cache}/lumina/thumbnails"
PYTHONPATH="${PYTHONPATH}" python3 - "${WALLPAPER}" "${THUMB_DIR}" <<'PY' >/dev/null 2>&1 || true
import sys
from lumina_core.wallpaper import generate_thumbnail

generate_thumbnail(sys.argv[1], sys.argv[2])
PY

lumina-toast "Wallpaper applied" "$(basename "${WALLPAPER}")" success >/dev/null 2>&1 || true

log::success "Wallpaper switched and theme updated"
