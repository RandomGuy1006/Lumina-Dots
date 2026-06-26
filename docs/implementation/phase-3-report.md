# Phase 3 Report

Phase 3 added health, recovery, and audit surfaces on top of the Lumina Core foundation.

## Implemented

- `apps/doctor-dashboard/lumina-doctor-dashboard.py` parses `scripts/doctor.sh --porcelain` style output into graphical health items.
- `apps/snapshot-manager/lumina-snapshot-manager.py` reads Snapper snapshot lists and exposes recovery state for Btrfs/Snapper systems.
- `apps/activity-history/lumina-activity-history.py` reads and clears Lumina event history stored through the shared state layer.
- The popup/event system records useful shell events so user-facing surfaces and diagnostics share one trail.

## Current constraints

- Snapshot restore remains a guided Btrfs subvolume swap flow through `dotfiles rollback`, not a raw `snapper rollback` command.
- Doctor and dashboard checks can run off-Hyprland, but runtime checks for services, monitors, and portals are meaningful only on an installed Arch + Hyprland session.

## Verification

Validated by `tests/test-lumina-phase3.py`, `scripts/doctor.sh`, and the repository-level architecture checks.
