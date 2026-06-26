# Future Quickshell Readiness

Quickshell is not a production dependency and this release does not replace GTK or HyprPanel.

## Public Boundary

- `lumina-shell capabilities` publishes supported queries, commands, events, and frontends.
- `lumina-shell status --json`, `modes --json`, and `snapshot` publish versioned snapshots.
- `lumina-shell events` publishes newline-delimited versioned Hyprland events.
- `lumina-shell tokens` publishes the current visual-token snapshot.
- OSD, popup, mode, workspace, monitor, service, and visual-token data remain toolkit-neutral.

## Migration Rules

- A future Quickshell frontend may render contracts and invoke public commands.
- It must not import internal Python modules or implement system mutation independently.
- GTK and HyprPanel remain available until feature parity, fallback, recovery, scaling, accessibility, and soak gates pass.
- Migration must be reversible by switching the enabled frontend service; state formats remain shared.

Readiness is achieved when an external mock consumer can render snapshots and process events without GTK imports.

The canonical envelope schema is `schemas/lumina-shell-envelope.schema.json`; versioned fixtures live under `schemas/fixtures/`.
