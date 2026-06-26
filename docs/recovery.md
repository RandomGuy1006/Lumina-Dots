# Recovery guide

## Quick recovery commands

```bash
dotfiles doctor                    # Full system health check
lumina-doctor                      # Same thing, from ~/.local/bin
hypr-recover                       # Launch fallback Hyprland from TTY
```

## Fastest recovery path

If the desktop breaks after an update:

1. Switch to a TTY with `Ctrl` + `Alt` + `F2`
2. Log in
3. Run:

```bash
dotfiles doctor
hypr-recover
```

The recovery script launches Hyprland with the fallback config instead of modifying your tracked main config.

## Full root rollback

The active filesystem selects the snapshot backend. `dotfiles backup <description>` creates a Snapper snapshot on Btrfs or a Timeshift snapshot on ext4 and writes a recovery manifest under `~/.local/state/loqdots/backups/`.

List snapshots on either supported filesystem:

```bash
dotfiles rollback list
```

For ext4, restore through Timeshift from a rescue environment and verify the selected snapshot before confirmation. Lumina does not hide Timeshift restoration behind a desktop control.

For Btrfs, use the offline subvolume flow below.

List snapshots:

```bash
sudo snapper -c root list
```

Prepare rollback:

```bash
# from an Arch ISO or another rescue environment
git clone "https://github.com/RandomGuy1006/lumina-dots" /tmp/lumina-dots
cd /tmp/lumina-dots
bash install.sh rollback 123 /dev/nvme0n1p2
# Non-interactive rescue automation only after independently verifying both values:
bash install.sh rollback --yes 123 /dev/nvme0n1p2
sudo reboot
```

This uses an offline subvolume restore for the repo's `@` / `@snapshots` layout. It does not rely on `snapper rollback`, which only works cleanly when the system boots from the filesystem's default subvolume instead of an explicit `subvol=@` root.

The restore validates the block device, refuses the active root, preserves the previous `@`, and records a transaction under `~/.local/state/lumina/recovery/`.

## If the graphical session never starts

- Boot the `linux-lts` entry from rEFInd, systemd-boot, or your configured bootloader.
- Log in on tty1 or tty2.
- Check `journalctl -b -p err`.
- Re-run targeted recovery commands:
  - `dotfiles install dotfiles-only` — re-apply all config symlinks
  - `dotfiles theme "$(cat ~/Pictures/Wallpapers/.current)"` — regenerate Matugen colors from current wallpaper
  - `dotfiles doctor` — verify all system health checks

## If sleep or resume regresses

- Verify the LOQ drop-ins still exist:
  - `/etc/systemd/sleep.conf.d/60-loqdots.conf`
  - `/etc/systemd/logind.conf.d/60-loqdots.conf`
- Verify kernel parameters:
  - `mem_sleep_default=deep`
  - `i915.enable_psr=0`
  - `ibt=off`
- Boot `linux-lts` and compare behavior before changing anything else.

## If HyprPanel crashes or disappears

```bash
# From a terminal or TTY
pkill -x hyprpanel 2>/dev/null
while pgrep -x hyprpanel >/dev/null; do sleep 0.1; done
hyprpanel &>/dev/null & disown
```

Or use the `hpanel` alias from any terminal, or press `Super + Shift + R` to reload.

## If colors look wrong or empty

```bash
# Re-run the theme pipeline
dotfiles theme "$(cat ~/Pictures/Wallpapers/.current)"

# If matugen itself is broken, check the version:
matugen --version   # Must be >= 0.10.0

# If too old, update via AUR:
paru -S matugen-bin
```
