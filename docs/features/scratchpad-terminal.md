# Scratchpad Terminal

## Purpose

Scratchpad Terminal provides a quick transient terminal surface on a Hyprland
special workspace without stealing normal terminal or workspace navigation
binds.

## Launch Command And Keybind

- Script: `scripts/system/scratchpad-terminal.sh`
- Linked path: `~/.config/hypr/scripts/scratchpad-terminal.sh`
- Keybind: `Super + grave`
- Previous workspace moved to `Super + Ctrl + grave`.

## Dependencies

- `hyprctl`
- `ghostty`
- Optional: `uwsm`

## Failure Behavior

The script toggles `special:scratch` and starts a `lumina-scratch` Ghostty
window only if one is not already running. Hyprland dispatch failures are
ignored so the script remains harmless outside a live Hyprland session.

## Recovery/Fallback

If the scratchpad does not appear, Ghostty can still be launched with
`Super + Return`, and previous workspace remains available at
`Super + Ctrl + grave`.

## Config Paths

- Hyprland rules and keybinds under `~/.config/hypr/`.

## State Paths

- No persistent state.
