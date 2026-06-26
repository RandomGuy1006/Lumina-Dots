# Welcome App

## Purpose

Lumina Welcome guides first login setup without becoming a permanent startup
surface.

## Launch Command

- `lumina-welcome`
- `dotfiles welcome`
- `lumina-welcome --force`

## Features

- First login detection.
- Wallpaper selection entrypoint.
- Theme application entrypoint.
- Keybind overview entrypoint.
- Documentation links.
- Snapshot creation button.
- Skip option.
- Never reappears after completion unless manually launched with `--force`.

## Dependencies

- `apps/welcome/lumina-welcome.py`
- `lumina_core.app`
- `lumina_core.state`
- `dotfiles backup`
- `dotfiles theme`

## Failure Behavior

If GTK is unavailable, the app prints CLI guidance and exits cleanly.

## Config Paths

- `~/.config/lumina/shell.toml`

## State Paths

- `~/.local/state/lumina/welcome/state.json`

