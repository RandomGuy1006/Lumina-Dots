# Scratch Notes

## Purpose

Scratch Notes gives Lumina a fast local note buffer without adding a network
service, account, or database. It reuses Ghostty and Neovim so notes stay simple
and recoverable.

## Launch Command And Keybind

- Script: `scripts/system/scratch-notes.sh`
- Linked path: `~/.config/hypr/scripts/scratch-notes.sh`
- Keybind: `Super + N`
- Neovim direct launcher moved to `Super + Shift + N`.

## Dependencies

- `ghostty`
- `nvim`
- Optional: `uwsm`

## Failure Behavior

The script creates the Lumina state directory and note file before launch. If
UWSM is unavailable, it launches Ghostty directly.

## Recovery/Fallback

The notes are plain Markdown and can be opened manually from the state path if
the GUI launcher fails.

## Config Paths

- No feature-specific config.

## State Paths

- `~/.local/state/lumina/scratch-notes.md`
