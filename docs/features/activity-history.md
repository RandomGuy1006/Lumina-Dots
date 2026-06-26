# Lumina Activity History

Activity History is the Phase 3 audit trail for Lumina Shell events.

- App: `apps/activity-history/lumina-activity-history.py`
- CLI: `lumina-activity-history`
- Dotfiles command: `dotfiles activity`
- State file: `activity/history.json` under `LUMINA_STATE_HOME`

The Universal Popup Framework appends popup events to the bounded history log. Future apps can read the same state through Lumina Core state APIs and should append user-facing events through the popup framework where possible.

The frozen boundary is that activity storage stays in Lumina Core state paths; apps must not invent independent history files.
