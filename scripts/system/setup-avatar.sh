#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "${DOTFILES_DIR}/lib/log.sh"

if [[ -f "${HOME}/.face" ]]; then
  exit 0
fi

if command -v magick >/dev/null 2>&1; then
  convert_cmd=(magick)
elif command -v convert >/dev/null 2>&1; then
  convert_cmd=(convert)
else
  log::warn "ImageMagick not installed; skipping avatar generation"
  exit 0
fi

username="${USER:-user}"
initial="${username:0:1}"

# Read avatar colors from Lumina design system tokens (RULE-002 compliance)
if command -v python3 >/dev/null 2>&1 && python3 -c "import sys; sys.path.insert(0, '${DOTFILES_DIR}/apps/lib'); import lumina_core" 2>/dev/null; then
  AVATAR_BG=$(python3 -c "import sys; sys.path.insert(0, '${DOTFILES_DIR}/apps/lib'); from lumina_core.theme import FALLBACK_TOKENS; print(FALLBACK_TOKENS['colors']['surface_alt'])")
  AVATAR_FG=$(python3 -c "import sys; sys.path.insert(0, '${DOTFILES_DIR}/apps/lib'); from lumina_core.theme import FALLBACK_TOKENS; print(FALLBACK_TOKENS['colors']['accent'])")
else
  AVATAR_BG="#0f1220"  # FALLBACK_TOKENS colors.surface_alt
  AVATAR_FG="#00f5ff"  # FALLBACK_TOKENS colors.accent
fi

"${convert_cmd[@]}" -size 200x200 xc:"${AVATAR_BG}" \
  -fill "${AVATAR_FG}" -font "Inter-Bold" -pointsize 100 \
  -gravity center -annotate 0 "${initial^^}" \
  "${HOME}/.face" 2>/dev/null || true

[[ -f "${HOME}/.face" ]] && log::success "Created avatar at ~/.face"
