# Phase 4.5 - Release Candidate Test Plan

Goal: validate Lumina Dots on a real Arch Linux + Hyprland installation and identify runtime bugs before Phase 5 work is treated as releasable.

## Test Environment

- Fresh Arch install or equivalent clean test host.
- Hyprland session launched through TTY + UWSM.
- Btrfs root with Snapper where recovery tests are run.
- Network available for package install, then offline pass after install.
- Test user has sudo rights.

## Fresh Install Validation

1. Boot clean Arch environment.
2. Clone or copy Lumina Dots.
3. Run `bash install.sh --dry-run --host=generic`.
4. Run `bash install.sh --dry-run --host=loq-15irx9`.
5. Run full install for the selected host.
6. Reboot and confirm TTY/UWSM launches Hyprland.
7. Run `dotfiles doctor --full` and `dotfiles validate`.

Expected result: install completes, first login reaches Hyprland, Lumina Shell and HyprPanel fallback are available, and runtime validation has no critical failures.

## Upgrade Validation

1. Start from a previous Lumina install.
2. Create a snapshot: `dotfiles backup "pre-rc-upgrade"`.
3. Run `bash install.sh update`.
4. Reboot.
5. Run `dotfiles validate apps`, `dotfiles validate services`, and `dotfiles doctor --full`.

Expected result: existing user config survives, new Lumina app entry points link correctly, services remain enabled, and no package conflicts appear.

## Recovery Validation

1. Run `dotfiles backup "rc-validation"`.
2. Run `dotfiles snapshot list` or `lumina-snapshot-manager list`.
3. Open Snapshot Manager and verify snapshots are visible.
4. Review `docs/recovery.md` and `dotfiles rollback list`.
5. Do not perform destructive rollback outside a planned recovery test.

Expected result: snapshots are discoverable, online root rollback is not exposed as a casual GUI action, and recovery docs match commands.

## Theme Validation

1. Place images in `~/Pictures/Wallpapers`.
2. Run `dotfiles theme ~/Pictures/Wallpapers/<image>`.
3. Open Theme Studio and apply a second image.
4. Run `dotfiles validate themes`.
5. Confirm Hyprland, Hyprlock, Walker, Ghostty, HyprPanel, Wlogout, GTK, Yazi, Starship, and Btop outputs update.

Expected result: token file updates, surfaces sync, and current theme remains intact if an invalid image is selected.

## Service Validation

1. Run `systemctl --user status loq-session.target --no-pager`.
2. Run `systemctl --user status lumina-shell.service --no-pager`.
3. Run `systemctl --user status lumina-welcome.service --no-pager`.
4. Run `dotfiles validate services`.

Expected result: required user units are active or clearly explain why they are unavailable before first graphical login.

## UWSM Validation

1. Verify `.zprofile` contains UWSM launch.
2. Run `uwsm check may-start` if supported by installed UWSM.
3. Launch apps through keybinds using `uwsm app --`.
4. Run `dotfiles validate uwsm`.

Expected result: session starts from TTY, app launch environment is correct, and no display manager is required.

## Hyprland Validation

1. Run `hyprctl monitors`.
2. Run `hyprctl clients -j`.
3. Run `hyprctl workspaces -j`.
4. Run `dotfiles validate hyprland`.
5. Test keybinds from `docs/keybindings.md`.

Expected result: config loads, keybinds work, Mission Control can read workspaces/windows, and fallback binds remain available.

## App Validation

Run each app from CLI and keybind where applicable:

- Control Center: `Super + C`, `lumina-control-center status`
- Hub: `Super + L`, `lumina-hub --json`
- Mission Control: `Super + Tab`, `lumina-mission-control --json`
- Welcome: `lumina-welcome --status`, `lumina-welcome --force`
- Snapshot Manager: `Super + Shift + B`, `lumina-snapshot-manager list`
- Doctor Dashboard: `Super + D`, `lumina-doctor-dashboard --json`

Expected result: every app opens or falls back to JSON/text output without breaking the session.

## Diagnostic Commands

- `dotfiles doctor`
- `dotfiles doctor --full`
- `dotfiles doctor --porcelain`
- `dotfiles validate`
- `dotfiles validate services`
- `dotfiles validate themes`
- `dotfiles validate hyprland`
- `dotfiles validate uwsm`
- `dotfiles validate apps`
- `dotfiles shell status`
- `dotfiles control status`
- `dotfiles hub --json`
- `dotfiles mission-control --json`
