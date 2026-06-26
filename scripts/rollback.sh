#!/usr/bin/env bash
set -euo pipefail

ROOT="${LOQDOTS_ROOT:-${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}}"
DOTFILES_DIR="${DOTFILES_DIR:-$ROOT}"
LOQDOTS_ROOT="${LOQDOTS_ROOT:-$DOTFILES_DIR}"
export DOTFILES_DIR LOQDOTS_ROOT
source "$ROOT/lib/common.sh"

ASSUME_YES=false
if [[ "${1:-}" == "--yes" ]]; then
  ASSUME_YES=true
  shift
fi
action="${1:-list}"

usage() {
  cat <<'EOF'
Usage:
  ./install.sh rollback list
  ./install.sh rollback [--yes] last <btrfs-device>
  ./install.sh rollback [--yes] <snapshot-id> <btrfs-device>

Notes:
  - With this repo's @ / @snapshots layout, root restore must be run from a live ISO
    or another boot environment, not from the currently mounted target root.
  - Example device: /dev/nvme0n1p2
EOF
}

canonical_device() {
  local device="$1"
  readlink -f "$device" 2>/dev/null || printf '%s\n' "$device"
}

require_device_arg() {
  local device="${1:-}"
  [[ -n "$device" ]] || {
    fail "A Btrfs root device is required for restore operations."
    usage
    exit 1
  }
}

ensure_offline_restore_target() {
  local device="$1"
  local current_root

  current_root="$(findmnt -n -o SOURCE / 2>/dev/null || true)"
  if [[ -n "$current_root" ]] && [[ "$(canonical_device "$current_root")" == "$(canonical_device "$device")" ]]; then
    fail "Refusing to replace the active root subvolume on a running system."
    note "Boot an Arch ISO or another environment, then rerun:"
    note "  ./install.sh rollback <snapshot-id> $device"
    exit 1
  fi
}

validate_btrfs_device() {
  local device="$1"
  [[ -b "${device}" ]] || {
    fail "Restore target is not a block device: ${device}"
    exit 1
  }
  if command -v blkid >/dev/null 2>&1 && [[ "$(sudo blkid -s TYPE -o value "${device}" 2>/dev/null || true)" != "btrfs" ]]; then
    fail "Restore target is not a Btrfs filesystem: ${device}"
    exit 1
  fi
}

confirm_restore() {
  local snapshot_id="$1"
  local device="$2"
  if [[ "${ASSUME_YES}" == "true" || "${LUMINA_ROLLBACK_CONFIRM:-0}" == "1" ]]; then
    return 0
  fi
  [[ -t 0 ]] || {
    fail "Rollback confirmation requires a terminal. Re-run with --yes after verifying the target."
    exit 1
  }
  printf 'Replace @ on %s with snapshot %s? Type the snapshot id to continue: ' "${device}" "${snapshot_id}"
  read -r confirmation
  [[ "${confirmation}" == "${snapshot_id}" ]] || {
    fail "Rollback cancelled"
    exit 1
  }
}

find_last_snapshot_on_device() {
  local device="$1"
  local mount_dir snapshot_id

  require_device_arg "$device"
  ensure_offline_restore_target "$device"
  validate_btrfs_device "$device"

  mount_dir="$(mktemp -d)"
  trap 'sudo umount "$mount_dir" >/dev/null 2>&1 || true; rmdir "$mount_dir" >/dev/null 2>&1 || true' RETURN
  sudo mount -o subvolid=5 "$device" "$mount_dir"

  snapshot_id="$(find "$mount_dir/@snapshots" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | grep -E '^[0-9]+$' | sort -n | tail -n1 || true)"
  [[ -n "$snapshot_id" ]] || {
    fail "No snapshots were found under @snapshots on $device"
    exit 1
  }

  printf '%s\n' "$snapshot_id"
}

restore_snapshot() {
  local snapshot_id="$1"
  local device="$2"
  local mount_dir snapshot_path backup_name restore_name transaction_log

  require_device_arg "$device"
  ensure_offline_restore_target "$device"
  validate_btrfs_device "$device"
  confirm_restore "$snapshot_id" "$device"

  mount_dir="$(mktemp -d)"
  trap 'sudo umount "$mount_dir" >/dev/null 2>&1 || true; rmdir "$mount_dir" >/dev/null 2>&1 || true' RETURN

  sudo mount -o subvolid=5 "$device" "$mount_dir"

  snapshot_path="$mount_dir/@snapshots/$snapshot_id/snapshot"
  [[ -d "$snapshot_path" ]] || {
    fail "Snapshot $snapshot_id not found at $snapshot_path"
    exit 1
  }
  [[ -d "$mount_dir/@" ]] || {
    fail "Expected root subvolume '@' was not found on $device"
    exit 1
  }

  backup_name="@.pre-rollback-$(date +%Y%m%d-%H%M%S)"
  restore_name="@.restore-$(date +%Y%m%d-%H%M%S)"
  transaction_log="${XDG_STATE_HOME:-${HOME}/.local/state}/lumina/recovery/rollback-$(date +%Y%m%d-%H%M%S).log"
  mkdir -p "$(dirname "${transaction_log}")"
  {
    printf 'schema_version=1\n'
    printf 'snapshot_id=%s\n' "${snapshot_id}"
    printf 'device=%s\n' "$(canonical_device "${device}")"
    printf 'previous_root=%s\n' "${backup_name}"
    printf 'started_at=%s\n' "$(date --iso-8601=seconds)"
  } >"${transaction_log}"
  sudo btrfs subvolume snapshot "$snapshot_path" "$mount_dir/$restore_name" >/dev/null
  sudo mv "$mount_dir/@" "$mount_dir/$backup_name"
  if ! sudo mv "$mount_dir/$restore_name" "$mount_dir/@"; then
    sudo mv "$mount_dir/$backup_name" "$mount_dir/@" || true
    fail "Restore activation failed; attempted to put the original @ back"
    exit 1
  fi
  printf 'completed_at=%s\nstatus=complete\n' "$(date --iso-8601=seconds)" >>"${transaction_log}"

  pass "Restored @ from snapshot $snapshot_id on $device"
  note "Previous root saved as $backup_name"
  note "Recovery transaction: $transaction_log"
  note "Reboot after unmounting or exiting the live environment."
}

case "$action" in
  list)
    case "$(findmnt -n -o FSTYPE / 2>/dev/null || true)" in
      btrfs)
        command -v snapper >/dev/null 2>&1 || { fail "Snapper is not installed"; exit 1; }
        [[ -f /etc/snapper/configs/root ]] || { fail "Snapper root configuration is missing"; exit 1; }
        sudo snapper -c root list
        ;;
      ext4)
        command -v timeshift >/dev/null 2>&1 || { fail "Timeshift is not installed"; exit 1; }
        sudo timeshift --list
        ;;
      *)
        fail "Unsupported root filesystem for snapshot listing"
        exit 1
        ;;
    esac
    ;;
  last)
    snapshot_id="$(find_last_snapshot_on_device "${2:-}")"
    restore_snapshot "$snapshot_id" "${2:-}"
    ;;
  *)
    restore_snapshot "$action" "${2:-}"
    ;;
esac
