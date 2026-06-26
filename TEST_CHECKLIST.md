# Lumina Release Candidate Test Checklist

Use severity levels: Critical, High, Medium, Low.

| Feature | Test steps | Expected result | Failure result | Severity |
|---|---|---|---|---|
| Installer | Run dry-run for generic and LOQ, then run selected install. | Install completes and logs next steps. | Install exits early, leaves partial critical config, or cannot rerun. | Critical |
| Package manifests | Run package duplicate scan and install package phase. | No duplicates or missing required packages. | Duplicate packages, stale package names, or unresolved packages. | High |
| Symlinks | Run `dotfiles validate symlinks`. | Managed links verify. | Missing, broken, or wrong-target managed links. | Critical |
| Services | Run `dotfiles validate services`. | Required user services active or clearly deferred. | Lumina Shell, session target, portals, or HyprPanel fallback unavailable. | Critical |
| UWSM | Reboot and log in through TTY. | UWSM starts Hyprland without display manager. | Session does not start or app environment is wrong. | Critical |
| Hyprland | Run `dotfiles validate hyprland` and test window binds. | Monitors, clients, workspaces query correctly. | Hyprland config fails, keybinds conflict, or windows cannot be managed. | Critical |
| Theme pipeline | Apply wallpaper through CLI and Theme Studio. | Tokens and all runtime surfaces update. | Theme partially updates, generated files corrupt, or current theme breaks. | High |
| Control Center | Open `Super + C`, run audio/brightness/night-light actions. | Status renders and actions emit popups. | App crashes or unsafe command runs. | High |
| Hub | Open `Super + L`, run `lumina-hub --json`. | Mode, shell status, actions, and activity render. | Hub crashes or app launch buttons fail silently. | Medium |
| Mission Control | Open `Super + Tab`, run JSON mode. | Workspaces/windows show; bracket workspace binds still work. | Overview crashes or workspace cycling lost. | High |
| Welcome App | Reset, reboot, complete, reboot again. | Appears once and never blocks login. | Reappears after completion or blocks session. | High |
| Snapshot Manager | Run list/create paths on Btrfs host. | Lists snapshots and creates manual snapshot. | Unsafe rollback exposed or Snapper errors crash app. | Critical |
| Doctor Dashboard | Run GUI and JSON paths. | Parses Doctor output and summarizes health. | Parser fails, CLI Doctor breaks, or GUI hides critical failures. | High |
| Activity History | Trigger popups, open Activity History. | Recent events appear and clear works. | History grows unbounded or app crashes. | Medium |
| Theme Studio | List wallpapers, preview palette, apply image. | Uses `dotfiles theme`; invalid paths fail safely. | Writes generated surfaces directly or breaks active theme. | High |
| AI Assistant | Run pattern queries with no network/model. | Pattern mode answers and suggests safe actions. | Requires model/API or blocks shell/recovery. | Medium |

