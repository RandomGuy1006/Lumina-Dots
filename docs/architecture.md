# Lumina Architecture

## Ownership

- `lumina_core` owns configuration, state persistence, command execution, service queries, Hyprland queries, notifications, visual tokens, and public contracts.
- Shell components own domain behavior such as modes, OSD, popups, workspaces, and media. They must not depend on GTK widgets.
- Shell adapters own external protocols such as Hyprland sockets, PipeWire, brightnessctl, and playerctl.
- GTK/libadwaita applications own presentation only. HyprPanel remains the production bar and notification fallback.
- Bash scripts own installation, system mutation, recovery, and generated desktop configuration.

## Data Flow

1. Adapters query or subscribe to external services.
2. Components normalize data into versioned backend-neutral contracts.
3. Atomic state files provide restart snapshots under `~/.local/state/lumina`.
4. GTK, CLI, and future frontends consume the same contracts.
5. System mutations remain in Lumina Core adapters or audited scripts.

## Reliability Boundaries

- Optional desktop dependencies degrade to structured state, logs, or HyprPanel rather than breaking login.
- Generated theme files are validated before publication.
- User services have bounded restart bursts and short stop timeouts.
- Recovery operations remain separate from normal UI controls and record transaction evidence.

Human-readable CLI output remains supported. Machine consumers use envelopes containing `schema_version`, `kind`, `timestamp`, and `data`.
