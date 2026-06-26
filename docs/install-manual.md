# Installation guide: Manual path

Use this path if you want the base install to be fully explicit.

## 1. Boot the Arch ISO and prepare network

```bash
timedatectl set-ntp true
iwctl
```

## 2. Partition the disk

For a fresh Arch-only disk, this creates a new GPT and wipes the drive:

```bash
parted /dev/nvme0n1 --script \
  mklabel gpt \
  mkpart ESP fat32 1MiB 1025MiB \
  set 1 esp on \
  mkpart primary btrfs 1025MiB 100%
```

For your Windows dual-boot layout, create the Arch root/home/swap partitions from Windows first, then do not run the `parted mklabel gpt` command. Use the existing EFI partition as `/boot` without formatting it.

## 3. Create filesystems

```bash
# Arch-only example:
mkfs.fat -F32 /dev/nvme0n1p1
mkfs.btrfs -f /dev/nvme0n1p2
mount /dev/nvme0n1p2 /mnt

# Dual-boot example:
# mkfs.btrfs -f /dev/nvme0n1p5
# mkfs.btrfs -f /dev/nvme0n1p6
# mkswap /dev/nvme0n1p7
# mount /dev/nvme0n1p5 /mnt
```

## 4. Create Btrfs subvolumes

```bash
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@var_log
btrfs subvolume create /mnt/@var_cache_pacman
btrfs subvolume create /mnt/@swapvol
umount /mnt
```

## 5. Mount the final layout

```bash
mount -o noatime,compress=zstd:3,ssd,space_cache=v2,subvol=@ /dev/nvme0n1p2 /mnt
mkdir -p /mnt/{boot,home,.snapshots,var/log,var/cache/pacman/pkg}
mount -o noatime,compress=zstd:3,ssd,space_cache=v2,subvol=@home /dev/nvme0n1p2 /mnt/home
mount -o noatime,compress=zstd:3,ssd,space_cache=v2,subvol=@snapshots /dev/nvme0n1p2 /mnt/.snapshots
mount -o noatime,compress=zstd:3,ssd,space_cache=v2,subvol=@var_log /dev/nvme0n1p2 /mnt/var/log
mount -o noatime,compress=zstd:3,ssd,space_cache=v2,subvol=@var_cache_pacman /dev/nvme0n1p2 /mnt/var/cache/pacman/pkg
mount /dev/nvme0n1p1 /mnt/boot
```

## 6. Install the base system

```bash
pacstrap -K /mnt base linux linux-lts linux-firmware intel-ucode neovim git zsh networkmanager btrfs-progs snapper snap-pac sudo
genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt
```

## 7. Base system configuration

```bash
ln -sf /usr/share/zoneinfo/Asia/Kolkata /etc/localtime
hwclock --systohc
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf
echo 'KEYMAP=us' > /etc/vconsole.conf
echo 'loq' > /etc/hostname
```

Edit `/etc/hosts`:

```text
127.0.0.1 localhost
::1       localhost
127.0.1.1 loq.localdomain loq
```

Create your user:

```bash
passwd
useradd -m -G wheel -s /bin/zsh YOUR_USER
passwd YOUR_USER
EDITOR=nvim visudo
```

Uncomment:

```text
%wheel ALL=(ALL:ALL) ALL
```

## 8. Bootloader

```bash
bootctl install
```

Create `/boot/loader/loader.conf`:

```text
default arch.conf
timeout 3
editor no
```

Create `/boot/loader/entries/arch.conf`:

```text
title   Arch Linux
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux.img
options root=UUID=<ROOT_UUID> rootflags=subvol=@ rw quiet loglevel=3 rd.udev.log_level=3 vt.global_cursor_default=0 nowatchdog mem_sleep_default=deep i915.enable_psr=0 ibt=off
```

Create `/boot/loader/entries/arch-lts.conf` with `vmlinuz-linux-lts` and `initramfs-linux-lts.img`.

## 9. Enable base services

```bash
systemctl enable NetworkManager
```

Exit chroot, unmount, and reboot:

```bash
exit
umount -R /mnt
reboot
```

## 10. Post-install repo setup

After reboot, log in on tty and run:

```bash
REPO_URL="https://github.com/RandomGuy1006/lumina-dots"
git clone "$REPO_URL" "$HOME/lumina-dots"
cd "$HOME/lumina-dots"
bash install.sh install --host=loq-15irx9
```

## 11. Rollback steps

- list snapshots with `sudo snapper -c root list`
- boot an Arch ISO or another rescue environment
- run `git clone "https://github.com/RandomGuy1006/lumina-dots" /tmp/lumina-dots`
- run `/tmp/lumina-dots/install.sh rollback <snapshot-id> /dev/nvme0n1p2`
- reboot
