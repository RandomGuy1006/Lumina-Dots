# Runtime Risk Matrix

| Component | Risk | Why | Validation |
|---|---|---|---|
| Installer | High | Runs package, hardware, symlink, and service phases. | Fresh install, upgrade, dry-run, rerun tests. |
| Symlink engine | High | Broken links can prevent shell/session config from loading. | `dotfiles validate symlinks`, isolated regression test. |
| UWSM login | High | Session startup depends on TTY/UWSM path. | Reboot and login test, `dotfiles validate uwsm`. |
| Hyprland config | High | Bad config can break desktop startup or keybinds. | `hyprctl` checks, keybind scan, fallback launch. |
| Lumina Shell | High | Owns shell surfaces but must not break HyprPanel fallback. | Service status, OSD/popup tests, stop-service fallback test. |
| Theme pipeline | High | Writes many runtime surfaces. | `dotfiles validate themes`, invalid wallpaper test. |
| Snapshot/recovery | High | Recovery must stay safe and non-destructive by default. | Snapshot create/list, rollback docs review. |
| Doctor | High | Source of health truth for release decisions. | `dotfiles doctor --full`, porcelain parseability. |
| Control Center | Medium | Invokes runtime controls for audio, brightness, modes, and actions. | GUI, CLI status, quick action tests. |
| Mission Control | Medium | Depends on live Hyprland JSON state. | `lumina-mission-control --json`, keybind test. |
| Welcome | Medium | First-login app must not block session. | Reset/complete/reboot test. |
| Theme Studio | Medium | Applies themes through CLI pipeline. | List, preview, apply, invalid path test. |
| Lumina Hub | Medium | Aggregates app status and launches tools. | `lumina-hub --json`, action launch tests. |
| Snapshot Manager | Medium | Lists snapshots and creates backups. | Btrfs/Snapper host test. |
| Keybind Overlay | Low | Reads static binds and can launch commands. | `Super+/`, search, JSON export. |
| Activity History | Low | Bounded state file backed by popup events. | Trigger events, clear history. |
| AI Assistant | Low | Optional and pattern-mode first. | No-model/no-network test. |
| Website/docs | Low | Does not affect runtime but can mislead users. | Docs validation and stale-claim scan. |

