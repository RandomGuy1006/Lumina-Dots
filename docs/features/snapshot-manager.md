# Lumina Snapshot Manager

The Snapshot Manager is the Phase 3 recovery surface for Btrfs/Snapper systems.

- App: `apps/snapshot-manager/lumina-snapshot-manager.py`
- CLI: `lumina-snapshot-manager`
- Dotfiles command: `dotfiles snapshot`
- Keybind: `Super + Shift + B`

It lists `snapper -c root list` output and creates manual snapshots through `dotfiles backup`, preserving the existing recovery scripts as the authority for snapshot creation.

Rollback remains in the documented offline recovery flow. The MVP intentionally avoids in-session rollback controls.
