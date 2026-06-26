#!/usr/bin/env bash
# lib/link.sh — Idempotent symlink management for lumina-dots
# Requires: lib/log.sh sourced first
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
LOQDOTS_ROOT="${LOQDOTS_ROOT:-$DOTFILES_DIR}"
export DOTFILES_DIR LOQDOTS_ROOT
source "${DOTFILES_DIR}/lib/host.sh"

link::backup_target() {
  local target="$1"
  local backup
  backup="${target}.lumina-bak-$(date +%Y%m%d%H%M%S)"

  log::warn "Backup: ${target##"$HOME/"} → ${backup##"$HOME/"}"
  mv "${target}" "${backup}"
}

link::ensure_directory() {
  local target_dir="$1"

  if [[ -L "${target_dir}" ]]; then
    link::backup_target "${target_dir}"
  elif [[ -e "${target_dir}" ]] && [[ ! -d "${target_dir}" ]]; then
    link::backup_target "${target_dir}"
  fi

  mkdir -p "${target_dir}"
}

link::current_host() {
  if [[ -n "${HOST_PROFILE:-}" ]]; then
    host::canonical "${HOST_PROFILE}"
  else
    host::detect
  fi
}

link::monitor_source() {
  local host_name="${1:-$(link::current_host)}"
  local host_monitor="hosts/${host_name}/hyprland-monitors.conf"
  local host_monitor_alt="hosts/${host_name}/monitors.conf"
  local default_monitor="hypr/.config/hypr/monitors.conf"

  if [[ -f "${DOTFILES_DIR}/${host_monitor}" ]]; then
    printf '%s\n' "${host_monitor}"
  elif [[ -f "${DOTFILES_DIR}/${host_monitor_alt}" ]]; then
    printf '%s\n' "${host_monitor_alt}"
  else
    printf '%s\n' "${default_monitor}"
  fi
}

link::tree_entries() {
  cat <<EOF
hypr/.config/hypr|${HOME}/.config/hypr
hyprpanel/.config/hyprpanel|${HOME}/.config/hyprpanel
walker/.config/walker|${HOME}/.config/walker
ghostty/.config/ghostty|${HOME}/.config/ghostty
matugen/.config/matugen|${HOME}/.config/matugen
apps/lib|${HOME}/.local/share/lumina/lib
apps/core-service|${HOME}/.local/share/lumina/core-service
scripts|${HOME}/.local/share/lumina/scripts
apps/shell|${HOME}/.local/share/lumina/shell
apps/welcome|${HOME}/.local/share/lumina/welcome
apps/keybind-overlay|${HOME}/.local/share/lumina/keybind-overlay
apps/control-center|${HOME}/.local/share/lumina/control-center
apps/settings-studio|${HOME}/.local/share/lumina/settings-studio
apps/doctor-dashboard|${HOME}/.local/share/lumina/doctor-dashboard
apps/snapshot-manager|${HOME}/.local/share/lumina/snapshot-manager
apps/activity-history|${HOME}/.local/share/lumina/activity-history
apps/theme-studio|${HOME}/.local/share/lumina/theme-studio
apps/lumina-hub|${HOME}/.local/share/lumina/lumina-hub
apps/mission-control|${HOME}/.local/share/lumina/mission-control
apps/lumina-ai|${HOME}/.local/share/lumina/lumina-ai
apps/pomodoro|${HOME}/.local/share/lumina/pomodoro
apps/cleanup-manager|${HOME}/.local/share/lumina/cleanup-manager
nvim/.config/nvim|${HOME}/.config/nvim
btop/.config/btop|${HOME}/.config/btop
gtk/.config/gtk-3.0|${HOME}/.config/gtk-3.0
gtk/.config/gtk-4.0|${HOME}/.config/gtk-4.0
waypaper/.config/waypaper|${HOME}/.config/waypaper
wlogout/.config/wlogout|${HOME}/.config/wlogout
uwsm/.config/uwsm|${HOME}/.config/uwsm
local-bin/.local/bin|${HOME}/.local/bin
modules/yazi|${HOME}/.config/yazi
modules/mpv|${HOME}/.config/mpv
systemd/.config/systemd/user|${HOME}/.config/systemd/user
dbus-1/services|${HOME}/.local/share/dbus-1/services
applications|${HOME}/.local/share/applications
lumina/.config/lumina|${HOME}/.config/lumina
shell/.config/zsh|${HOME}/.config/zsh
EOF
}

link::direct_entries() {
  local monitor_src
  monitor_src="$(link::monitor_source)"

  cat <<EOF
${monitor_src}|${HOME}/.config/hypr/monitors.conf
shell/.zshrc|${HOME}/.zshrc
shell/.zshenv|${HOME}/.zshenv
shell/.zprofile|${HOME}/.zprofile
scripts/system/polkit.sh|${HOME}/.config/hypr/scripts/polkit.sh
scripts/system/battery-alert.sh|${HOME}/.config/hypr/scripts/battery-alert.sh
scripts/system/gaming-mode.sh|${HOME}/.config/hypr/scripts/gaming-mode.sh
scripts/system/keybinds-popup.sh|${HOME}/.config/hypr/scripts/keybinds-popup.sh
scripts/system/monitor-detect.sh|${HOME}/.config/hypr/scripts/monitor-detect.sh
scripts/system/setup-avatar.sh|${HOME}/.config/hypr/scripts/setup-avatar.sh
scripts/system/capture-screenshots.sh|${HOME}/.config/hypr/scripts/capture-screenshots.sh
scripts/system/ocr-region.sh|${HOME}/.config/hypr/scripts/ocr-region.sh
scripts/system/presentation-mode.sh|${HOME}/.config/hypr/scripts/presentation-mode.sh
scripts/system/focus-mode.sh|${HOME}/.config/hypr/scripts/focus-mode.sh
scripts/system/idle-inhibit.sh|${HOME}/.config/hypr/scripts/idle-inhibit.sh
scripts/system/media-overlay.sh|${HOME}/.config/hypr/scripts/media-overlay.sh
scripts/system/session-health.sh|${HOME}/.config/hypr/scripts/session-health.sh
scripts/system/workspace-template.sh|${HOME}/.config/hypr/scripts/workspace-template.sh
scripts/system/scratch-notes.sh|${HOME}/.config/hypr/scripts/scratch-notes.sh
scripts/system/scratchpad-terminal.sh|${HOME}/.config/hypr/scripts/scratchpad-terminal.sh
scripts/system/color-picker.sh|${HOME}/.config/hypr/scripts/color-picker.sh
scripts/theme/start-swww-daemon.sh|${HOME}/.config/hypr/scripts/start-swww-daemon.sh
scripts/theme/apply-theme-clipboard.sh|${HOME}/.config/hypr/scripts/apply-theme-clipboard.sh
scripts/theme/random-wallpaper.sh|${HOME}/.config/hypr/scripts/random-wallpaper.sh
scripts/theme/apply-theme.sh|${HOME}/.config/hypr/scripts/apply-theme.sh
apps/shell/lumina-shell.py|${HOME}/.local/bin/lumina-shell
apps/welcome/lumina-welcome.py|${HOME}/.local/bin/lumina-welcome
apps/keybind-overlay/lumina-keybind-overlay.py|${HOME}/.local/bin/lumina-keybind-overlay
apps/control-center/lumina-control-center.py|${HOME}/.local/bin/lumina-control-center
apps/doctor-dashboard/lumina-doctor-dashboard.py|${HOME}/.local/bin/lumina-doctor-dashboard
apps/snapshot-manager/lumina-snapshot-manager.py|${HOME}/.local/bin/lumina-snapshot-manager
apps/activity-history/lumina-activity-history.py|${HOME}/.local/bin/lumina-activity-history
apps/theme-studio/lumina-theme-studio.py|${HOME}/.local/bin/lumina-theme-studio
apps/lumina-hub/lumina-hub.py|${HOME}/.local/bin/lumina-hub
apps/mission-control/lumina-mission-control.py|${HOME}/.local/bin/lumina-mission-control
apps/lumina-ai/lumina-ai.py|${HOME}/.local/bin/lumina-ai
apps/pomodoro/lumina-pomodoro.py|${HOME}/.local/bin/lumina-pomodoro
apps/cleanup-manager/lumina-cleanup-manager.py|${HOME}/.local/bin/lumina-cleanup-manager
scripts/dev/firewall-profile.sh|${HOME}/.local/bin/lumina-firewall
scripts/dev/secure-tunnel.sh|${HOME}/.local/bin/lumina-tunnel
EOF
}

link::skip_tree_file() {
  local src_rel="$1"
  local rel_path="$2"

  case "${rel_path}" in
    __pycache__/* | */__pycache__/* | *.pyc | *.pyo) return 0 ;;
  esac

  case "${src_rel}:${rel_path}" in
    hypr/.config/hypr:monitors.conf) return 0 ;;
    ghostty/.config/ghostty:themes/LoqDynamic) return 0 ;;
    btop/.config/btop:themes/loq.theme) return 0 ;;
    walker/.config/walker:themes/generated.css) return 0 ;;
    hyprpanel/.config/hyprpanel:theme.generated.json) return 0 ;;
    hyprpanel/.config/hyprpanel:config.json) return 0 ;;
    wlogout/.config/wlogout:colors.css) return 0 ;;
    gtk/.config/gtk-3.0:settings.ini) return 0 ;;
    gtk/.config/gtk-3.0:gtk.css) return 0 ;;
    gtk/.config/gtk-4.0:settings.ini) return 0 ;;
    gtk/.config/gtk-4.0:gtk.css) return 0 ;;
    modules/yazi:theme.toml) return 0 ;;
  esac

  return 1
}

# Create a symlink (idempotent, with backup)
# Usage: link::create <source_relative_to_DOTFILES_DIR> <absolute_target_path>
link::create() {
  local src_rel="$1"
  local target="$2"
  local src="${DOTFILES_DIR}/${src_rel}"

  if [[ ! -e "${src}" ]]; then
    log::error "Link source does not exist: ${src}"
    return 1
  fi

  # Already the correct symlink → skip
  if [[ -L "${target}" ]] && [[ "$(readlink -f "${target}")" == "$(readlink -f "${src}")" ]]; then
    log::dim "Already linked: ${target##"$HOME/"}"
    return 0
  fi

  # Target exists but is wrong → back it up
  if [[ -e "${target}" ]] || [[ -L "${target}" ]]; then
    link::backup_target "${target}"
  fi

  mkdir -p "$(dirname "${target}")"
  ln -sf "${src}" "${target}"

  if [[ -L "${target}" ]]; then
    log::success "Linked: ${target##"$HOME/"}"
  else
    log::error "Failed: ${target}"
    return 1
  fi
}

# Link every file in a source tree while keeping target directories real.
# Usage: link::create_tree <source_dir_relative_to_DOTFILES_DIR> <absolute_target_dir>
link::create_tree() {
  local src_rel="$1"
  local target_dir="$2"
  local src_dir="${DOTFILES_DIR}/${src_rel}"
  local path rel_path

  if [[ ! -d "${src_dir}" ]]; then
    log::error "Link tree source does not exist: ${src_dir}"
    return 1
  fi

  link::ensure_directory "${target_dir}"

  while IFS= read -r -d '' path; do
    rel_path="${path#"${src_dir}/"}"
    link::ensure_directory "${target_dir}/${rel_path}"
  done < <(find "${src_dir}" -mindepth 1 -type d -print0)

  while IFS= read -r -d '' path; do
    rel_path="${path#"${src_dir}/"}"

    if link::skip_tree_file "${src_rel}" "${rel_path}"; then
      continue
    fi

    link::create "${src_rel}/${rel_path}" "${target_dir}/${rel_path}"
  done < <(find "${src_dir}" -type f -print0)
}

# Create all standard dotfile symlinks
link::all() {
  log::section "Creating config symlinks"
  local src_rel target

  link::harden_systemd_user_units
  link::harden_lumina_templates

  while IFS='|' read -r src_rel target; do
    [[ -n "${src_rel}" ]] || continue
    link::create_tree "${src_rel}" "${target}"
  done < <(link::tree_entries)

  while IFS='|' read -r src_rel target; do
    [[ -n "${src_rel}" ]] || continue
    link::create "${src_rel}" "${target}"
  done < <(link::direct_entries)

  log::success "All symlinks created"
}

link::harden_systemd_user_units() {
  local units_dir="${DOTFILES_DIR}/systemd/.config/systemd/user"

  [[ -d "${units_dir}" ]] || return 0

  find "${units_dir}" -maxdepth 1 -type f \
    \( -name '*.service' -o -name '*.target' -o -name '*.timer' -o -name '*.socket' \) \
    -exec chmod 0644 {} + 2>/dev/null || true
}

link::harden_lumina_templates() {
  local ocr_pipeline="${DOTFILES_DIR}/lumina/.config/lumina/ocr-pipeline.sh"

  [[ -f "${ocr_pipeline}" ]] || return 0
  chmod 0644 "${ocr_pipeline}" 2>/dev/null || true
}

# Verify a single managed symlink
link::verify_entry() {
  local src_rel="$1"
  local target="$2"
  local src="${DOTFILES_DIR}/${src_rel}"

  if [[ -L "${target}" ]] && [[ -e "${target}" ]] && [[ "$(readlink -f "${target}")" == "$(readlink -f "${src}")" ]]; then
    log::success "OK: ${target##"$HOME/"}"
    return 0
  fi

  if [[ -L "${target}" ]]; then
    log::error "BROKEN SYMLINK: ${target##"$HOME/"}"
  else
    log::error "MISSING: ${target##"$HOME/"}"
  fi

  return 1
}

link::verify_tree() {
  local src_rel="$1"
  local target_dir="$2"
  local src_dir="${DOTFILES_DIR}/${src_rel}"
  local path rel_path target
  local -i errors=0

  if [[ -L "${target_dir}" ]]; then
    log::error "EXPECTED DIRECTORY: ${target_dir##"$HOME/"} is still a symlink"
    ((errors++)) || true
  elif [[ ! -d "${target_dir}" ]]; then
    log::error "MISSING DIRECTORY: ${target_dir##"$HOME/"}"
    return 1
  fi

  while IFS= read -r -d '' path; do
    rel_path="${path#"${src_dir}/"}"

    if link::skip_tree_file "${src_rel}" "${rel_path}"; then
      continue
    fi

    target="${target_dir}/${rel_path}"
    link::verify_entry "${src_rel}/${rel_path}" "${target}" || ((errors++)) || true
  done < <(find "${src_dir}" -type f -print0)

  return "${errors}"
}

# Verify all expected symlinks
link::verify() {
  local src_rel target
  local status
  local -i errors=0

  while IFS='|' read -r src_rel target; do
    [[ -n "${src_rel}" ]] || continue
    if link::verify_tree "${src_rel}" "${target}"; then
      :
    else
      status=$?
      ((errors += status)) || true
    fi
  done < <(link::tree_entries)

  while IFS='|' read -r src_rel target; do
    [[ -n "${src_rel}" ]] || continue
    if ! link::verify_entry "${src_rel}" "${target}"; then
      ((errors++)) || true
    fi
  done < <(link::direct_entries)

  return ${errors}
}

link::restore_backup() {
  local target="$1"
  local backup

  backup="$(ls -1d "${target}.lumina-bak-"* 2>/dev/null | tail -n 1 || true)"
  if [[ -n "${backup}" ]]; then
    mv "${backup}" "${target}"
    log::info "Restored backup: ${target}"
  fi
}

link::remove_entry() {
  local target="$1"

  if [[ -L "${target}" ]]; then
    unlink "${target}"
    log::success "Removed symlink: ${target}"
  else
    log::dim "Skipped non-symlink or missing: ${target}"
  fi
}

link::remove_tree() {
  local src_rel="$1"
  local target_dir="$2"
  local src_dir="${DOTFILES_DIR}/${src_rel}"
  local path rel_path target

  while IFS= read -r -d '' path; do
    rel_path="${path#"${src_dir}/"}"

    if link::skip_tree_file "${src_rel}" "${rel_path}"; then
      continue
    fi

    target="${target_dir}/${rel_path}"
    link::remove_entry "${target}"
    link::restore_backup "${target}"
  done < <(find "${src_dir}" -type f -print0)

  if [[ -d "${target_dir}" ]] && [[ ! -L "${target_dir}" ]]; then
    find "${target_dir}" -depth -type d -empty -delete 2>/dev/null || true
  fi

  link::restore_backup "${target_dir}"
}

link::remove_all() {
  local src_rel target

  while IFS='|' read -r src_rel target; do
    [[ -n "${src_rel}" ]] || continue
    link::remove_tree "${src_rel}" "${target}"
  done < <(link::tree_entries)

  while IFS='|' read -r src_rel target; do
    [[ -n "${src_rel}" ]] || continue
    link::remove_entry "${target}"
    link::restore_backup "${target}"
  done < <(link::direct_entries)
}
