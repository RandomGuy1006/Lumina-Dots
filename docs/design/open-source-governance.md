# Open Source Governance

Lumina Dots extension work must preserve the frozen architecture.

- Shared Python behavior belongs in `apps/lib/lumina_core/`.
- Desktop shell behavior belongs in `apps/shell/`.
- Product apps belong in their own `apps/<name>/` directories and launch through `lumina-*` entry points.
- Runtime state belongs under Lumina Core state paths, normally `~/.local/state/lumina`.
- Generated theme outputs remain runtime files and must not be tracked in managed config trees.
- New keybinds must be checked against `hypr/.config/hypr/binds.conf` and documented in `docs/keybindings.md`.
- New packages must be added once, in the correct manifest, with no duplicate pacman declarations.

Public app APIs should be CLI-friendly: every first-party GUI app needs a non-GTK status, JSON, list, or preview path where practical so validation can run outside a live Hyprland session.
