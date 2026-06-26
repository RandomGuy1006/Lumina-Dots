# Installation guide: Archinstall path

This is the safer and faster path if you want Archinstall to handle the base system while the repo handles the desktop and post-install policy.

## 1. BIOS preparation

- Update to the newest stable BIOS available for the LOQ 15IRX9.
- Disable Secure Boot unless you plan to manage signed third-party kernel modules yourself.
- Prefer Hybrid or Integrated graphics mode if your firmware exposes it.
- Keep virtualization enabled if you use Android Studio, VMs, or containers.

## 2. Partition layout

Recommended GPT layout for your Windows dual-boot LOQ:

1. Existing Windows EFI partition - `FAT32` - mount at `/boot`, do not format
2. Arch root - `80-100 GiB` - `Btrfs`
3. Arch home - `80-150 GiB` - `Btrfs`
4. Swap - `18-20 GiB` - Linux swap, large enough for hibernate

Recommended Btrfs subvolumes:

- `@`
- `@home`
- `@snapshots`
- `@var_log`
- `@var_cache_pacman`
- `@swapvol`

Mount strategy:

- `/` -> `@`
- `/home` -> `@home`
- `/.snapshots` -> `@snapshots`
- `/var/log` -> `@var_log`
- `/var/cache/pacman/pkg` -> `@var_cache_pacman`

## 3. Archinstall choices

- Profile: minimal
- Bootloader: rEFInd for Windows dual boot, or systemd-boot for Arch-only installs
- Kernels: `linux`, `linux-lts`
- Network: NetworkManager
- Audio: PipeWire
- Filesystem: Btrfs
- Swap: enabled if you created a swap partition; disabled if you want the repo to create a Btrfs swapfile

Swap rule:

- With a swap partition, the hardware step injects `resume=UUID=...`.
- Without active swap, the hardware step creates `/.swapvol/swapfile` and injects `resume=UUID=... resume_offset=...`.

Reference file:

- [`archinstall/loq-archinstall.example.json`](../archinstall/loq-archinstall.example.json)

## 4. First boot after Archinstall

Log into the new system on a text console, then run:

```bash
sudo systemctl enable --now NetworkManager
REPO_URL="https://github.com/RandomGuy1006/lumina-dots"
git clone "$REPO_URL" "$HOME/lumina-dots"
cd "$HOME/lumina-dots"
bash install.sh install --host=loq-15irx9
```

## 5. What the repo configures

- installs official and AUR packages
- symlinks configs into `$HOME` (via custom link engine)
- disables `greetd` if present
- enables tty1 autologin
- configures deep sleep and resume parameters
- creates a Btrfs swapfile if one is missing
- enables Snapper, snap-pac, `thermald`, `auto-cpufreq`, and scrub timers
- generates HyprPanel and Matugen outputs

## 6. First boot into Hyprland

- Reboot after install.
- Let tty1 autologin start UWSM.
- Hyprlock should appear immediately.
- Unlock and run:

```bash
bash ~/lumina-dots/install.sh doctor --host=loq-15irx9
```

## 7. Rollback steps

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
sudo reboot
```
