#!/usr/bin/env bash
# scripts/install/05-hardware.sh — LOQ 15IRX9 hardware-specific tuning
# NVIDIA hybrid graphics, sleep, power management, kernel parameters
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${SCRIPT_PATH}")/../.." && pwd)}"
source "${DOTFILES_DIR}/lib/log.sh"
source "${DOTFILES_DIR}/lib/host.sh"
source "${DOTFILES_DIR}/lib/common.sh"

REBOOT_REQUIRED_EXIT_CODE="${REBOOT_REQUIRED_EXIT_CODE:-20}"

hardware::normalize_nvidia_mode() {
  case "${1:-hybrid}" in
    "") printf '%s\n' "hybrid" ;;
    hybrid) printf '%s\n' "hybrid" ;;
    integrated) printf '%s\n' "integrated" ;;
    nvidia) printf '%s\n' "nvidia" ;;
    dedicated) printf '%s\n' "nvidia" ;;
    *) return 1 ;;
  esac
}

setup_swap_if_missing() {
  if swapon --noheadings --show=NAME | grep -q .; then
    log::info "Swap already active"
    return 0
  fi

  if [[ "$(findmnt -n -o FSTYPE /)" != "btrfs" ]]; then
    log::warn "Root is not Btrfs. Skipping auto swapfile creation."
    return 0
  fi

  sudo btrfs subvolume create /.swapvol >/dev/null 2>&1 || true
  if [[ ! -f /.swapvol/swapfile ]]; then
    sudo btrfs filesystem mkswapfile --size "${SWAPFILE_SIZE:-16G}" /.swapvol/swapfile >/dev/null
    log::success "Created Btrfs swapfile at /.swapvol/swapfile"
  fi

  if ! grep -q "/.swapvol/swapfile" /etc/fstab; then
    echo "/.swapvol/swapfile none swap defaults 0 0" | sudo tee -a /etc/fstab >/dev/null
  fi
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
    log::info "Configured resume=UUID for swap partition"
    return 0
  fi

  if [[ "$swap_type" == "file" ]]; then
    resume_uuid="$(findmnt -n -o UUID /)"
    resume_offset="$(sudo btrfs inspect-internal map-swapfile -r "$swap_name")"
    ensure_kernel_param "resume=UUID=$resume_uuid"
    ensure_kernel_param "resume_offset=$resume_offset"
    log::info "Configured resume UUID and offset for Btrfs swapfile"
  fi
}

remove_nvidia_modules_from_mkinitcpio() {
  local mkinitcpio_conf="/etc/mkinitcpio.conf"
  local tmp_file

  [[ -f "${mkinitcpio_conf}" ]] || return 0
  grep -qE '^MODULES=.*nvidia' "${mkinitcpio_conf}" || return 0

  tmp_file="$(mktemp)"
  chmod 600 "${tmp_file}"
  awk '
      /^MODULES=\(/ {
        line = $0
        sub(/^MODULES=\(/, "", line)
        sub(/\)$/, "", line)
        n = split(line, modules, /[[:space:]]+/)
        out = "MODULES=("
        sep = ""
        for (i = 1; i <= n; i++) {
          if (modules[i] == "" || modules[i] ~ /^nvidia(_modeset|_uvm|_drm)?$/) {
            continue
          }
          out = out sep modules[i]
          sep = " "
        }
        print out ")"
        next
      }
      { print }
    ' "${mkinitcpio_conf}" >"${tmp_file}"
  sudo install -m 0644 "${tmp_file}" "${mkinitcpio_conf}"
  rm -f "${tmp_file}"
  log::success "Removed NVIDIA modules from mkinitcpio MODULES for integrated mode"
}

ensure_resume_hook() {
  local hooks_line hooks tmp_file
  local raw_hooks=()
  local normalized_hooks=()
  local hook inserted=0 has_fsck=0

  hooks_line="$(grep '^HOOKS=(' /etc/mkinitcpio.conf | head -n1 || true)"
  [[ -n "$hooks_line" ]] || {
    log::warn "Could not find a HOOKS line in /etc/mkinitcpio.conf"
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
    chmod 600 "${tmp_file}"
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
    log::success "Normalized resume hook in mkinitcpio.conf"
  else
    log::success "mkinitcpio resume hook already in the correct position"
  fi
}

hardware::query_nvidia_mode() {
  local current_mode

  current_mode="$(envycontrol --query 2>/dev/null | awk 'NF { print tolower($NF) }' | tail -n 1)"
  printf '%s\n' "${current_mode:-unknown}"
}

hardware::host_file() {
  local host_name="$1"
  local name="$2"
  local primary="${DOTFILES_DIR}/hosts/${host_name}/${name}"

  [[ -f "${primary}" ]] || return 1
  printf '%s\n' "${primary}"
}

hardware::install_host_dropins() {
  local host_name="$1"
  local file

  if file="$(hardware::host_file "${host_name}" modprobe-i915.conf)"; then
    sudo install -Dm0644 "${file}" "/etc/modprobe.d/loqdots-i915.conf"
    log::success "Installed i915 modprobe drop-in"
  fi

  if file="$(hardware::host_file "${host_name}" sleep.conf)"; then
    sudo install -Dm0644 "${file}" "/etc/systemd/sleep.conf.d/60-loqdots.conf"
    log::success "Installed systemd sleep drop-in"
  fi

  if file="$(hardware::host_file "${host_name}" logind.conf)"; then
    sudo install -Dm0644 "${file}" "/etc/systemd/logind.conf.d/60-loqdots.conf"
    log::success "Installed logind drop-in"
  fi
}

hardware::append_refind_param_file() {
  local file_path="$1"
  local param="$2"
  local tmp_file

  tmp_file="$(mktemp)"
  chmod 600 "${tmp_file}"

  if ! awk -v param="${param}" '
    BEGIN {
      saw_boot_entry = 0
    }
    /^[[:space:]]*#/ || /^[[:space:]]*$/ {
      print
      next
    }
    /^[[:space:]]*"/ {
      if (saw_boot_entry) {
        print
        next
      }
      saw_boot_entry = 1
      line = $0
      if (index(line, param) == 0) {
        sub(/"[[:space:]]*$/, " " param "\"", line)
      }
      print line
      next
    }
    {
      print
    }
    END {
      if (!saw_boot_entry) {
        exit 1
      }
    }
  ' "${file_path}" >"${tmp_file}"; then
    rm -f "${tmp_file}"
    return 1
  fi

  cat "${tmp_file}" >"${file_path}"
  rm -f "${tmp_file}"
}

hardware::append_refind_param() {
  local file_path="$1"
  local param="$2"
  local tmp_file

  tmp_file="$(mktemp)"
  chmod 600 "${tmp_file}"
  sudo dd if="${file_path}" of="${tmp_file}" status=none

  if ! hardware::append_refind_param_file "${tmp_file}" "${param}"; then
    rm -f "${tmp_file}"
    return 1
  fi

  sudo install -m 0644 "${tmp_file}" "${file_path}"
  rm -f "${tmp_file}"
}

hardware::main() {
  local host_name desired_mode current_mode param reboot_required
  local mkinitcpio_conf

  host_name="${HOST_PROFILE:-$(host::detect)}"
  host::load "${host_name}" >/dev/null 2>&1 || true
  reboot_required=false

  log::header "Step 5: Hardware Configuration (${host_name})"

  if [[ "${host_name}" != "loq-15irx9" ]]; then
    log::info "Host is not loq-15irx9 — skipping hardware-specific tuning"
    log::info "If this is a LOQ 15IRX9, re-run with: bash install.sh --host=loq-15irx9"
    return 0
  fi

  # ─── Btrfs Swap & Resume Hook ───────────────────────────────────────────────
  log::section "Swapfile and Resume Hook"
  setup_swap_if_missing
  ensure_resume_hook
  configure_resume

  if ! desired_mode="$(hardware::normalize_nvidia_mode "${NVIDIA_MODE:-integrated}")"; then
    log::fatal "Invalid NVIDIA_MODE='${NVIDIA_MODE:-}'. Use: integrated, hybrid, nvidia, or dedicated."
  fi

  # ─── Kernel parameters (rEFInd / systemd-boot / GRUB) ─────────────────────
  log::section "Kernel parameters"

  local kernel_params_file
  kernel_params_file="${DOTFILES_DIR}/hosts/${host_name}/kernel-params.conf"

  local -a required_params=()
  if [[ -f "${kernel_params_file}" ]]; then
    while IFS= read -r param; do
      [[ -n "${param}" ]] && required_params+=("${param}")
    done < <(read_manifest "${kernel_params_file}")
    log::info "Loaded ${#required_params[@]} base kernel params from ${kernel_params_file##*/}"
  else
    log::warn "kernel-params.conf not found for ${host_name}; falling back to defaults"
    required_params=(
      "quiet"
      "loglevel=3"
      "rd.udev.log_level=3"
      "vt.global_cursor_default=0"
      "nowatchdog"
      "acpi_backlight=native"
      "i915.enable_psr=0"
      "mem_sleep_default=deep"
      "nvme_core.default_ps_max_latency_us=0"
      "ibt=off"
      "iommu=pt"
      "mitigations=auto"
    )
  fi

  if [[ "${desired_mode}" != "integrated" ]]; then
    required_params+=(
      "nvidia-drm.modeset=1"
      "nvidia-drm.fbdev=1"
    )
  fi

  log::info "Injecting kernel parameters via detected bootloader..."
  for param in "${required_params[@]}"; do
    ensure_kernel_param "${param}"
    log::dim "Ensured: ${param}"
  done

  log::section "Host drop-ins"
  hardware::install_host_dropins "${host_name}"

  if [[ "${desired_mode}" == "integrated" ]]; then
    log::info "Integrated GPU mode selected; skipping NVIDIA module and KMS setup"
    remove_nvidia_modules_from_mkinitcpio
    if [[ -f /etc/modprobe.d/nvidia.conf ]]; then
      sudo mv /etc/modprobe.d/nvidia.conf /etc/modprobe.d/nvidia.conf.lumina-disabled 2>/dev/null || true
      log::success "Disabled stale /etc/modprobe.d/nvidia.conf"
    fi
  else
    # ─── NVIDIA kernel mode setting ───────────────────────────────────────────
    log::section "NVIDIA Kernel Mode Setting (KMS)"

    if ! pacman -Qi nvidia-open-dkms nvidia-utils >/dev/null 2>&1; then
      log::warn "NVIDIA mode requested, but nvidia-open-dkms/nvidia-utils are missing"
      log::warn "Install packages/optional-nvidia.txt before using NVIDIA_MODE=${desired_mode}"
    fi

    sudo tee /etc/modprobe.d/nvidia.conf >/dev/null <<'NVIDIA_EOF'
# NVIDIA KMS and Wayland support for LOQ 15IRX9
options nvidia_drm modeset=1 fbdev=1

# S0ix power management (fixes suspend/resume on LOQ 15IRX9)
options nvidia NVreg_EnableS0ixPowerManagement=1
options nvidia NVreg_TemporaryFilePath=/var/tmp

# Dynamic power management — allow GPU to power down when idle
# 0x02 = coarse-grained (safer), 0x03 = fine-grained (more savings)
options nvidia NVreg_DynamicPowerManagement=0x02

# Preserve video memory on suspend (required for proper resume)
options nvidia NVreg_PreserveVideoMemoryAllocations=1
NVIDIA_EOF
    log::success "/etc/modprobe.d/nvidia.conf written"

    # ─── mkinitcpio — NVIDIA modules ─────────────────────────────────────────
    log::section "mkinitcpio NVIDIA modules"
    mkinitcpio_conf="/etc/mkinitcpio.conf"

    if grep -q "^MODULES=()$" "${mkinitcpio_conf}"; then
      sudo sed -i 's/^MODULES=()/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' "${mkinitcpio_conf}"
      log::success "NVIDIA modules added to mkinitcpio MODULES"
    elif ! grep -q "nvidia_drm" "${mkinitcpio_conf}"; then
      sudo sed -i 's/^MODULES=(\(.*\))/MODULES=(\1 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' "${mkinitcpio_conf}"
      log::success "NVIDIA modules appended to mkinitcpio MODULES"
    else
      log::dim "NVIDIA modules already in mkinitcpio MODULES"
    fi

    # ─── NVIDIA suspend/hibernate systemd services ───────────────────────────
    log::section "NVIDIA suspend/resume services"
    sudo systemctl enable \
      nvidia-suspend.service \
      nvidia-hibernate.service \
      nvidia-resume.service \
      2>/dev/null && log::success "NVIDIA power services enabled" ||
      log::warn "NVIDIA power services not found — ensure nvidia-open-dkms is installed"
  fi

  log::step "Rebuilding initramfs..."
  sudo mkinitcpio -P
  log::success "initramfs rebuilt"

  # ─── Envycontrol (NVIDIA Mode) ────────────────────────────────────────────
  log::section "Envycontrol (GPU Mode)"
  if command -v envycontrol &>/dev/null; then
    current_mode="$(hardware::query_nvidia_mode)"

    if [[ "${current_mode}" != "${desired_mode}" ]]; then
      log::step "Setting NVIDIA mode to ${desired_mode}..."
      if sudo envycontrol -s "${desired_mode}"; then
        log::success "GPU mode set to ${desired_mode}"
        reboot_required=true
      else
        log::error "Failed to set GPU mode"
      fi
    else
      log::dim "GPU already in ${desired_mode} mode"
    fi
  else
    log::warn "envycontrol not installed. Skipping GPU mode enforcement."
  fi

  # ─── AutoCPUFreq ──────────────────────────────────────────────────────────
  log::section "AutoCPUFreq (intelligent CPU governor)"
  if command -v auto-cpufreq &>/dev/null; then
    if [[ ! -f /etc/auto-cpufreq.conf ]]; then
      sudo tee /etc/auto-cpufreq.conf >/dev/null <<'AUTOCPU_EOF'
[charger]
governor = performance
energy_performance_preference = performance
turbo = auto

[battery]
governor = powersave
energy_performance_preference = power
turbo = auto
AUTOCPU_EOF
      log::success "/etc/auto-cpufreq.conf written"
    fi
    sudo systemctl enable --now auto-cpufreq &&
      log::success "auto-cpufreq service enabled" ||
      log::warn "auto-cpufreq enable failed"
  else
    log::warn "auto-cpufreq not installed — install from AUR and re-run"
  fi

  # ─── Thermald (Intel thermal management) ──────────────────────────────────
  log::section "Thermald"
  sudo systemctl enable --now thermald &&
    log::success "thermald enabled" ||
    log::warn "thermald not available"

  # ─── Ideapad laptop module (fan/power for Lenovo) ─────────────────────────
  log::section "Ideapad-laptop kernel module"
  if ! lsmod | grep -q ideapad_laptop; then
    sudo modprobe ideapad_laptop 2>/dev/null && log::success "ideapad_laptop module loaded" ||
      log::warn "ideapad_laptop module not available"
  fi

  if ! grep -q "ideapad_laptop" /etc/modules-load.d/lenovo.conf 2>/dev/null; then
    echo "ideapad_laptop" | sudo tee /etc/modules-load.d/lenovo.conf >/dev/null
    log::success "ideapad_laptop module set to auto-load"
  fi

  # ─── Power rule: allow backlight write without sudo ───────────────────────
  log::section "udev backlight rule"
  sudo tee /etc/udev/rules.d/90-backlight.rules >/dev/null <<'UDEV_EOF'
ACTION=="add", SUBSYSTEM=="backlight", KERNEL=="intel_backlight", RUN+="/bin/chgrp video /sys/class/backlight/%k/brightness"
ACTION=="add", SUBSYSTEM=="backlight", KERNEL=="intel_backlight", RUN+="/bin/chmod g+w /sys/class/backlight/%k/brightness"
UDEV_EOF
  sudo usermod -aG video "${USER}"
  sudo udevadm control --reload-rules
  log::success "Backlight udev rule applied, ${USER} added to video group"

  # ─── fwupd firmware updates ────────────────────────────────────────────────
  log::section "fwupd (firmware updates)"
  sudo systemctl enable --now fwupd &&
    log::success "fwupd enabled" ||
    log::warn "fwupd not available"

  if [[ "${reboot_required}" == "true" ]]; then
    log::warn "Reboot required before continuing with the rest of the install"
    return "${REBOOT_REQUIRED_EXIT_CODE}"
  fi

  log::success "Hardware configuration complete for LOQ 15IRX9"
  log::info "Reboot after the first hardware run, or after changing kernel/GPU settings."
  return 0
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  hardware::main "$@"
fi
