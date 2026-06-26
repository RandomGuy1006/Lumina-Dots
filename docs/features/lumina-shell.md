# Lumina Shell

## Purpose

Lumina Shell provides the first-party desktop feedback layer for Lumina Dots:
OSD events, workspace state, shared popups, and mode-aware behavior while
HyprPanel remains the fallback shell surface.

## Launch Command And Keybind

- Service: `lumina-shell.service`
- CLI: `lumina-shell status`, `lumina-shell status --json`, `lumina-shell snapshot`, `lumina-shell capabilities`, `lumina-shell events`, `lumina-shell popup <event>`, `lumina-shell mode <name>`
- Dotfiles command: `dotfiles shell status`
- Keybinds: hardware volume and brightness keys route through Lumina controls; mode and popup events are surfaced by the shell.

## Dependencies

- Python GTK/libadwaita stack from the package manifests
- Optional GTK layer-shell bindings
- `apps/lib/lumina_core`
- `apps/shell/components/*`
- `lumina/.config/lumina/shell.toml`

## Failure Behavior

Missing GTK layer-shell opens or degrades as a normal GTK surface where possible.
Missing token JSON uses Lumina Core fallback tokens. Missing `notify-send` or
session bus degrades to logs and state files instead of crashing.

## Recovery/Fallback

HyprPanel remains enabled as the stable fallback. Stopping
`lumina-shell.service` must not break login, Walker, HyprPanel, theme recovery,
or `dotfiles doctor`.

Persistent public state and CLI responses use versioned envelopes. State writes are atomic and preserve a last-known-good backup for corruption recovery. GTK widgets consume these contracts but do not define them.

## Config Paths

- `~/.config/lumina/shell.toml`
- `~/.cache/lumina/visual-tokens.json`

## State Paths

- `~/.local/state/lumina/shell/`
- `~/.local/state/lumina/logs/`
