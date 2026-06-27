#!/usr/bin/env bash
# lumina-dots — One-command update script
# Usage: bash update.sh [--skip-packages] [--skip-dotfiles]
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES_DIR

source "${DOTFILES_DIR}/lib/log.sh"
source "${DOTFILES_DIR}/lib/pkg.sh"
source "${DOTFILES_DIR}/lib/host.sh"
source "${DOTFILES_DIR}/lib/safety.sh"

HOST_PROFILE="${HOST_PROFILE:-$(host::detect)}"
HOST_PROFILE="$(host::canonical "${HOST_PROFILE}")"
export HOST_PROFILE
REBOOT_REQUIRED_EXIT_CODE="${REBOOT_REQUIRED_EXIT_CODE:-20}"
export REBOOT_REQUIRED_EXIT_CODE

SKIP_PACKAGES=false
SKIP_DOTFILES=false

for arg in "$@"; do
  case "${arg}" in
    --skip-packages) SKIP_PACKAGES=true ;;
    --skip-dotfiles) SKIP_DOTFILES=true ;;
    --host=*)
      HOST_PROFILE="$(host::canonical "${arg#*=}")"
      export HOST_PROFILE
      ;;
  esac
done

log::header "lumina-dots Update"

if [[ "${SKIP_PACKAGES}" == "false" ]] && command -v paru >/dev/null 2>&1; then
  UPDATE_SIZE="$(paru -Syup --noconfirm 2>/dev/null | awk '/Total Download Size:/{print $4, $5}' || true)"
  if [[ -n "${UPDATE_SIZE}" ]]; then
    lumina-toast "Update pending: ${UPDATE_SIZE}" "Creating safety snapshot first..." info 2>/dev/null || true
    bash "${DOTFILES_DIR}/scripts/maintenance/backup.sh" "pre-update $(date +%Y-%m-%d)" || true
  fi
fi

# Step 1: Create pre-update snapshot
if [[ "${SKIP_PACKAGES}" == "false" ]]; then
  safety::require_snapshot "lumina-dots pre-update $(date +%Y-%m-%d)"
fi

# Step 2: Pull latest dotfiles
log::section "Pulling latest dotfiles from git"
if [[ -d "${DOTFILES_DIR}/.git" ]]; then
  prev_tag="$(git -C "${DOTFILES_DIR}" describe --tags --abbrev=0 2>/dev/null || echo "unknown")"
  local_branch="$(git -C "${DOTFILES_DIR}" rev-parse --abbrev-ref HEAD)"
  stash_created=false
  if ! git -C "${DOTFILES_DIR}" diff --quiet || ! git -C "${DOTFILES_DIR}" diff --cached --quiet; then
    git -C "${DOTFILES_DIR}" stash push -u -m "auto-stash before update $(date +%Y%m%d-%H%M%S)" >/dev/null
    stash_created=true
  fi
  git -C "${DOTFILES_DIR}" fetch origin
  git -C "${DOTFILES_DIR}" pull --ff-only origin "${local_branch}" &&
    log::success "dotfiles updated" ||
    log::warn "git pull failed — you may have local modifications"
  if [[ "${stash_created}" == "true" ]]; then
    git -C "${DOTFILES_DIR}" stash pop >/dev/null || log::warn "Auto-stash could not be reapplied cleanly"
  fi
  curr_tag="$(git -C "${DOTFILES_DIR}" describe --tags --abbrev=0 2>/dev/null || cat "${DOTFILES_DIR}/.version")"
  if [[ "${prev_tag}" != "${curr_tag}" ]]; then
    log::info "Updated ${prev_tag} → ${curr_tag}"
    log::info "See CHANGELOG.md for what changed"
  fi
else
  log::warn "Not a git repo — skipping git pull"
fi

# Step 3: Update system packages and dependencies
if [[ "${SKIP_PACKAGES}" == "false" ]]; then
  log::section "Updating system packages"
  sudo pacman -Syu --noconfirm
  log::success "System packages updated"

  log::section "Updating AUR packages"
  if command -v paru &>/dev/null; then
    PINNED_DESKTOP_PKGS=(ags-hyprpanel-git hyprswitch walker-bin matugen-bin)
    ignore_args=()
    for pinned_pkg in "${PINNED_DESKTOP_PKGS[@]}"; do
      ignore_args+=("--ignore=${pinned_pkg}")
    done
    paru -Su --noconfirm --aur "${ignore_args[@]}"
    log::success "AUR packages updated"
  fi

  log::section "Syncing repository dependencies"
  # This ensures newly added tools in git commits are automatically installed
  bash "${DOTFILES_DIR}/scripts/install/02-packages.sh"
fi

# Step 4: Re-apply dotfiles symlinks (handles new files added)
if [[ "${SKIP_DOTFILES}" == "false" ]]; then
  log::section "Re-applying dotfile symlinks"
  bash "${DOTFILES_DIR}/scripts/install/03-dotfiles.sh"
fi

log::section "Re-applying host tuning"
host_status=0
bash "${DOTFILES_DIR}/scripts/install/05-hardware.sh" || host_status=$?
if [[ "${host_status}" -eq "${REBOOT_REQUIRED_EXIT_CODE}" ]]; then
  log::warn "Host tuning changed a reboot-sensitive setting. Reboot after this update."
elif [[ "${host_status}" -ne 0 ]]; then
  exit "${host_status}"
fi

log::section "Re-applying systemd services"
bash "${DOTFILES_DIR}/scripts/install/06-services.sh"

log::section "Re-applying theme outputs"
bash "${DOTFILES_DIR}/scripts/apply-theme.sh" || log::warn "Theme refresh reported issues"

# Step 5: Maintenance cleanup
if [[ "${SKIP_PACKAGES}" == "false" ]]; then
  log::section "Running maintenance cleanup"
  bash "${DOTFILES_DIR}/scripts/maintenance/update.sh" || log::warn "Maintenance cleanup reported issues"
fi

# Step 6: Source runtime Hyprland theme files if running
log::section "Sourcing compositor theme files"
if command -v hyprctl &>/dev/null && hyprctl monitors &>/dev/null 2>&1; then
  hyprctl keyword source ~/.config/hypr/colors.conf
  hyprctl keyword source ~/.config/hypr/tokens.conf
  hyprctl keyword source ~/.config/hypr/conf.d/tokens-colors.conf
  log::success "Hyprland theme files sourced"
else
  log::info "Not in Hyprland session — skipping compositor source"
fi

log::header "Update Complete"
log::info "Running system health checks..."
bash "${DOTFILES_DIR}/scripts/doctor.sh" || true
