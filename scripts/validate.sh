#!/usr/bin/env bash
# Runtime validation dispatcher for installed Lumina systems.
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "${DOTFILES_DIR}/lib/log.sh"
source "${DOTFILES_DIR}/lib/link.sh"

errors=0
warnings=0

pass() {
  log::success "$1"
}

fail() {
  log::error "$1"
  ((errors++)) || true
}

warn() {
  log::warn "$1"
  ((warnings++)) || true
}

check_command() {
  local command="$1"
  if command -v "${command}" >/dev/null 2>&1; then
    pass "Command available: ${command}"
  else
    fail "Command missing: ${command}"
  fi
}

validate_packages() {
  log::section "Package Manifests"
  local manifest duplicates
  for manifest in "${DOTFILES_DIR}"/packages/*.txt; do
    [[ -f "${manifest}" ]] || continue
    duplicates="$(awk 'NF && $1 !~ /^#/ { print }' "${manifest}" | sort | uniq -d)"
    if [[ -n "${duplicates}" ]]; then
      fail "Duplicate package(s) in ${manifest##*/}: ${duplicates}"
    else
      pass "No duplicate packages in ${manifest##*/}"
    fi
  done
}

validate_symlinks() {
  log::section "Managed Symlinks"
  if link::verify; then
    pass "Managed symlinks verified"
  else
    fail "Managed symlink verification failed"
  fi
}

validate_services() {
  log::section "User Services"
  local svc
  for svc in \
    loq-session.target \
    loq-hyprpanel.service \
    loq-hypridle.service \
    loq-swww.service \
    lumina-shell.service \
    lumina-welcome.service \
    xdg-desktop-portal-hyprland.service; do
    if systemctl --user is-active "${svc}" >/dev/null 2>&1; then
      pass "Active: ${svc}"
    else
      warn "Inactive or unavailable: ${svc}"
    fi
  done
}

validate_themes() {
  log::section "Theme Runtime"
  check_command matugen
  check_command swww
  for file in \
    "${HOME}/.cache/lumina/visual-tokens.json" \
    "${HOME}/.config/hypr/colors.conf" \
    "${HOME}/.config/hypr/tokens.conf" \
    "${HOME}/.config/hyprpanel/theme.generated.json" \
    "${HOME}/.config/walker/themes/generated.css"; do
    if [[ -s "${file}" ]]; then
      pass "Theme file present: ${file##"$HOME/"}"
    else
      warn "Theme file missing or empty: ${file##"$HOME/"}"
    fi
  done
}

validate_hyprland() {
  log::section "Hyprland Runtime"
  check_command hyprctl
  if command -v hyprctl >/dev/null 2>&1 && hyprctl monitors >/dev/null 2>&1; then
    pass "Hyprland monitors query succeeded"
    hyprctl clients -j >/dev/null 2>&1 && pass "Hyprland clients JSON query succeeded" || warn "Hyprland clients JSON query failed"
    hyprctl workspaces -j >/dev/null 2>&1 && pass "Hyprland workspaces JSON query succeeded" || warn "Hyprland workspaces JSON query failed"
  else
    warn "Hyprland session is not active"
  fi
}

validate_uwsm() {
  log::section "UWSM Runtime"
  check_command uwsm
  if grep -q "uwsm start" "${HOME}/.zprofile" 2>/dev/null; then
    pass "UWSM launch is configured in .zprofile"
  else
    fail "UWSM launch missing from .zprofile"
  fi
}

validate_apps() {
  log::section "Lumina Apps"
  local app
  for app in \
    lumina-shell \
    lumina-welcome \
    lumina-keybind-overlay \
    lumina-control-center \
    lumina-doctor-dashboard \
    lumina-snapshot-manager \
    lumina-activity-history \
    lumina-theme-studio \
    lumina-hub \
    lumina-mission-control \
    lumina-ai \
    lumina-pomodoro \
    lumina-cleanup-manager; do
    check_command "${app}"
  done
}

usage() {
  cat <<'EOF'
Usage: dotfiles validate [all|services|themes|hyprland|uwsm|apps|packages|symlinks]

Runtime validation is intended for a real Arch + Hyprland install.
EOF
}

target="${1:-all}"
case "${target}" in
  all)
    log::header "Lumina Runtime Validation"
    validate_packages
    validate_symlinks
    validate_services
    validate_themes
    validate_hyprland
    validate_uwsm
    validate_apps
    ;;
  packages) validate_packages ;;
  symlinks) validate_symlinks ;;
  services) validate_services ;;
  themes | theme) validate_themes ;;
  hyprland) validate_hyprland ;;
  uwsm) validate_uwsm ;;
  apps) validate_apps ;;
  help | --help | -h)
    usage
    exit 0
    ;;
  *)
    usage
    exit 2
    ;;
esac

if ((errors > 0)); then
  log::error "Runtime validation completed with ${errors} error(s), ${warnings} warning(s)"
else
  log::success "Runtime validation completed with ${warnings} warning(s)"
fi

exit "${errors}"
