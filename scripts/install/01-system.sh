#!/usr/bin/env bash
# scripts/install/01-system.sh — System configuration step
# Sets up: locale, timezone, hostname, sudo, paru, zram, Snapper
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "${DOTFILES_DIR}/lib/log.sh"
source "${DOTFILES_DIR}/lib/aur.sh"
source "${DOTFILES_DIR}/lib/safety.sh"

log::header "Step 1: System Configuration"

root_is_btrfs() {
  [[ "$(findmnt -n -o FSTYPE / 2>/dev/null || true)" == "btrfs" ]]
}

configure_snapper_root() {
  command -v snapper >/dev/null 2>&1 || return 0
  root_is_btrfs || {
    log::warn "Root is not Btrfs — skipping Snapper setup"
    return 0
  }

  if [[ ! -f /etc/snapper/configs/root ]]; then
    sudo snapper -c root create-config / &&
      log::success "Snapper root config created" ||
      log::warn "Snapper config creation failed (may already exist)"
  else
    log::dim "Snapper root config already exists"
  fi

  sudo snapper -c root set-config \
    TIMELINE_CREATE=yes \
    TIMELINE_CLEANUP=yes \
    TIMELINE_LIMIT_HOURLY=5 \
    TIMELINE_LIMIT_DAILY=7 \
    TIMELINE_LIMIT_WEEKLY=4 \
    TIMELINE_LIMIT_MONTHLY=2 \
    TIMELINE_LIMIT_YEARLY=1 \
    2>/dev/null || log::warn "Snapper config update failed — set manually"

  sudo systemctl enable --now snapper-timeline.timer snapper-cleanup.timer &&
    log::success "Snapper timers enabled" ||
    log::warn "Snapper timer enablement failed"
}

create_safety_snapshot() {
  local description="$1"

  if command -v snapper >/dev/null 2>&1 && [[ -f /etc/snapper/configs/root ]]; then
    safety::require_snapshot "${description}"
  elif root_is_btrfs; then
    log::fatal "Snapper is not ready; refusing to continue without safety snapshot: ${description}"
  else
    log::warn "Snapper is not ready yet; cannot create safety snapshot: ${description}"
  fi
}

# ─── Locale ───────────────────────────────────────────────────────────────────
log::section "Locale setup"
if ! grep -q "^en_US.UTF-8 UTF-8" /etc/locale.gen 2>/dev/null; then
  sudo sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
  sudo locale-gen
  log::success "Locale generated"
else
  log::dim "Locale already configured"
fi

if [[ ! -f /etc/locale.conf ]] || ! grep -q "LANG=en_US.UTF-8" /etc/locale.conf; then
  echo "LANG=en_US.UTF-8" | sudo tee /etc/locale.conf >/dev/null
  log::success "Locale configured"
fi

# ─── Timezone ─────────────────────────────────────────────────────────────────
log::section "Timezone"
DESIRED_TZ="${LUMINA_TIMEZONE:-Asia/Kolkata}"
current_tz="$(timedatectl show --property=Timezone --value 2>/dev/null || echo "unknown")"
if [[ "${current_tz}" != "${DESIRED_TZ}" ]]; then
  sudo timedatectl set-timezone "${DESIRED_TZ}"
  log::success "Timezone set to ${DESIRED_TZ}"
else
  log::dim "Timezone already ${DESIRED_TZ}"
fi
sudo timedatectl set-ntp true
log::success "NTP enabled"

# ─── Sudoers ──────────────────────────────────────────────────────────────────
log::section "Sudo configuration"
if ! sudo grep -q "^%wheel ALL=(ALL:ALL) ALL" /etc/sudoers 2>/dev/null; then
  sudo sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
  log::success "wheel group sudoers configured"
else
  log::dim "wheel group already in sudoers"
fi

# ─── Pacman tweaks ────────────────────────────────────────────────────────────
log::section "Pacman configuration"
# Enable Color and ParallelDownloads in /etc/pacman.conf
sudo sed -i 's/^#Color/Color/' /etc/pacman.conf
sudo sed -i 's/^#ParallelDownloads.*/ParallelDownloads = 10/' /etc/pacman.conf
# Enable multilib for 32-bit NVIDIA libs
if grep -q "^\[multilib\]" /etc/pacman.conf; then
  log::dim "multilib already enabled"
else
  # Uncomment the existing [multilib] section in pacman.conf
  sudo sed -i '/^#\[multilib\]/,/^#Include = \/etc\/pacman.d\/mirrorlist/ s/^#//' /etc/pacman.conf
  log::success "multilib enabled"
fi
PINNED_DESKTOP_PKGS=(ags-hyprpanel-git hyprswitch walker-bin matugen-bin)
existing_ignore="$(
  grep -E "^[#[:space:]]*IgnorePkg[[:space:]]*=" /etc/pacman.conf 2>/dev/null |
    sed -E "s/^[#[:space:]]*IgnorePkg[[:space:]]*=[[:space:]]*//" |
    tr ' ' '\n' |
    grep -Ev '^[[:space:]]*$' ||
    true
)"
combined_ignore="$(
  {
    printf '%s\n' "${existing_ignore}"
    printf '%s\n' "${PINNED_DESKTOP_PKGS[@]}"
  } | awk 'NF && !seen[$0]++'
)"
sudo sed -i '/^[#[:space:]]*IgnorePkg[[:space:]]*=/d' /etc/pacman.conf
printf '\nIgnorePkg = %s\n' "${combined_ignore//$'\n'/ }" | sudo tee -a /etc/pacman.conf >/dev/null
log::success "Pinned volatile desktop packages for intentional updates"
if root_is_btrfs && safety::snapper_ready; then
  create_safety_snapshot "lumina pre-system-bootstrap $(date +%Y-%m-%d)"
fi
sudo pacman -S --needed --noconfirm archlinux-keyring
if root_is_btrfs; then
  sudo pacman -S --needed --noconfirm btrfs-progs snapper snap-pac
  configure_snapper_root
  create_safety_snapshot "lumina pre-system-upgrade $(date +%Y-%m-%d)"
  safety::configure_grub_btrfs
else
  log::warn "Root is not Btrfs — automatic safety snapshots unavailable"
fi
sudo pacman -Syu --noconfirm
log::success "Pacman configured"

# ─── paru AUR helper ──────────────────────────────────────────────────────────
aur::ensure_paru

# ─── zram (compressed swap in RAM) ───────────────────────────────────────────
log::section "zram setup"
if ! pacman -Qi zram-generator &>/dev/null; then
  sudo pacman -S --needed --noconfirm zram-generator
fi

sudo tee /etc/systemd/zram-generator.conf >/dev/null <<'ZRAM_EOF'
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
swap-priority = 100
ZRAM_EOF

sudo systemctl daemon-reload
sudo systemctl start systemd-zram-setup@zram0.service 2>/dev/null || true
log::success "zram configured (50% of RAM, zstd compression)"

# ─── Snapper ─────────────────────────────────────────────────────────────────
log::section "Snapper Btrfs snapshot setup"
configure_snapper_root
safety::configure_grub_btrfs

# ─── XDG user directories ────────────────────────────────────────────────────
log::section "XDG user directories"
if command -v xdg-user-dirs-update &>/dev/null; then
  xdg-user-dirs-update
  log::success "XDG user directories configured"
fi

log::success "System configuration complete"
