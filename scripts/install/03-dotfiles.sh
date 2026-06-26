#!/usr/bin/env bash
# scripts/install/03-dotfiles.sh — Dotfiles symlinking
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "${DOTFILES_DIR}/lib/log.sh"
source "${DOTFILES_DIR}/lib/link.sh"
source "${DOTFILES_DIR}/lib/runtime.sh"

log::header "Step 3: Dotfiles Symlinking"

runtime::write_env "${DOTFILES_DIR}"
log::success "Runtime environment pinned to ${DOTFILES_DIR}"

chmod +x "${DOTFILES_DIR}/install.sh" "${DOTFILES_DIR}/update.sh" "${DOTFILES_DIR}/setup" 2>/dev/null || true
chmod +x "${DOTFILES_DIR}/apps/shell/lumina-shell.py" 2>/dev/null || true
chmod +x "${DOTFILES_DIR}/apps/welcome/lumina-welcome.py" 2>/dev/null || true
chmod +x "${DOTFILES_DIR}/apps/keybind-overlay/lumina-keybind-overlay.py" 2>/dev/null || true
chmod +x "${DOTFILES_DIR}/apps/control-center/lumina-control-center.py" 2>/dev/null || true
chmod +x "${DOTFILES_DIR}/apps/doctor-dashboard/lumina-doctor-dashboard.py" 2>/dev/null || true
chmod +x "${DOTFILES_DIR}/apps/snapshot-manager/lumina-snapshot-manager.py" 2>/dev/null || true
chmod +x "${DOTFILES_DIR}/apps/activity-history/lumina-activity-history.py" 2>/dev/null || true
chmod +x "${DOTFILES_DIR}/apps/theme-studio/lumina-theme-studio.py" 2>/dev/null || true
chmod +x "${DOTFILES_DIR}/apps/lumina-hub/lumina-hub.py" 2>/dev/null || true
chmod +x "${DOTFILES_DIR}/apps/mission-control/lumina-mission-control.py" 2>/dev/null || true
chmod +x "${DOTFILES_DIR}/apps/lumina-ai/lumina-ai.py" 2>/dev/null || true
chmod +x "${DOTFILES_DIR}/apps/pomodoro/lumina-pomodoro.py" 2>/dev/null || true
chmod +x "${DOTFILES_DIR}/apps/cleanup-manager/lumina-cleanup-manager.py" 2>/dev/null || true
find "${DOTFILES_DIR}/scripts" "${DOTFILES_DIR}/local-bin/.local/bin" -type f -exec chmod +x {} + 2>/dev/null || true

# Create all symlinks
link::all

# ─── Ensure local-only Hyprland directories exist ───────────────────────────
mkdir -p "${HOME}/.config/hypr/custom"
touch "${HOME}/.config/hypr/custom/.gitkeep"

seed_dynamic_file() {
  local source_file="$1"
  local target_file="$2"

  if [[ -L "$target_file" ]]; then
    rm -f "$target_file"
  fi

  if [[ ! -s "$target_file" ]]; then
    install -Dm0644 "$source_file" "$target_file"
  fi
}

seed_dynamic_file "${DOTFILES_DIR}/themes/defaults/hypr/colors.conf" "${HOME}/.config/hypr/colors.conf"
seed_dynamic_file "${DOTFILES_DIR}/themes/defaults/hypr/tokens.conf" "${HOME}/.config/hypr/tokens.conf"
seed_dynamic_file "${DOTFILES_DIR}/themes/defaults/hypr/hyprlock-colors.conf" "${HOME}/.config/hypr/hyprlock-colors.conf"
seed_dynamic_file "${DOTFILES_DIR}/themes/defaults/ghostty/LoqDynamic" "${HOME}/.config/ghostty/themes/LoqDynamic"
seed_dynamic_file "${DOTFILES_DIR}/themes/defaults/ghostty/lumina-tokens.conf" "${HOME}/.config/ghostty/lumina-tokens.conf"
seed_dynamic_file "${DOTFILES_DIR}/themes/defaults/btop/loq.theme" "${HOME}/.config/btop/themes/loq.theme"
seed_dynamic_file "${DOTFILES_DIR}/themes/defaults/walker/generated.css" "${HOME}/.config/walker/themes/generated.css"
seed_dynamic_file "${DOTFILES_DIR}/themes/defaults/hyprpanel/theme.generated.json" "${HOME}/.config/hyprpanel/theme.generated.json"
seed_dynamic_file "${DOTFILES_DIR}/themes/defaults/wlogout/colors.css" "${HOME}/.config/wlogout/colors.css"
seed_dynamic_file "${DOTFILES_DIR}/shell/.config/starship.toml" "${HOME}/.config/starship.toml"
seed_dynamic_file "${DOTFILES_DIR}/modules/yazi/theme.toml" "${HOME}/.config/yazi/theme.toml"

bash "${DOTFILES_DIR}/scripts/system/setup-avatar.sh" || true

# Bootstrap Hyprpanel config to prevent blank bar on first boot
mkdir -p "${HOME}/.config/hyprpanel"
if command -v jq >/dev/null 2>&1; then
  LOQDOTS_ROOT="${DOTFILES_DIR}" bash "${DOTFILES_DIR}/scripts/bootstrap-hyprpanel.sh"
else
  cp "${DOTFILES_DIR}/hyprpanel/.config/hyprpanel/base.json" "${HOME}/.config/hyprpanel/config.json" 2>/dev/null || true
  log::warn "jq not installed; copied Hyprpanel base config without generated theme merge"
fi

# ─── Verify ────────────────────────────────────────────────────────────────────
log::section "Verifying symlinks"
link::verify || log::warn "Some symlinks have issues — run 'dotfiles doctor' after install"

# ─── dotfiles CLI command ─────────────────────────────────────────────────────
log::section "Installing 'dotfiles' CLI command"
DOTFILES_BIN="/usr/local/bin/dotfiles"

sudo tee "${DOTFILES_BIN}" >/dev/null <<'DOTFILES_CLI_EOF'
#!/usr/bin/env bash
# lumina-dots CLI — the 'dotfiles' command

# Prefer the installer-pinned runtime environment; fall back to common locations.
if [[ -f "${HOME}/.config/lumina/env.sh" ]]; then
  # shellcheck disable=SC1090
  source "${HOME}/.config/lumina/env.sh"
fi
for _d in "${DOTFILES_DIR:-}" "${HOME}/lumina-dots" "${HOME}/dotfiles" "${HOME}/lumina-merged"; do
  if [[ -n "${_d}" && -d "${_d}/lib" && -f "${_d}/install.sh" ]]; then
    DOTFILES_DIR="${_d}"
    break
  fi
done
DOTFILES_DIR="${DOTFILES_DIR:-${HOME}/lumina-dots}"
export DOTFILES_DIR

case "${1:-}" in
  install)    bash "${DOTFILES_DIR}/install.sh" install "${@:2}" ;;
  update)     bash "${DOTFILES_DIR}/update.sh" "${@:2}" ;;
  doctor)     bash "${DOTFILES_DIR}/scripts/doctor.sh" "${@:2}" ;;
  doctor-dashboard|doctor-gui) python3 "${DOTFILES_DIR}/apps/doctor-dashboard/lumina-doctor-dashboard.py" "${@:2}" ;;
  validate)   bash "${DOTFILES_DIR}/scripts/validate.sh" "${@:2}" ;;
  status)     bash "${DOTFILES_DIR}/scripts/status.sh" ;;
  shell)      python3 "${DOTFILES_DIR}/apps/shell/lumina-shell.py" "${@:2}" ;;
  welcome)    python3 "${DOTFILES_DIR}/apps/welcome/lumina-welcome.py" "${@:2}" ;;
  keybinds)   python3 "${DOTFILES_DIR}/apps/keybind-overlay/lumina-keybind-overlay.py" "${@:2}" ;;
  control)    python3 "${DOTFILES_DIR}/apps/control-center/lumina-control-center.py" "${@:2}" ;;
  snapshot)   python3 "${DOTFILES_DIR}/apps/snapshot-manager/lumina-snapshot-manager.py" "${@:2}" ;;
  activity)   python3 "${DOTFILES_DIR}/apps/activity-history/lumina-activity-history.py" "${@:2}" ;;
  theme-studio) python3 "${DOTFILES_DIR}/apps/theme-studio/lumina-theme-studio.py" "${@:2}" ;;
  hub)        python3 "${DOTFILES_DIR}/apps/lumina-hub/lumina-hub.py" "${@:2}" ;;
  mission-control|mission) python3 "${DOTFILES_DIR}/apps/mission-control/lumina-mission-control.py" "${@:2}" ;;
  ai)         python3 "${DOTFILES_DIR}/apps/lumina-ai/lumina-ai.py" "${@:2}" ;;
  pomodoro)   python3 "${DOTFILES_DIR}/apps/pomodoro/lumina-pomodoro.py" "${@:2}" ;;
  cleanup)    python3 "${DOTFILES_DIR}/apps/cleanup-manager/lumina-cleanup-manager.py" "${@:2}" ;;
  workspace-template) bash "${DOTFILES_DIR}/scripts/system/workspace-template.sh" "${@:2}" ;;
  seed)       bash "${DOTFILES_DIR}/scripts/seed.sh" ;;
  backup)     bash "${DOTFILES_DIR}/scripts/maintenance/backup.sh" "${@:2}" ;;
  rollback)   bash "${DOTFILES_DIR}/scripts/rollback.sh" "${@:2}" ;;
  recover|fallback-hypr) bash "${DOTFILES_DIR}/scripts/recover-hypr.sh" "${@:2}" ;;
  screenshots) bash "${DOTFILES_DIR}/scripts/system/capture-screenshots.sh" "${@:2}" ;;
  theme)      bash "${DOTFILES_DIR}/scripts/theme/switch-wallpaper.sh" "${@:2}" ;;
  test)       python3 "${DOTFILES_DIR}/scripts/quality.py" all ;;
  help|--help|-h)
    echo "lumina-dots CLI"
    echo ""
    echo "Usage: dotfiles <command>"
    echo ""
    echo "Commands:"
    echo "  install             Run the full lumina-dots installer"
    echo "  update              Pull latest dotfiles and update packages"
    echo "  doctor              Run health check and diagnose issues"
    echo "  doctor-dashboard    Launch graphical doctor dashboard"
    echo "  validate            Run runtime validation checks"
    echo "  status              Print host, wallpaper, theme, and service status"
    echo "  shell [status|osd]  Inspect or control Lumina Shell"
    echo "  welcome             Launch or inspect Lumina Welcome"
    echo "  keybinds            Launch searchable keybind overlay"
    echo "  control             Launch Lumina Control Center"
    echo "  snapshot            Launch or inspect Snapshot Manager"
    echo "  activity            Launch or inspect Activity History"
    echo "  theme-studio        Launch or inspect Theme Studio"
    echo "  hub                 Launch Lumina Hub"
    echo "  mission-control     Launch Mission Control"
    echo "  ai                  Launch optional Lumina AI Assistant"
    echo "  pomodoro            Launch or inspect Pomodoro timer"
    echo "  cleanup             Launch Cleanup Manager"
    echo "  workspace-template  Launch a workspace template"
    echo "  seed                Copy fallback generated files into local config"
    echo "  backup              Create a manual Btrfs snapshot"
    echo "  rollback [args]     Offline Btrfs @ rollback helper (see: dotfiles rollback list)"
    echo "  recover             Launch fallback Hyprland config"
    echo "  screenshots         Capture showcase screenshots"
    echo "  theme <wallpaper>   Apply Matugen theme from a wallpaper image"
    echo "  test                Run test suite"
    echo "  help                Show this help"
    ;;
  *)
    echo "Unknown command: ${1:-}. Run 'dotfiles help'."
    exit 1
    ;;
esac
DOTFILES_CLI_EOF

sudo chmod +x "${DOTFILES_BIN}"
log::success "'dotfiles' command installed at ${DOTFILES_BIN}"

log::success "Dotfiles symlinking complete"
