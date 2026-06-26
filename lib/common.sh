#!/usr/bin/env bash
set -euo pipefail

if [[ "${LOQDOTS_COMMON_SOURCED:-0}" == "1" ]]; then
  return 0
fi
export LOQDOTS_COMMON_SOURCED=1

ROOT="${LOQDOTS_ROOT:-${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}}"
DOTFILES_DIR="${DOTFILES_DIR:-$ROOT}"
LOQDOTS_ROOT="${LOQDOTS_ROOT:-$DOTFILES_DIR}"

common_detect_host() {
  local dmi_product
  dmi_product="$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo "unknown")"
  if [[ "$dmi_product" == *"LOQ"* || "$dmi_product" == *"15IRX9"* ]]; then
    printf '%s\n' "loq-15irx9"
  else
    printf '%s\n' "generic"
  fi
}

HOST="${LOQDOTS_HOST:-${HOST_PROFILE:-$(common_detect_host)}}"
case "$HOST" in
  loq | loq15irx9 | loq-15IRX9 | loq-15irx9 | lenovo-loq | lenovo-loq-15irx9)
    HOST="loq-15irx9"
    ;;
  "" | generic)
    HOST="generic"
    ;;
esac
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/loqdots"
BACKUP_DIR="$STATE_DIR/backups"
LOG_DIR="$ROOT/logs"
LOG_FILE="${LOQDOTS_LOG:-${LOG_FILE:-}}"
LUMINA_DRY_RUN="${LUMINA_DRY_RUN:-0}"
export ROOT DOTFILES_DIR LOQDOTS_ROOT LUMINA_DRY_RUN

ensure_log_file() {
  mkdir -p "$LOG_DIR" "$STATE_DIR" "$BACKUP_DIR"
  if [[ -z "$LOG_FILE" ]]; then
    LOG_FILE="$LOG_DIR/$(date +%Y-%m-%d_%H-%M-%S).log"
    export LOQDOTS_LOG="$LOG_FILE"
  fi
}

_log() {
  local level="$1"
  shift
  ensure_log_file
  printf '[%s] %-5s %s\n' "$(date +%H:%M:%S)" "$level" "$*" | tee -a "$LOG_FILE"
}

step() { _log STEP "$*"; }
note() { _log INFO "$*"; }
warn() { _log WARN "$*"; }
pass() { _log OK "$*"; }
fail() { _log FAIL "$*"; }

run_cmd() {
  if [[ "${LUMINA_DRY_RUN}" == "1" ]]; then
    note "[DRY RUN] Would run: $*"
  else
    "$@"
  fi
}

require_arch() {
  [[ -f /etc/arch-release ]] || {
    fail "This repo targets Arch Linux."
    exit 1
  }
}

require_not_root() {
  [[ "$EUID" -ne 0 ]] || {
    fail "Run this repo as your user, not as root."
    exit 1
  }
}

require_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || {
    fail "Missing required command: $cmd"
    exit 1
  }
}

ensure_sudo() {
  if sudo -n true 2>/dev/null; then
    return 0
  fi

  if [[ -t 0 ]]; then
    sudo -v
    return
  fi

  fail "sudo credentials required, but no interactive prompt is available."
  exit 1
}

load_host_profile() {
  local profile_sh="$ROOT/hosts/$HOST/profile.sh"
  local profile_env="$ROOT/hosts/$HOST/profile.env"

  if [[ -f "$profile_sh" ]]; then
    # shellcheck disable=SC1090
    source "$profile_sh"
  elif [[ -f "$profile_env" ]]; then
    # shellcheck disable=SC1090
    source "$profile_env"
  else
    warn "Host profile missing for: $HOST"
  fi

  export HOST HOST_PROFILE="$HOST"
  export HOST_ID="${HOST_ID:-$HOST}"
  export LAPTOP_PANEL="${LAPTOP_PANEL:-eDP-1}"
  export WALLPAPER_DIR="${WALLPAPER_DIR:-$HOME/Pictures/Wallpapers}"
  export SCREENSHOT_DIR="${SCREENSHOT_DIR:-$HOME/Pictures/Screenshots}"
  export SWAPFILE_SIZE="${SWAPFILE_SIZE:-16G}"
  export NVIDIA_MODE="${NVIDIA_MODE:-integrated}"
  export SWWW_PIXEL_FORMAT="${SWWW_PIXEL_FORMAT:-}"
}

read_manifest() {
  local file="$1"
  grep -Ev '^\s*(#|$)' "$file"
}

ensure_dir() {
  mkdir -p "$1"
}

ensure_line() {
  local line="$1"
  local file="$2"
  sudo touch "$file"
  if ! sudo grep -qF "$line" "$file"; then
    printf '%s\n' "$line" | sudo tee -a "$file" >/dev/null
  fi
}

install_root_file() {
  local source_file="$1"
  local target_file="$2"
  local mode="${3:-0644}"
  sudo install -Dm"$mode" "$source_file" "$target_file"
}

safe_target_backup() {
  local target="$1"
  if [[ -e "$target" && ! -L "$target" ]]; then
    local rel="${target#"$HOME"/}"
    local stamp
    stamp="$(date +%Y%m%d-%H%M%S)"
    local backup_path="$BACKUP_DIR/$stamp/$rel"
    mkdir -p "$(dirname "$backup_path")"
    mv "$target" "$backup_path"
    warn "Backed up conflicting target to $backup_path"
  fi
}

find_refind_linux_conf() {
  local path
  for path in \
    /boot/refind_linux.conf \
    /efi/refind_linux.conf \
    /boot/efi/refind_linux.conf \
    /boot/EFI/refind/refind_linux.conf \
    /efi/EFI/refind/refind_linux.conf \
    /boot/efi/EFI/refind/refind_linux.conf; do
    [[ -f "$path" ]] && {
      printf '%s\n' "$path"
      return 0
    }
  done

  return 1
}

refind_present() {
  local path
  for path in \
    /boot/refind_linux.conf \
    /efi/refind_linux.conf \
    /boot/efi/refind_linux.conf \
    /boot/EFI/refind/refind_linux.conf \
    /efi/EFI/refind/refind_linux.conf \
    /boot/efi/EFI/refind/refind_linux.conf \
    /boot/EFI/refind/refind.conf \
    /efi/EFI/refind/refind.conf \
    /boot/efi/EFI/refind/refind.conf; do
    [[ -e "$path" ]] && return 0
  done

  return 1
}

detect_bootloader() {
  if [[ -d /boot/loader/entries || -d /efi/loader/entries ]]; then
    printf 'systemd-boot\n'
    return 0
  fi

  if [[ -f /etc/default/grub || -d /boot/grub ]]; then
    printf 'grub\n'
    return 0
  fi

  if refind_present; then
    printf 'refind\n'
    return 0
  fi

  printf 'unknown\n'
}

ensure_kernel_param_in_systemd_boot() {
  local param="$1"
  local entry

  for entry in /boot/loader/entries/*.conf /efi/loader/entries/*.conf; do
    [[ -f "$entry" ]] || continue
    if ! sudo grep -qF "$param" "$entry"; then
      sudo sed -i "/^options / s#$# $param#" "$entry"
      note "Added kernel parameter '$param' to $entry"
    fi
  done
}

ensure_kernel_param_in_grub() {
  local param="$1"
  local grub_file="/etc/default/grub"
  local tmp_file line current_value

  [[ -f "$grub_file" ]] || return 0

  if ! sudo grep -qF "$param" "$grub_file"; then
    tmp_file="$(mktemp)"
    chmod 600 "$tmp_file"
    while IFS= read -r line || [[ -n "$line" ]]; do
      if [[ "$line" == GRUB_CMDLINE_LINUX_DEFAULT=* ]]; then
        current_value="${line#GRUB_CMDLINE_LINUX_DEFAULT=\"}"
        current_value="${current_value%\"}"
        if [[ -n "$current_value" ]]; then
          line="GRUB_CMDLINE_LINUX_DEFAULT=\"$current_value $param\""
        else
          line="GRUB_CMDLINE_LINUX_DEFAULT=\"$param\""
        fi
      fi
      printf '%s\n' "$line" >>"$tmp_file"
    done <"$grub_file"

    sudo install -m 0644 "$tmp_file" "$grub_file"
    rm -f "$tmp_file"
    note "Added kernel parameter '$param' to $grub_file"
    sudo grub-mkconfig -o /boot/grub/grub.cfg >/dev/null
  fi
}

ensure_kernel_param_in_refind() {
  local param="$1"
  local conf_file tmp_file line stripped_line changed=0 first_entry_seen=0

  conf_file="$(find_refind_linux_conf || true)"
  [[ -n "$conf_file" ]] || {
    warn "rEFInd detected, but no refind_linux.conf was found. Add kernel parameter manually: $param"
    return 0
  }

  tmp_file="$(mktemp)"
  chmod 600 "$tmp_file"
  while IFS= read -r line || [[ -n "$line" ]]; do
    stripped_line="${line#"${line%%[![:space:]]*}"}"
    if [[ -z "$stripped_line" || "$stripped_line" == \#* ]]; then
      printf '%s\n' "$line" >>"$tmp_file"
      continue
    fi

    if ((first_entry_seen)); then
      printf '%s\n' "$line" >>"$tmp_file"
      continue
    fi

    first_entry_seen=1
    if [[ "$line" == *"$param"* ]]; then
      printf '%s\n' "$line" >>"$tmp_file"
    elif [[ "$line" == *'"' ]]; then
      printf '%s\n' "${line%\"} $param\"" >>"$tmp_file"
      changed=1
    else
      printf '%s %s\n' "$line" "$param" >>"$tmp_file"
      changed=1
    fi
  done <"$conf_file"

  if ((changed)); then
    install_root_file "$tmp_file" "$conf_file"
    note "Added kernel parameter '$param' to $conf_file"
  fi

  rm -f "$tmp_file"
}

ensure_kernel_param() {
  local param="$1"
  case "$(detect_bootloader)" in
    systemd-boot)
      ensure_kernel_param_in_systemd_boot "$param"
      ;;
    grub)
      ensure_kernel_param_in_grub "$param"
      ;;
    refind)
      ensure_kernel_param_in_refind "$param"
      ;;
    *)
      warn "Unknown bootloader. Add kernel parameter manually: $param"
      ;;
  esac
}

unit_exists() {
  local unit="$1"
  systemctl list-unit-files "$unit" --no-legend 2>/dev/null | grep -q "$unit"
}

maybe_enable_system_unit() {
  local unit="$1"
  if unit_exists "$unit"; then
    sudo systemctl enable --now "$unit" >/dev/null
    pass "Enabled system unit: $unit"
  else
    warn "Skipping missing system unit: $unit"
  fi
}

maybe_disable_system_unit() {
  local unit="$1"
  if unit_exists "$unit"; then
    sudo systemctl disable --now "$unit" >/dev/null 2>&1 || true
    pass "Disabled conflicting system unit: $unit"
  fi
}

maybe_disable_user_unit() {
  local unit="$1"
  if [[ -z "${XDG_RUNTIME_DIR:-}" || ! -S "${XDG_RUNTIME_DIR}/bus" ]]; then
    return 0
  fi

  if systemctl --user disable --now "$unit" >/dev/null 2>&1; then
    pass "Disabled user unit: $unit"
  fi
}

maybe_enable_user_unit() {
  local unit="$1"
  if [[ -z "${XDG_RUNTIME_DIR:-}" || ! -S "${XDG_RUNTIME_DIR}/bus" ]]; then
    warn "No user session bus detected. Skipping enable for $unit; Hyprland can still start it through loq-session.target after login."
    return 0
  fi

  if ! systemctl --user daemon-reload >/dev/null 2>&1; then
    warn "Could not reload the user manager while enabling $unit"
    return 0
  fi

  if systemctl --user enable --now "$unit" >/dev/null 2>&1; then
    pass "Enabled user unit: $unit"
  else
    warn "Failed to enable user unit: $unit"
  fi
}

current_wallpaper_file() {
  printf '%s\n' "$STATE_DIR/current-wallpaper"
}
