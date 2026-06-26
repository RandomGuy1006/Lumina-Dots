# Arch Install Validation

This document verifies Lumina Dots on a real Arch Linux + Hyprland target.

## Installer

- `bash install.sh --dry-run --host=generic`
- `bash install.sh --dry-run --host=loq-15irx9`
- `bash install.sh install --host=<target>`
- Re-run the same command after an intentional interruption to verify idempotence.

Pass: installer phases are rerunnable and do not require a display manager.

## Package Manifests

- Run package duplicate scan.
- Run package install phase.
- Confirm GTK/libadwaita/layer-shell/Python dependencies are installed once.
- Confirm optional AI backend packages remain optional.

Pass: manifests resolve and contain no duplicate pacman declarations.

## Symlinks

- Run `dotfiles validate symlinks`.
- Verify `~/.config/hypr` remains a real directory.
- Verify app binaries exist under `~/.local/bin`.

Pass: all managed links point to repo sources and runtime-generated files are not linked back into tracked config trees.

## Services

- Run `dotfiles validate services`.
- Inspect:
  - `loq-session.target`
  - `lumina-shell.service`
  - `lumina-welcome.service`
  - `loq-hyprpanel.service`
  - `loq-swww.service`
  - `xdg-desktop-portal-hyprland.service`

Pass: session and fallback services are active or have documented first-login deferral.

## First Login Experience

- Reboot after install.
- Confirm TTY login starts Hyprland through UWSM.
- Confirm Welcome appears once.
- Complete or skip Welcome.
- Reboot and confirm Welcome does not reappear.

Pass: first login succeeds, Welcome never blocks login, and completion state is respected.

## Runtime Diagnostic Commands

- `dotfiles doctor`
- `dotfiles doctor --full`
- `dotfiles validate`
- `dotfiles validate services`
- `dotfiles validate themes`
- `dotfiles validate hyprland`
- `dotfiles validate uwsm`
- `dotfiles validate apps`

Pass: diagnostics identify runtime issues without crashing the desktop.

