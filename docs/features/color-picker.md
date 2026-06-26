# Color Picker

## Purpose

Color Picker samples a screen color, copies the value, and reports the result
through Lumina feedback surfaces.

## Launch Command And Keybind

- Script: `scripts/system/color-picker.sh`
- Linked path: `~/.config/hypr/scripts/color-picker.sh`
- Keybind: `Super + Shift + C`

## Dependencies

- `hyprpicker`
- Optional copy target: `wl-copy`
- Optional feedback: `lumina-shell` or `notify-send`

## Failure Behavior

Missing `hyprpicker` produces a clear unavailable notification and non-zero
exit. Cancelled picks exit without writing clipboard data. Missing `wl-copy`
still prints and reports the sampled color.

## Recovery/Fallback

This feature is non-critical. Manual `hyprpicker` remains available from a
terminal if the keybind path is unavailable.

## Config Paths

- No feature-specific config.

## State Paths

- Popup activity is recorded under `~/.local/state/lumina/shell/` by Lumina Shell.
