# Media Overlay

## Purpose

Media Overlay shows the current player state through the Lumina popup path so
media feedback uses the same shell style as modes, volume, brightness, and
other Phase 6 surfaces.

## Launch Command And Keybind

- Script: `scripts/system/media-overlay.sh`
- Linked path: `~/.config/hypr/scripts/media-overlay.sh`
- Keybind: `Super + Shift + M`

## Dependencies

- Optional: `playerctl`
- Optional feedback: `lumina-shell` or `notify-send`

## Failure Behavior

If `playerctl` is missing or no player is active, the script reports
`unavailable` instead of crashing. If Lumina Shell is unavailable, it falls back
to `notify-send` when present.

## Recovery/Fallback

The feature is non-critical. Media keys still call `playerctl` directly, and
HyprPanel remains available as the broader fallback shell surface.

## Config Paths

- `~/.config/lumina/shell.toml`

## State Paths

- Popup activity is recorded under `~/.local/state/lumina/shell/` by Lumina Shell.
