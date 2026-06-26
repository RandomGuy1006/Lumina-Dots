# Universal Popup Framework

## Purpose

The Universal Popup Framework gives Lumina Shell one shared event surface for
small user feedback: OSD values, mode changes, theme events, battery warnings,
Bluetooth state, screenshot confirmations, and future quick actions.

## Launch Command And Keybind

- CLI: `lumina-shell popup <event> [--body text] [--progress 0-100]`
- Used by: volume, brightness, microphone mute, wallpaper/theme scripts,
  screenshot script, battery alerts, and performance mode changes.

## Dependencies

- `apps/shell/components/popups.py`
- `lumina_core.theme`
- `lumina_core.state`
- `lumina_core.notifications`

## Failure Behavior

If GTK or layer-shell is unavailable, events degrade to `notify-send` through
Lumina Core. If `notify-send` is unavailable, the event is logged and the last
popup payload is still written to Lumina state.

## Recovery/Fallback

HyprPanel remains the fallback notification and OSD surface. Popup state lives
under `~/.local/state/lumina/shell/`.

## Config Paths

- `~/.config/lumina/shell.toml`

## State Paths

- `~/.local/state/lumina/shell/popup-last.json`
- `~/.local/state/lumina/shell/popup-queue.json`

