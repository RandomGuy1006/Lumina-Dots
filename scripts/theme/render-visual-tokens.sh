#!/usr/bin/env bash
# Render Matugen token JSON into the runtime files consumed by shell surfaces.
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "${DOTFILES_DIR}/lib/log.sh"

TOKEN_JSON="${XDG_CACHE_HOME:-${HOME}/.cache}/lumina/visual-tokens.json"
CACHE_ROOT="${XDG_CACHE_HOME:-${HOME}/.cache}"
mkdir -p "${CACHE_ROOT}"
STAGE_DIR="$(mktemp -d "${CACHE_ROOT}/lumina-theme.XXXXXX")"
trap 'rm -rf "${STAGE_DIR}"' EXIT

if [[ ! -s "${TOKEN_JSON}" ]]; then
  log::fatal "Visual token JSON missing or empty: ${TOKEN_JSON}. Run: lumina-theme apply --wallpaper <path> to generate tokens first."
fi

if ! command -v jq >/dev/null 2>&1; then
  log::fatal "jq not installed; cannot render visual tokens. Install jq and rerun."
fi

read_token() {
  jq -er "$1 | select(. != null and . != \"\")" "${TOKEN_JSON}"
}

require_token() {
  local key="$1"

  if ! jq -e --arg key "${key}" '
    getpath($key | split(".")) | select(. != null and . != "")
  ' "${TOKEN_JSON}" >/dev/null; then
    log::fatal "Visual token JSON is missing required key: ${key}"
  fi
}

for key in \
  colors.fg colors.muted colors.surface colors.surface_alt colors.surface_high \
  colors.accent colors.accent_alt colors.warning colors.danger colors.outline \
  colors.on_accent colors.primary_container colors.on_primary_container \
  colors.secondary_container \
  spacing.gap_inner spacing.gap_outer spacing.chip spacing.item spacing.panel \
  spacing.shell \
  typography.ui_family typography.mono_family typography.caption_px \
  typography.body_px typography.title_px typography.display_px \
  typography.line_height \
  icons.small icons.regular icons.large \
  stroke.hairline stroke.focus \
  radius.chip radius.item radius.shell \
  shadow.range shadow.render_power \
  motion.curve_css motion.micro_ms motion.panel_ms motion.exit_ms \
  motion.wallpaper_ms; do
  require_token "${key}"
done

mkdir -p \
  "${HOME}/.config/hypr" \
  "${HOME}/.config/walker/themes" \
  "${HOME}/.config/wlogout" \
  "${HOME}/.config/ghostty" \
  "${HOME}/.config/ghostty/themes" \
  "${HOME}/.config/hyprpanel"

mkdir -p \
  "${STAGE_DIR}/hypr" \
  "${STAGE_DIR}/walker" \
  "${STAGE_DIR}/wlogout" \
  "${STAGE_DIR}/ghostty/themes" \
  "${STAGE_DIR}/hyprpanel"

cat >"${STAGE_DIR}/hypr/tokens.conf" <<EOF
# Generated from Matugen visual-tokens.json.
\$gap_inner = $(read_token '.spacing.gap_inner')
\$gap_outer = $(read_token '.spacing.gap_outer')
\$radius_shell = $(read_token '.radius.shell')
\$radius_item = $(read_token '.radius.item')
\$radius_chip = $(read_token '.radius.chip')
\$shadow_range = $(read_token '.shadow.range')
\$shadow_render_power = $(read_token '.shadow.render_power')
EOF

cat >"${STAGE_DIR}/walker/generated.css" <<EOF
@define-color fg $(read_token '.colors.fg');
@define-color muted $(read_token '.colors.muted');
@define-color surface $(read_token '.colors.surface');
@define-color surface_alt $(read_token '.colors.surface_alt');
@define-color accent $(read_token '.colors.accent');

window {
    background: @surface;
    border-radius: $(read_token '.radius.shell')px;
    border: 1px solid alpha(@accent, 0.34);
    box-shadow: 0 24px 90px alpha(@surface, 0.45);
    color: @fg;
    font-family: "$(read_token '.typography.ui_family')";
    font-size: $(read_token '.typography.body_px')px;
}

entry {
    margin: $(read_token '.spacing.shell')px $(read_token '.spacing.shell')px $(read_token '.spacing.item')px;
    min-height: 54px;
    border-radius: $(read_token '.radius.shell')px;
    padding: 0 $(read_token '.spacing.panel')px;
    background: @surface_alt;
    color: @fg;
    border: 1px solid alpha(@accent, 0.12);
    font-size: $(read_token '.typography.body_px')px;
}

list {
    margin: 0 $(read_token '.spacing.item')px $(read_token '.spacing.item')px;
    padding: $(read_token '.spacing.chip')px;
    background: transparent;
}

child {
    min-height: 50px;
    margin: $(read_token '.spacing.gap_inner')px 0;
    border-radius: $(read_token '.radius.item')px;
    padding: 0 $(read_token '.spacing.item')px;
    background: transparent;
    color: @fg;
    transition: $(read_token '.motion.micro_ms')ms cubic-bezier($(read_token '.motion.curve_css'));
}

child:selected {
    background: alpha(@accent, 0.18);
    border: 1px solid alpha(@accent, 0.24);
}

child:focus-visible, entry:focus-visible {
    outline: $(read_token '.stroke.focus')px solid @accent;
    outline-offset: $(read_token '.spacing.gap_inner')px;
}

label.sub {
    color: @muted;
    font-size: $(read_token '.typography.caption_px')px;
}
EOF

cat >"${STAGE_DIR}/wlogout/colors.css" <<EOF
:root {
    --accent: $(read_token '.colors.accent');
    --accent-alt: $(read_token '.colors.accent_alt');
    --surface: $(read_token '.colors.surface');
    --surface-alt: $(read_token '.colors.surface_alt');
    --fg: $(read_token '.colors.fg');
    --muted: $(read_token '.colors.muted');
    --danger: $(read_token '.colors.danger');
    --radius-shell: $(read_token '.radius.shell')px;
    --radius-item: $(read_token '.radius.item')px;
    --space-item: $(read_token '.spacing.item')px;
    --motion-fast: $(read_token '.motion.micro_ms')ms cubic-bezier($(read_token '.motion.curve_css'));
}
EOF

cat >"${STAGE_DIR}/ghostty/lumina-tokens.conf" <<EOF
window-padding-x = $(read_token '.spacing.panel')
window-padding-y = $(read_token '.spacing.item')
EOF

cat >"${STAGE_DIR}/ghostty/themes/LoqDynamic" <<EOF
palette = 0=$(read_token '.colors.surface')
palette = 1=$(read_token '.colors.danger')
palette = 2=$(read_token '.colors.accent_alt')
palette = 3=$(read_token '.colors.warning')
palette = 4=$(read_token '.colors.accent')
palette = 5=$(read_token '.colors.secondary_container')
palette = 6=$(read_token '.colors.accent_alt')
palette = 7=$(read_token '.colors.fg')
palette = 8=$(read_token '.colors.surface_high')
palette = 9=$(read_token '.colors.danger')
palette = 10=$(read_token '.colors.accent_alt')
palette = 11=$(read_token '.colors.warning')
palette = 12=$(read_token '.colors.accent')
palette = 13=$(read_token '.colors.secondary_container')
palette = 14=$(read_token '.colors.accent_alt')
palette = 15=$(read_token '.colors.fg')
background = $(read_token '.colors.surface')
foreground = $(read_token '.colors.fg')
cursor-color = $(read_token '.colors.accent')
selection-background = $(read_token '.colors.primary_container')
selection-foreground = $(read_token '.colors.on_primary_container')
EOF

jq '{
  "theme.bar.background": .colors.surface,
  "theme.bar.buttons.background": .colors.surface_alt,
  "theme.bar.buttons.text": .colors.fg,
  "theme.bar.buttons.icon": .colors.accent,
  "theme.bar.buttons.hover": .colors.surface_high,
  "theme.bar.buttons.border": .colors.outline,
  "theme.bar.buttons.dashboard.background": .colors.surface_alt,
  "theme.bar.buttons.dashboard.icon": .colors.accent,
  "theme.bar.buttons.workspaces.background": .colors.surface_alt,
  "theme.bar.buttons.workspaces.active": .colors.accent,
  "theme.bar.buttons.workspaces.occupied": .colors.fg,
  "theme.bar.buttons.workspaces.available": .colors.muted,
  "theme.bar.buttons.windowtitle.background": .colors.surface_alt,
  "theme.bar.buttons.windowtitle.text": .colors.fg,
  "theme.bar.buttons.media.background": .colors.surface_alt,
  "theme.bar.buttons.media.text": .colors.fg,
  "theme.bar.buttons.media.icon": .colors.accent_alt,
  "theme.bar.buttons.volume.background": .colors.surface_alt,
  "theme.bar.buttons.volume.text": .colors.fg,
  "theme.bar.buttons.volume.icon": .colors.accent,
  "theme.bar.buttons.network.background": .colors.surface_alt,
  "theme.bar.buttons.network.text": .colors.fg,
  "theme.bar.buttons.network.icon": .colors.accent,
  "theme.bar.buttons.bluetooth.background": .colors.surface_alt,
  "theme.bar.buttons.bluetooth.text": .colors.fg,
  "theme.bar.buttons.bluetooth.icon": .colors.accent_alt,
  "theme.bar.buttons.battery.background": .colors.surface_alt,
  "theme.bar.buttons.battery.text": .colors.fg,
  "theme.bar.buttons.battery.icon": .colors.warning,
  "theme.bar.buttons.clock.background": .colors.surface_alt,
  "theme.bar.buttons.clock.text": .colors.fg,
  "theme.bar.buttons.clock.icon": .colors.accent,
  "theme.bar.buttons.notifications.background": .colors.surface_alt,
  "theme.bar.buttons.notifications.icon": .colors.accent,
  "theme.bar.buttons.notifications.total": .colors.danger,
  "theme.bar.menus.background": .colors.surface,
  "theme.bar.menus.cards": .colors.surface_alt,
  "theme.bar.menus.text": .colors.fg,
  "theme.bar.menus.label": .colors.accent,
  "theme.bar.menus.border.color": .colors.outline,
  "theme.bar.border_radius": (.radius.shell|tostring) + "px",
  "theme.osd.icon_container": .colors.accent,
  "theme.osd.icon": .colors.on_accent,
  "theme.osd.bar_container": .colors.surface,
  "theme.osd.bar_color": .colors.accent,
  "theme.osd.label": .colors.fg,
  "theme.notification.background": .colors.surface,
  "theme.notification.border": .colors.outline,
  "theme.notification.label": .colors.accent,
  "theme.notification.text": .colors.fg,
  "theme.notification.border_radius": (.radius.shell | tostring) + "px",
  "theme.notification.border_size": (.stroke.hairline | tostring) + "px",
  "theme.notification.margin_top": (.spacing.item | tostring) + "px",
  "theme.notification.margin_right": (.spacing.item | tostring) + "px",
  "theme.notification.padding": (.spacing.panel | tostring) + "px",
  "menus.transitionTime": .motion.panel_ms
}' "${TOKEN_JSON}" >"${STAGE_DIR}/hyprpanel/theme.generated.json"

for staged in \
  "${STAGE_DIR}/hypr/tokens.conf" \
  "${STAGE_DIR}/walker/generated.css" \
  "${STAGE_DIR}/wlogout/colors.css" \
  "${STAGE_DIR}/ghostty/lumina-tokens.conf" \
  "${STAGE_DIR}/ghostty/themes/LoqDynamic" \
  "${STAGE_DIR}/hyprpanel/theme.generated.json"; do
  [[ -s "${staged}" ]] || log::fatal "Refusing to publish empty rendered theme file: ${staged}"
done

publish_atomic() {
  local source="$1"
  local destination="$2"
  local temporary="${destination}.tmp.$$"
  install -m 0644 "${source}" "${temporary}"
  mv -f "${temporary}" "${destination}"
}

publish_atomic "${STAGE_DIR}/hypr/tokens.conf" "${HOME}/.config/hypr/tokens.conf"
publish_atomic "${STAGE_DIR}/walker/generated.css" "${HOME}/.config/walker/themes/generated.css"
publish_atomic "${STAGE_DIR}/wlogout/colors.css" "${HOME}/.config/wlogout/colors.css"
publish_atomic "${STAGE_DIR}/ghostty/lumina-tokens.conf" "${HOME}/.config/ghostty/lumina-tokens.conf"
publish_atomic "${STAGE_DIR}/ghostty/themes/LoqDynamic" "${HOME}/.config/ghostty/themes/LoqDynamic"
publish_atomic "${STAGE_DIR}/hyprpanel/theme.generated.json" "${HOME}/.config/hyprpanel/theme.generated.json"

log::success "Visual tokens rendered to Hyprland, Walker, Wlogout, Ghostty, and Hyprpanel"
