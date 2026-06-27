# Lumina Modes

## Purpose

Lumina Modes expose shared shell behavior profiles for future components.

## Modes

- Quiet Mode: reduced animations, lower polling rates, battery friendly.
- Auto Mode: hardware-aware defaults.
- Performance Mode: full effects, faster updates, maximum responsiveness.
- Custom Mode: user-configurable, with the distinct `custom-prism`
  mode-selection animation.

## Launch Command

- `lumina-shell modes`
- `lumina-shell mode quiet`
- `lumina-shell mode auto`
- `lumina-shell mode performance`
- `lumina-shell mode custom`

## Dependencies

- `apps/shell/components/modes.py`
- `apps/shell/components/popups.py`
- `lumina_core.state`

## Failure Behavior

Invalid mode names are rejected. Missing state falls back to Auto Mode.

## Config Paths

- `~/.config/lumina/shell.json`

## State Paths

- `~/.local/state/lumina/shell/mode.json`
- `~/.local/state/lumina/shell/custom-mode.json`
