#!/usr/bin/env bash
set -euo pipefail

ROOT="${LOQDOTS_ROOT:-${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}}"
DOTFILES_DIR="${DOTFILES_DIR:-$ROOT}"
LOQDOTS_ROOT="${LOQDOTS_ROOT:-$DOTFILES_DIR}"
export DOTFILES_DIR LOQDOTS_ROOT
source "$ROOT/lib/common.sh"

load_host_profile
require_cmd jq

ensure_dir "$HOME/.config/hyprpanel"
base="$HOME/.config/hyprpanel/base.json"
generated="$HOME/.config/hyprpanel/theme.generated.json"
config="$HOME/.config/hyprpanel/config.json"
wallpaper_path=""

if [[ -s "$(current_wallpaper_file)" ]]; then
  wallpaper_path="$(cat "$(current_wallpaper_file)")"
fi

[[ -f "$generated" ]] || printf '{}\n' >"$generated"

jq -s --arg wallpaper "$wallpaper_path" '
    .[0] * .[1]
    | if $wallpaper != "" then .["wallpaper.image"] = $wallpaper else . end
' "$base" "$generated" >"$config.tmp"
mv "$config.tmp" "$config"

pass "Built HyprPanel runtime config"
