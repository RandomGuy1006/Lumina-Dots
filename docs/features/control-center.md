# Control Center

## Purpose

Lumina Control Center provides a compact MVP surface for common desktop state
and quick actions.

## Launch Command And Keybind

- Keybind: `Super + C`
- CLI: `lumina-control-center`
- Status: `lumina-control-center status`

## Included Controls

- Audio volume and mute.
- Brightness up/down.
- Network status.
- Bluetooth status.
- Night Light toggle.
- Lumina mode selector.
- Quick actions for lock, screenshot, power menu, keybinds, and Welcome.

## Dependencies

- `apps/control-center/lumina-control-center.py`
- `wpctl`
- `brightnessctl`
- `nmcli`
- `bluetoothctl`
- `hyprsunset`
- `lumina-shell`

## Failure Behavior

Missing commands return unavailable state or a failed action without crashing.
User-facing changes route through the Universal Popup Framework.

## Config Paths

- `~/.config/lumina/shell.toml`

## State Paths

- Shared Lumina Shell popup and mode state under `~/.local/state/lumina/shell/`.

