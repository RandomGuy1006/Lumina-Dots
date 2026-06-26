# Cleanup Manager

Cleanup Manager exposes safe maintenance cleanup through Lumina Core.

- App: `apps/cleanup-manager/lumina-cleanup-manager.py`
- CLI: `lumina-cleanup-manager`
- Dotfiles command: `dotfiles cleanup`

The app delegates cleanup to `scripts/maintenance/cleanup.sh` and reports results through the Universal Popup Framework.
