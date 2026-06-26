#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "${TMP_ROOT}"' EXIT

export HOME="${TMP_ROOT}/home"
export XDG_CACHE_HOME="${TMP_ROOT}/cache"
export DOTFILES_DIR="${ROOT}"
export LOG_FILE="${TMP_ROOT}/theme-render.log"
mkdir -p "${HOME}" "${XDG_CACHE_HOME}/lumina"

PYTHONPATH="${ROOT}/apps/lib" python3 - <<'PY' >"${XDG_CACHE_HOME}/lumina/visual-tokens.json"
import json
from lumina_core.theme import FALLBACK_TOKENS
print(json.dumps(FALLBACK_TOKENS))
PY

bash "${ROOT}/scripts/theme/render-visual-tokens.sh" >/dev/null

for file in \
  "${HOME}/.config/hypr/tokens.conf" \
  "${HOME}/.config/walker/themes/generated.css" \
  "${HOME}/.config/wlogout/colors.css" \
  "${HOME}/.config/ghostty/lumina-tokens.conf" \
  "${HOME}/.config/ghostty/themes/LoqDynamic" \
  "${HOME}/.config/hyprpanel/theme.generated.json"; do
  [[ -s "${file}" ]]
done

printf 'sentinel\n' >"${HOME}/.config/hypr/tokens.conf"
printf '{"colors": {}}\n' >"${XDG_CACHE_HOME}/lumina/visual-tokens.json"
if bash "${ROOT}/scripts/theme/render-visual-tokens.sh" >/dev/null 2>&1; then
  printf 'Renderer unexpectedly accepted incomplete tokens\n'
  exit 1
fi
grep -qx sentinel "${HOME}/.config/hypr/tokens.conf"

printf 'Atomic theme rendering tests passed\n'
