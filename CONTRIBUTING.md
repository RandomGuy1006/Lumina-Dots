# Contributing to Lumina

Thanks for helping make Lumina better. This project targets a real Arch Linux
Hyprland desktop, so please test changes in a clean Arch VM or a disposable
snapshot before proposing runtime changes.

## Local Development

1. Install a clean Arch VM with a normal user in `wheel`.
2. Clone the repo and run `bash install.sh --dry-run --host=generic`.
3. For LOQ-specific changes, test `bash install.sh --dry-run --host=loq-15irx9`.
4. Run focused tests before editing and the full suite before opening a PR.

## Installer Architecture

The installer is intentionally phased. Current scripts live under
`scripts/install/`; the long-term phase vocabulary is:

- `00-preflight`: Arch, sudo, network, disk, and repo checks.
- `01-base`: base system, pacman, keyring, snapshots, and AUR helper setup.
- `02-packages`: official and AUR package manifests.
- `03-dotfiles`: `lib/link.sh` symlink creation and generated-file seeding.
- `04-theme`: GTK, font, cursor, and initial Matugen theme.
- `05-hardware`: host-specific kernel, GPU, sleep, and power tuning.
- `06-services`: user services, portals, autologin, and runtime units.
- `07-doctor`: post-install health checks.
- `08-recovery`: fallback and rollback validation.
- `09-apps`: Lumina app smoke checks.
- `10-wallpapers`: wallpaper and theme pipeline validation.

## Test Suite

Run these before a PR:

```bash
bash tests/validate-repo.sh
bash tests/validate-docs.sh
python tests/validate-lumina-core.py
python tests/validate-lumina-architecture.py
bash tests/test-regressions.sh
bash tests/test-theme.sh
bash tests/test-services.sh
bash tests/test-links.sh
```

## Inviolable Architectural Rules

- `hyprctl keyword source <file>`; never reload the whole compositor config.
- UWSM owns all XDG environment variables; nothing else sets them.
- `matugen-bin` is the correct AUR package name.
- `ags-hyprpanel-git` is the correct AUR package name.
- Use `layerrule`, not deprecated wlogout window rules.
- `((ERRORS++))` under `set -e` requires `|| true`.
- Brightness temp files live in `$XDG_RUNTIME_DIR`, not `/tmp`.
- rEFInd edits target only the first boot entry.
- NVIDIA doctor checks use `lsmod`, not PCI listing.
- `loq-hyprlock-boot.service` requires `RemainAfterExit=yes`.
- Autologin units require `Type=idle`.
- `lib/link.sh` is the symlink engine.
- `hyprlock` uses native `$TIME`, not shell-spawning clock updates.

## Pull Requests

- Use branch names like `codex/fix-theme-pipeline` or `feature/keybind-overlay`.
- Use concise imperative commit messages, for example `Fix theme surface sync`.
- Describe what changed, how it was tested, and any user-visible impact.
- Keep unrelated refactors out of bug-fix PRs.

## Bugs

File bugs with the GitHub bug report template. Include install method, exact
steps, `journalctl --user -b -n 100`, and screenshots for visual issues.
