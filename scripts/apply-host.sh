#!/usr/bin/env bash
set -euo pipefail

ROOT="${LOQDOTS_ROOT:-${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}}"
DOTFILES_DIR="${DOTFILES_DIR:-$ROOT}"
LOQDOTS_ROOT="${LOQDOTS_ROOT:-$DOTFILES_DIR}"
export DOTFILES_DIR LOQDOTS_ROOT
source "$ROOT/lib/common.sh"

load_host_profile

host_file() {
  local name="$1"
  local primary="$ROOT/hosts/$HOST/$name"

  if [[ -f "$primary" ]]; then
    printf '%s\n' "$primary"
  else
    return 1
  fi
}

setup_swap_if_missing() {
  if swapon --noheadings --show=NAME | grep -q .; then
    note "Swap already active"
    return 0
  fi

  if [[ "$(findmnt -n -o FSTYPE /)" != "btrfs" ]]; then
    warn "Root is not Btrfs. Skipping auto swapfile creation."
    return 0
  fi

  sudo btrfs subvolume create /.swapvol >/dev/null 2>&1 || true
  if [[ ! -f /.swapvol/swapfile ]]; then
    sudo btrfs filesystem mkswapfile --size "$SWAPFILE_SIZE" /.swapvol/swapfile >/dev/null
    pass "Created Btrfs swapfile at /.swapvol/swapfile"
  fi

  ensure_line "/.swapvol/swapfile none swap defaults 0 0" /etc/fstab
  sudo swapon /.swapvol/swapfile >/dev/null 2>&1 || true
}

configure_resume() {
  local swap_name swap_type resume_uuid resume_offset
  swap_name="$(swapon --noheadings --raw --output NAME | head -n1 || true)"
  swap_type="$(swapon --noheadings --raw --output TYPE | head -n1 || true)"

  [[ -n "$swap_name" ]] || return 0

  if [[ "$swap_type" == "partition" ]]; then
    resume_uuid="$(blkid -s UUID -o value "$swap_name")"
    ensure_kernel_param "resume=UUID=$resume_uuid"
    note "Configured resume=UUID for swap partition"
    return 0
  fi

  if [[ "$swap_type" == "file" ]]; then
    resume_uuid="$(findmnt -n -o UUID /)"
    resume_offset="$(sudo btrfs inspect-internal map-swapfile -r "$swap_name")"
    ensure_kernel_param "resume=UUID=$resume_uuid"
    ensure_kernel_param "resume_offset=$resume_offset"
    note "Configured resume UUID and offset for Btrfs swapfile"
  fi
}

ensure_resume_hook() {
  local hooks_line hooks tmp_file
  local raw_hooks=()
  local normalized_hooks=()
  local hook inserted=0 has_fsck=0

  hooks_line="$(grep '^HOOKS=(' /etc/mkinitcpio.conf | head -n1 || true)"
  [[ -n "$hooks_line" ]] || {
    warn "Could not find a HOOKS line in /etc/mkinitcpio.conf"
    return 0
  }

  hooks="${hooks_line#HOOKS=(}"
  hooks="${hooks%)}"
  read -r -a raw_hooks <<<"$hooks"

  for hook in "${raw_hooks[@]}"; do
    [[ "$hook" == "resume" ]] && continue
    if [[ "$hook" == "fsck" ]]; then
      has_fsck=1
      continue
    fi
    normalized_hooks+=("$hook")
  done

  for i in "${!normalized_hooks[@]}"; do
    if [[ "${normalized_hooks[$i]}" == "filesystems" ]]; then
      normalized_hooks=("${normalized_hooks[@]:0:i+1}" "resume" "${normalized_hooks[@]:i+1}")
      if ((has_fsck)); then
        normalized_hooks=("${normalized_hooks[@]:0:i+2}" "fsck" "${normalized_hooks[@]:i+2}")
      fi
      inserted=1
      break
    fi
  done

  if ((!inserted)); then
    normalized_hooks+=("resume")
    ((has_fsck)) && normalized_hooks+=("fsck")
  fi

  hooks_line="HOOKS=(${normalized_hooks[*]})"
  if ! grep -qxF "$hooks_line" /etc/mkinitcpio.conf; then
    tmp_file="$(mktemp)"
    chmod 600 "$tmp_file"
    awk -v new_line="$hooks_line" '
            BEGIN { replaced = 0 }
            /^HOOKS=\(/ && !replaced {
                print new_line
                replaced = 1
                next
            }
            { print }
        ' /etc/mkinitcpio.conf >"$tmp_file"
    sudo install -m 0644 "$tmp_file" /etc/mkinitcpio.conf
    rm -f "$tmp_file"
    pass "Normalized resume hook in mkinitcpio.conf"
    sudo mkinitcpio -P >/dev/null
  else
    pass "mkinitcpio resume hook already in the correct position"
  fi
}

install_host_dropins() {
  local file

  if file="$(host_file modprobe-i915.conf)"; then
    install_root_file "$file" "/etc/modprobe.d/loqdots-i915.conf"
  fi

  if file="$(host_file sleep.conf)"; then
    install_root_file "$file" "/etc/systemd/sleep.conf.d/60-loqdots.conf"
  fi

  if file="$(host_file logind.conf)"; then
    install_root_file "$file" "/etc/systemd/logind.conf.d/60-loqdots.conf"
  fi
}

step "Applying host tuning for $HOST"
setup_swap_if_missing
root_is_btrfs=false
if [[ "$(findmnt -n -o FSTYPE /)" == "btrfs" ]]; then
  root_is_btrfs=true
fi

if kernel_params_file="$(host_file kernel-params.conf)"; then
  while IFS= read -r param; do
    ensure_kernel_param "$param"
  done < <(read_manifest "$kernel_params_file")
else
  warn "No kernel parameter manifest found for $HOST"
fi

ensure_resume_hook
configure_resume
install_host_dropins || warn "Some host drop-ins are missing for $HOST"

maybe_disable_system_unit power-profiles-daemon.service
for unit in \
  NetworkManager.service \
  bluetooth.service \
  auto-cpufreq.service \
  thermald.service \
  fstrim.timer; do
  maybe_enable_system_unit "$unit"
done

if [[ "${root_is_btrfs}" == "true" ]]; then
  for unit in \
    snapper-timeline.timer \
    snapper-cleanup.timer \
    btrfs-scrub@-.timer; do
    maybe_enable_system_unit "$unit"
  done
else
  warn "Root is not Btrfs. Skipping Snapper and Btrfs scrub timers."
fi

if unit_exists upower.service; then
  maybe_enable_system_unit upower.service
fi

sudo loginctl enable-linger "$USER" >/dev/null
pass "Enabled linger for $USER"

for user_unit in \
  loq-hyprpanel.service \
  lumina-shell.service \
  lumina-welcome.service \
  loq-hypridle.service \
  loq-hyprswitch.service \
  loq-swww.service \
  loq-cliphist-text.service \
  loq-cliphist-image.service; do
  maybe_enable_user_unit "$user_unit"
done

# Envycontrol integration (Rule 17)
reboot_required=false
if command -v envycontrol &>/dev/null; then
  desired_mode="${NVIDIA_MODE:-integrated}"
  current_mode="$(envycontrol --query 2>/dev/null | awk 'NF { print tolower($NF) }' | tail -n 1)"

  if [[ "$current_mode" != "$desired_mode" ]]; then
    step "Setting NVIDIA mode to $desired_mode..."
    if sudo envycontrol -s "$desired_mode"; then
      pass "GPU mode set to $desired_mode"
      reboot_required=true
    else
      fail "Failed to set GPU mode"
    fi
  fi
fi

if [[ "$reboot_required" == "true" ]]; then
  warn "Reboot required before continuing with the rest of the install"
  exit 20
fi

pass "Host tuning applied"
