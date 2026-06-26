# Keybind Overlay

## Purpose

The keybind overlay provides a searchable, categorized view of Hyprland binds
and exposes generated data for documentation sync.

## Launch Command And Keybind

- Keybind: `Super + /`
- CLI: `lumina-keybind-overlay`
- JSON: `lumina-keybind-overlay --json`
- Docs export: `lumina-keybind-overlay --export-docs docs/keybindings.generated.md`

## Dependencies

- `apps/keybind-overlay/lumina-keybind-overlay.py`
- `hypr/.config/hypr/binds.conf`
- `lumina_core.hyprland`

## Failure Behavior

If GTK is unavailable, matching keybinds print to stdout.

## Config Paths

- `hypr/.config/hypr/binds.conf`

## State Paths

No persistent user state is required.

