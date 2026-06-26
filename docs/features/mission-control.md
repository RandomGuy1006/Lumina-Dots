# Lumina Mission Control

Mission Control is the Phase 4 workspace and window overview.

- App: `apps/mission-control/lumina-mission-control.py`
- CLI: `lumina-mission-control`
- Dotfiles command: `dotfiles mission-control`
- Keybind: `Super + Tab`

Mission Control uses Lumina Core Hyprland wrappers over `hyprctl -j clients` and `hyprctl -j workspaces`. It does not require `hyprexpo`, `hyprland-overview`, `hyprpm`, or any Hyprland overview plugin.

Workspace cycling moved from `Super + Tab` and `Super + Shift + Tab` to `Super + ]` and `Super + [` so Mission Control can own the overview namespace.
