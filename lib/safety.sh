#!/usr/bin/env bash
# lib/safety.sh — Strict snapshot gates and boot snapshot integration.
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "${DOTFILES_DIR}/lib/log.sh"
source "${DOTFILES_DIR}/lib/common.sh"

safety::root_is_btrfs() {
  [[ "$(safety::root_fstype)" == "btrfs" ]]
}

safety::root_fstype() {
  if [[ -n "${LUMINA_ROOT_FSTYPE:-}" ]]; then
    printf '%s\n' "${LUMINA_ROOT_FSTYPE}"
  else
    findmnt -n -o FSTYPE / 2>/dev/null || true
  fi
}

safety::snapper_ready() {
  local config="${LUMINA_SNAPPER_CONFIG:-/etc/snapper/configs/root}"
  command -v snapper >/dev/null 2>&1 && [[ -f "${config}" ]]
}

safety::timeshift_ready() {
  command -v timeshift >/dev/null 2>&1
}

safety::require_snapshot() {
  local description="$1"

  case "$(safety::root_fstype)" in
    btrfs)
      if ! safety::snapper_ready; then
        if [[ "${LUMINA_ALLOW_UNSNAPPED_PACKAGES:-0}" == "1" ]]; then
          log::warn "Snapper is not ready; bypassing strict snapshot gate by explicit override"
          return 0
        fi
        log::fatal "Refusing system changes on Btrfs without a Snapper root configuration"
      fi
      log::section "Strict Btrfs safety snapshot"
      sudo snapper -c root create --description "${description}" ||
        log::fatal "Safety snapshot failed; aborting before system changes"
      ;;
    ext4)
      if ! safety::timeshift_ready; then
        if [[ "${LUMINA_ALLOW_UNSNAPPED_PACKAGES:-0}" == "1" ]]; then
          log::warn "Timeshift is unavailable; bypassing strict snapshot gate by explicit override"
          return 0
        fi
        log::fatal "Refusing system changes on ext4 without Timeshift"
      fi
      log::section "Strict ext4 safety snapshot"
      sudo timeshift --create --comments "${description}" --tags D --scripted ||
        log::fatal "Timeshift snapshot failed; aborting before system changes"
      ;;
    *)
      if [[ "${LUMINA_ALLOW_UNSNAPPED_PACKAGES:-0}" == "1" ]]; then
        log::warn "Unsupported root filesystem; proceeding by explicit unsnapped override"
      else
        log::fatal "Unsupported root filesystem for safety snapshots: $(safety::root_fstype)"
      fi
      ;;
  esac

  log::success "Safety snapshot created: ${description}"
}

safety::configure_grub_btrfs() {
  if ! safety::root_is_btrfs || ! safety::snapper_ready; then
    return 0
  fi

  case "$(detect_bootloader)" in
    grub)
      log::section "GRUB snapshot boot integration"
      sudo pacman -S --needed --noconfirm grub-btrfs inotify-tools

      if [[ -f /etc/default/grub-btrfs/config ]] &&
        ! sudo grep -q '^GRUB_BTRFS_SNAPSHOT_KERNEL_PARAMETERS=' /etc/default/grub-btrfs/config; then
        printf '\nGRUB_BTRFS_SNAPSHOT_KERNEL_PARAMETERS="rd.live.overlay.overlayfs=1"\n' |
          sudo tee -a /etc/default/grub-btrfs/config >/dev/null
      fi

      if systemctl list-unit-files grub-btrfsd.service --no-legend 2>/dev/null | grep -q grub-btrfsd.service; then
        sudo systemctl enable --now grub-btrfsd.service &&
          log::success "grub-btrfsd enabled for automatic snapshot menu refresh" ||
          log::warn "Could not enable grub-btrfsd.service"
      fi

      if command -v grub-mkconfig >/dev/null 2>&1 && [[ -d /boot/grub ]]; then
        sudo grub-mkconfig -o /boot/grub/grub.cfg >/dev/null &&
          log::success "GRUB menu regenerated with snapshot entries" ||
          log::warn "GRUB regeneration failed; run sudo grub-mkconfig -o /boot/grub/grub.cfg manually"
      fi
      ;;
    systemd-boot | refind)
      log::warn "Snapshot boot browsing is automatic only for GRUB. Offline rollback remains available through dotfiles rollback."
      ;;
    *)
      log::warn "Unknown bootloader; skipping automatic snapshot boot integration"
      ;;
  esac
}
