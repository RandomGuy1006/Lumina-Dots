# Phase 2 Architecture Snapshot

Phase 2 established the first-party Lumina application layer that now sits beside the Hyprland dotfiles. The current implementation is made of Python entrypoints under `apps/`, shared helpers under `apps/lib/lumina_core/`, and shell-facing launchers linked through `lib/link.sh`.

## Current surfaces

- Lumina Shell lives in `apps/shell/lumina-shell.py` with reusable components in `apps/shell/components/` and hardware/session adapters in `apps/shell/adapters/`.
- Shared application behavior lives in `apps/lib/lumina_core/`: theme token loading, state paths, subprocess wrappers, notifications, Hyprland calls, GTK helpers, and window/layer-shell helpers.
- Phase 2 user tools include Welcome, Keybind Overlay, Control Center, Lumina Shell modes, and popup/OSD plumbing.
- Runtime state is intentionally kept outside the repo under `~/.local/state/lumina`, while Matugen-derived design tokens are loaded from `~/.cache/lumina/visual-tokens.json`.

## Invariants

- GUI app entrypoints import `lumina_core` instead of hardcoding state paths, notification calls, or theme token parsing.
- `custom` is the supported high-energy shell mode; the older `crazy` mode name is not part of the current API.
- `Super + /` opens the keybind overlay, `Super + C` opens Control Center, and `Super + L` opens Lumina Hub. Lock is `Super + Escape`.
- The desktop session is TTY autologin plus UWSM and Hyprlock, not a display-manager flow.

## Verification

Validated by `tests/validate-lumina-core.py`, `tests/validate-lumina-architecture.py`, and `tests/test-lumina-phase2.py`.
