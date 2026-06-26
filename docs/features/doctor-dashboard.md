# Lumina Doctor Dashboard

The Doctor Dashboard is the graphical Phase 3 surface for repository and system health.

- App: `apps/doctor-dashboard/lumina-doctor-dashboard.py`
- CLI: `lumina-doctor-dashboard`
- Dotfiles command: `dotfiles doctor-dashboard`
- Keybind: `Super + D`

It reuses `scripts/doctor.sh --porcelain` as the single source of health checks, parses `PASS`, `FAIL`, `WARN`, and `INFO` rows, and emits a Lumina popup summary after each run.

The frozen boundary is that doctor logic remains in `scripts/doctor.sh`; the app is a viewer and launcher, not a second health-check implementation.
