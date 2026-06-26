# Feature Verification Matrix

This matrix is the operational contract for feature pages. Individual pages provide usage detail; this file prevents dependency, failure, recovery, and verification expectations from drifting.

| Feature | Dependencies | Failure and fallback | Verification |
|---|---|---|---|
| activity-history | Lumina state | Invalid history reports a state error; clear remains available | Phase 3 tests |
| ai-assistant | Optional local AI provider | Never required for install, shell, recovery, or theming | Phase 5 tests |
| cleanup-manager | Cache and state paths | Preview before deletion; core session remains unaffected | Phase 6 tests |
| control-center | Lumina Core adapters | Missing subsystem is shown unavailable | Phase 2 tests |
| doctor-dashboard | `doctor --porcelain` | CLI doctor remains authoritative | Phase 3 tests |
| focus-mode | Hyprland clients | Toggle restores moved windows from saved state | Phase 6 and runtime tests |
| idle-inhibitor | systemd inhibitor support | Toggle off restores normal idle behavior | Phase 6 and runtime tests |
| keybind-overlay | Hyprland bind files | Missing files yield an empty searchable view | Phase 2 tests |
| lumina-hub | Lumina app entrypoints | Individual unavailable apps do not break the hub | Phase 4 tests |
| lumina-modes | Versioned state and popup path | Invalid state falls back to auto mode | Phase 2 tests |
| lumina-shell | GTK optional, HyprPanel fallback | State/log fallback preserves login and panel | Phase 2 and runtime tests |
| media-overlay | playerctl | Missing player reports unavailable | Phase 6 tests |
| mission-control | Hyprland queries | Empty state when compositor is unavailable | Phase 4 tests |
| pomodoro | Lumina state | Restart-safe state; stop returns idle | Phase 6 tests |
| presentation-mode | Hyprland and idle controls | Second toggle restores previous behavior | Phase 6 and runtime tests |
| random-wallpaper | Wallpaper directory and swww | Invalid images fail before theme publication | Theme and Phase 6 tests |
| scratch-notes | Configured editor | Missing editor reports failure without session impact | Phase 6 tests |
| scratchpad-terminal | Hyprland and terminal | Missing terminal does not mutate workspace state | Phase 6 tests |
| snapshot-manager | Snapper CLI | Manual backup/rollback scripts remain authoritative | Phase 3 and recovery tests |
| theme-studio | Matugen and visual tokens | Failed generation retains prior runtime theme | Phase 4 and visual tests |
| universal-popup-framework | State and notification fallback | Missing notification daemon degrades to logs/state | Phase 2 tests |
| welcome-app | GTK and first-run state | Can be skipped; never blocks session target | Phase 2 and service tests |
| workspace-templates | Hyprland dispatch | Partial launch reports failure and remains repeatable | Phase 6 tests |
| color-picker | grim/slurp picker stack | Missing tool reports unavailable | Phase 6 tests |

Production acceptance also requires the live checks in `docs/verification.md`.
