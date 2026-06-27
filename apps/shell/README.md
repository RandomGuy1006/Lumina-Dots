# Lumina Shell

Lumina Shell is the Lumina-owned desktop surface layer. It starts as a
conservative GTK/libadwaita service with HyprPanel preserved as the fallback.

Implemented entrypoints:

- `lumina-shell` or `lumina-shell run` starts the GTK shell surface.
- `lumina-shell status` prints service, fallback, mode, and workspace state.
- `lumina-shell osd volume` and `lumina-shell osd brightness` show the current
  OSD value through Lumina Core notification fallback.

Configuration lives at `~/.config/lumina/shell.json`. Runtime logs are written
under `~/.local/state/lumina/logs/`.
