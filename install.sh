#!/usr/bin/env bash
# lumina-dots — Main install orchestrator
# Usage: bash install.sh [install|doctor|status|update|rollback|theme|test] [options]
#
# Modes:
#   full          Install everything (default)
#   dotfiles-only Only symlink configs, skip system packages
#   packages-only Only install packages, skip symlinking
#   hardware-only Only apply hardware-specific tuning
#
# Hosts:
#   loq-15irx9    Lenovo LOQ 15IRX9 (default auto-detected)
#   generic       Generic Hyprland system

set -euo pipefail

# ─── Resolve dotfiles directory ────────────────────────────────────────────────
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES_DIR

for arg in "$@"; do
  if [[ "${arg}" == "--dry-run" ]]; then
    export LOG_FILE="${TMPDIR:-/tmp}/lumina-dots-dry-run-$(date +%Y%m%d-%H%M%S).log"
    break
  fi
done

# ─── Source libraries ──────────────────────────────────────────────────────────
# shellcheck source=lib/log.sh
source "${DOTFILES_DIR}/lib/log.sh"
# shellcheck source=lib/pkg.sh
source "${DOTFILES_DIR}/lib/pkg.sh"
# shellcheck source=lib/link.sh
source "${DOTFILES_DIR}/lib/link.sh"
# shellcheck source=lib/check.sh
source "${DOTFILES_DIR}/lib/check.sh"
# shellcheck source=lib/aur.sh
source "${DOTFILES_DIR}/lib/aur.sh"
# shellcheck source=lib/host.sh
source "${DOTFILES_DIR}/lib/host.sh"

trap 'log::error "Install interrupted. Completed phases are designed to be re-run safely."; exit 130' INT TERM
trap 'status=$?; log::error "Install failed with exit ${status}. Fix the reported issue and re-run the same command."; exit "${status}"' ERR

# ─── Parse arguments ───────────────────────────────────────────────────────────
usage() {
  cat <<'EOF'
Usage:
  bash install.sh [install|all|full] [--dry-run] [--host=loq-15irx9|generic]
  bash install.sh dotfiles-only|stow [--host=loq-15irx9|generic]
  bash install.sh packages-only|packages [--host=loq-15irx9|generic]
  bash install.sh hardware-only|hardware [--host=loq-15irx9|generic]
  bash install.sh doctor
  bash install.sh validate [all|services|themes]
  bash install.sh doctor-dashboard
  bash install.sh status
  bash install.sh shell [status|osd]
  bash install.sh welcome
  bash install.sh keybinds
  bash install.sh control
  bash install.sh snapshot [list|create]
  bash install.sh activity [--json|--clear]
  bash install.sh theme-studio [list|preview|apply]
  bash install.sh hub [--json|--launch]
  bash install.sh mission-control [--json|--workspace|--focus]
  bash install.sh ai [prompt]
  bash install.sh pomodoro [start|break|stop|status]
  bash install.sh cleanup [--json|--run]
  bash install.sh workspace-template <name>
  bash install.sh seed
  bash install.sh recover
  bash install.sh update [--skip-packages] [--skip-dotfiles]
  bash install.sh backup [description]
  bash install.sh theme <wallpaper> [transition]
  bash install.sh rollback list
  bash install.sh rollback <snapshot-id|last> <btrfs-device>
  bash install.sh test

Host aliases accepted for the LOQ profile: loq, loq15irx9, loq-15irx9.
EOF
}

DRY_RUN=false
MODE="full"
COMMAND="install"
HOST_PROFILE=""
REBOOT_REQUIRED_EXIT_CODE=20
POSITIONAL_ARGS=()

if [[ $# -gt 0 && "${1}" != --* ]]; then
  case "${1}" in
    install | all | full)
      COMMAND="install"
      MODE="full"
      shift
      ;;
    dotfiles-only | stow | link)
      COMMAND="install"
      MODE="dotfiles-only"
      shift
      ;;
    packages-only | packages)
      COMMAND="install"
      MODE="packages-only"
      shift
      ;;
    hardware-only | hardware)
      COMMAND="install"
      MODE="hardware-only"
      shift
      ;;
    doctor | validate | doctor-dashboard | doctor-gui | status | shell | welcome | keybinds | control | snapshot | activity | theme-studio | hub | mission-control | mission | ai | pomodoro | cleanup | workspace-template | seed | recover | fallback-hypr | screenshots | update | backup | rollback | theme | wallpaper | test | help)
      COMMAND="${1}"
      shift
      ;;
    -h | --help)
      COMMAND="help"
      shift
      ;;
    *)
      log::fatal "Unknown command: ${1}. Run: bash install.sh help"
      ;;
  esac
fi

for arg in "$@"; do
  case "${arg}" in
    --dry-run) DRY_RUN=true ;;
    --mode=*) MODE="${arg#*=}" ;;
    --host=*) HOST_PROFILE="${arg#*=}" ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      POSITIONAL_ARGS+=("${arg}")
      ;;
  esac
done

export DRY_RUN MODE
if [[ "${DRY_RUN}" == "true" ]]; then
  export LUMINA_DRY_RUN=1
  log::warn "DRY RUN mode — install phases will be previewed where supported"
fi
export REBOOT_REQUIRED_EXIT_CODE

if [[ -z "${HOST_PROFILE}" ]]; then
  HOST_PROFILE="$(host::detect)"
fi
HOST_PROFILE="$(host::canonical "${HOST_PROFILE}")"
export HOST_PROFILE

case "${COMMAND}" in
  help)
    usage
    exit 0
    ;;
  doctor)
    exec bash "${DOTFILES_DIR}/scripts/doctor.sh" "${POSITIONAL_ARGS[@]}"
    ;;
  validate)
    exec bash "${DOTFILES_DIR}/scripts/validate.sh" "${POSITIONAL_ARGS[@]}"
    ;;
  doctor-dashboard | doctor-gui)
    exec python3 "${DOTFILES_DIR}/apps/doctor-dashboard/lumina-doctor-dashboard.py" "${POSITIONAL_ARGS[@]}"
    ;;
  status)
    exec bash "${DOTFILES_DIR}/scripts/status.sh" "${POSITIONAL_ARGS[@]}"
    ;;
  shell)
    exec python3 "${DOTFILES_DIR}/apps/shell/lumina-shell.py" "${POSITIONAL_ARGS[@]}"
    ;;
  welcome)
    exec python3 "${DOTFILES_DIR}/apps/welcome/lumina-welcome.py" "${POSITIONAL_ARGS[@]}"
    ;;
  keybinds)
    exec python3 "${DOTFILES_DIR}/apps/keybind-overlay/lumina-keybind-overlay.py" "${POSITIONAL_ARGS[@]}"
    ;;
  control)
    exec python3 "${DOTFILES_DIR}/apps/control-center/lumina-control-center.py" "${POSITIONAL_ARGS[@]}"
    ;;
  snapshot)
    exec python3 "${DOTFILES_DIR}/apps/snapshot-manager/lumina-snapshot-manager.py" "${POSITIONAL_ARGS[@]}"
    ;;
  activity)
    exec python3 "${DOTFILES_DIR}/apps/activity-history/lumina-activity-history.py" "${POSITIONAL_ARGS[@]}"
    ;;
  theme-studio)
    exec python3 "${DOTFILES_DIR}/apps/theme-studio/lumina-theme-studio.py" "${POSITIONAL_ARGS[@]}"
    ;;
  hub)
    exec python3 "${DOTFILES_DIR}/apps/lumina-hub/lumina-hub.py" "${POSITIONAL_ARGS[@]}"
    ;;
  mission-control | mission)
    exec python3 "${DOTFILES_DIR}/apps/mission-control/lumina-mission-control.py" "${POSITIONAL_ARGS[@]}"
    ;;
  ai)
    exec python3 "${DOTFILES_DIR}/apps/lumina-ai/lumina-ai.py" "${POSITIONAL_ARGS[@]}"
    ;;
  pomodoro)
    exec python3 "${DOTFILES_DIR}/apps/pomodoro/lumina-pomodoro.py" "${POSITIONAL_ARGS[@]}"
    ;;
  cleanup)
    exec python3 "${DOTFILES_DIR}/apps/cleanup-manager/lumina-cleanup-manager.py" "${POSITIONAL_ARGS[@]}"
    ;;
  workspace-template)
    exec bash "${DOTFILES_DIR}/scripts/system/workspace-template.sh" "${POSITIONAL_ARGS[@]}"
    ;;
  seed)
    exec bash "${DOTFILES_DIR}/scripts/seed.sh" "${POSITIONAL_ARGS[@]}"
    ;;
  recover | fallback-hypr)
    exec bash "${DOTFILES_DIR}/scripts/recover-hypr.sh" "${POSITIONAL_ARGS[@]}"
    ;;
  screenshots)
    exec bash "${DOTFILES_DIR}/scripts/system/capture-screenshots.sh" "${POSITIONAL_ARGS[@]}"
    ;;
  update)
    exec bash "${DOTFILES_DIR}/update.sh" "${POSITIONAL_ARGS[@]}"
    ;;
  backup)
    exec bash "${DOTFILES_DIR}/scripts/maintenance/backup.sh" "${POSITIONAL_ARGS[@]}"
    ;;
  rollback)
    exec bash "${DOTFILES_DIR}/scripts/rollback.sh" "${POSITIONAL_ARGS[@]}"
    ;;
  theme | wallpaper)
    exec bash "${DOTFILES_DIR}/scripts/theme/switch-wallpaper.sh" "${POSITIONAL_ARGS[@]}"
    ;;
  test)
    bash "${DOTFILES_DIR}/tests/validate-repo.sh"
    bash "${DOTFILES_DIR}/tests/validate-docs.sh"
    python3 "${DOTFILES_DIR}/tests/validate-lumina-core.py"
    python3 "${DOTFILES_DIR}/tests/validate-lumina-architecture.py"
    python3 "${DOTFILES_DIR}/tests/test-lumina-phase2.py"
    python3 "${DOTFILES_DIR}/tests/test-lumina-phase3.py"
    python3 "${DOTFILES_DIR}/tests/test-lumina-phase4.py"
    python3 "${DOTFILES_DIR}/tests/test-lumina-phase5.py"
    python3 "${DOTFILES_DIR}/tests/test-lumina-phase6.py"
    bash "${DOTFILES_DIR}/tests/test-regressions.sh"
    bash "${DOTFILES_DIR}/tests/test-links.sh"
    bash "${DOTFILES_DIR}/tests/test-services.sh"
    bash "${DOTFILES_DIR}/tests/test-theme.sh"
    bash "${DOTFILES_DIR}/tests/test-hardware.sh"
    exit 0
    ;;
  install)
    ;;
  *)
    log::fatal "Unknown command: ${COMMAND}. Run: bash install.sh help"
    ;;
esac

# ─── Banner ─────────────────────────────────────────────────────────────────────
clear
echo ""
echo -e "\033[1;36m"
cat <<'EOF'
  ██╗     ██╗   ██╗███╗   ███╗██╗███╗   ██╗ █████╗
  ██║     ██║   ██║████╗ ████║██║████╗  ██║██╔══██╗
  ██║     ██║   ██║██╔████╔██║██║██╔██╗ ██║███████║
  ██║     ██║   ██║██║╚██╔╝██║██║██║╚██╗██║██╔══██║
  ███████╗╚██████╔╝██║ ╚═╝ ██║██║██║ ╚████║██║  ██║
  ╚══════╝ ╚═════╝ ╚═╝     ╚═╝╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝
EOF
echo -e "\033[0m"
echo -e "\033[1;34m  Production-grade Hyprland dotfiles for Arch Linux\033[0m"
echo -e "\033[2m  Mode: ${MODE} | Host: ${HOST_PROFILE} | Dry-run: ${DRY_RUN}\033[0m"
echo ""

# ─── Dry-run wrapper ───────────────────────────────────────────────────────────
run_step() {
  local script="$1"
  local label="${2:-${script}}"
  local exit_code=0

  if [[ "${DRY_RUN}" == "true" ]]; then
    log::info "[DRY-RUN] Would run: ${script}"
    return 0
  fi

  if [[ ! -f "${DOTFILES_DIR}/${script}" ]]; then
    log::fatal "Install script not found: ${DOTFILES_DIR}/${script}"
  fi

  bash "${DOTFILES_DIR}/${script}" || exit_code=$?
  return "${exit_code}"
}

run_step_or_exit() {
  local script="$1"
  local label="${2:-${script}}"
  local status=0

  run_step "${script}" "${label}" || status=$?

  if [[ "${status}" -eq 0 ]]; then
    return 0
  fi

  if [[ "${status}" -eq "${REBOOT_REQUIRED_EXIT_CODE}" ]]; then
    log::header "Reboot Required"
    echo ""
    echo -e "  \033[1;33m${label} changed a reboot-sensitive setting.\033[0m"
    echo -e "  \033[2mReboot now, then re-run: bash install.sh --mode=${MODE} --host=${HOST_PROFILE}\033[0m"
    echo ""
    exit 0
  fi

  exit "${status}"
}

# ─── Run installation phases ────────────────────────────────────────────────────
log::header "lumina-dots Installation — v$(cat "${DOTFILES_DIR}/.version")"

# Always run prechecks
check::all

case "${MODE}" in
  full)
    run_step_or_exit "scripts/install/01-system.sh" "System setup"
    run_step_or_exit "scripts/install/02-packages.sh" "Package installation"
    run_step_or_exit "scripts/install/03-dotfiles.sh" "Dotfiles symlinking"
    run_step_or_exit "scripts/install/04-theme.sh" "Theme initialization"
    run_step_or_exit "scripts/install/05-hardware.sh" "Hardware-specific tuning"
    run_step_or_exit "scripts/install/06-services.sh" "Systemd service setup"
    ;;
  dotfiles-only)
    run_step_or_exit "scripts/install/03-dotfiles.sh" "Dotfiles symlinking"
    run_step_or_exit "scripts/install/04-theme.sh" "Theme initialization"
    ;;
  packages-only)
    run_step_or_exit "scripts/install/02-packages.sh" "Package installation"
    ;;
  hardware-only)
    run_step_or_exit "scripts/install/05-hardware.sh" "Hardware-specific tuning"
    ;;
  *)
    log::fatal "Unknown mode: ${MODE}. Use: full, dotfiles-only, packages-only, hardware-only"
    ;;
esac

# ─── Post-install summary ───────────────────────────────────────────────────────
if [[ "${DRY_RUN}" == "true" ]]; then
  log::header "Dry Run Complete"
else
  log::header "Installation Complete"
fi
echo ""
if [[ "${DRY_RUN}" == "true" ]]; then
  echo -e "  \033[1;32m✓\033[0m  lumina-dots install preview completed"
else
  echo -e "  \033[1;32m✓\033[0m  lumina-dots installed successfully"
fi
echo -e "  \033[1;32m✓\033[0m  Host profile: ${HOST_PROFILE}"
echo -e "  \033[1;32m✓\033[0m  Log file: ${LOG_FILE}"
echo ""
if [[ "${DRY_RUN}" == "true" ]]; then
  echo -e "  \033[1;33mNext step:\033[0m"
  echo -e "    Re-run without \033[1m--dry-run\033[0m when you are ready to apply changes"
else
  echo -e "  \033[1;33mNext steps:\033[0m"
  echo -e "    1. Reboot your system"
  echo -e "    2. Log in via TTY (autologin will start Hyprland)"
  echo -e "    3. Run: \033[1mdotfiles doctor\033[0m  to verify system health"
  echo -e "    4. Set your wallpaper: \033[1mdotfiles theme ~/Pictures/wallpaper.jpg\033[0m"
fi
echo ""
echo -e "  \033[2m  Documentation: ${DOTFILES_DIR}/docs\033[0m"
echo ""
