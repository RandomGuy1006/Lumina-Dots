#!/usr/bin/env bash
# lib/log.sh — Logging utilities for lumina-dots scripts
# Source this file: source "$(dirname "$0")/../lib/log.sh"
set -euo pipefail

# ─── Colors ───────────────────────────────────────────────────────────────────
# shellcheck disable=SC2034
if [[ -t 1 ]]; then
  CLR_RESET='\033[0m'
  CLR_BOLD='\033[1m'
  CLR_DIM='\033[2m'
  CLR_RED='\033[0;31m'
  CLR_GREEN='\033[0;32m'
  CLR_YELLOW='\033[0;33m'
  CLR_BLUE='\033[0;34m'
  CLR_MAGENTA='\033[0;35m'
  CLR_CYAN='\033[0;36m'
  CLR_WHITE='\033[0;37m'
  CLR_BOLD_RED='\033[1;31m'
  CLR_BOLD_GREEN='\033[1;32m'
  CLR_BOLD_YELLOW='\033[1;33m'
  CLR_BOLD_BLUE='\033[1;34m'
  CLR_BOLD_CYAN='\033[1;36m'
else
  CLR_RESET=''
  CLR_BOLD=''
  CLR_DIM=''
  CLR_RED=''
  CLR_GREEN=''
  CLR_YELLOW=''
  CLR_BLUE=''
  CLR_MAGENTA=''
  CLR_CYAN=''
  CLR_WHITE=''
  CLR_BOLD_RED=''
  CLR_BOLD_GREEN=''
  CLR_BOLD_YELLOW=''
  CLR_BOLD_BLUE=''
  CLR_BOLD_CYAN=''
fi

# ─── Log File Setup ────────────────────────────────────────────────────────────
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
LOQDOTS_ROOT="${LOQDOTS_ROOT:-$DOTFILES_DIR}"
LOG_DIR="${DOTFILES_DIR}/logs"
LOG_FILE="${LOG_FILE:-${LOG_DIR}/install-$(date +%Y%m%d-%H%M%S).log}"

mkdir -p "${LOG_DIR}"
export DOTFILES_DIR LOQDOTS_ROOT LOG_FILE

# ─── Internal: write to log file ───────────────────────────────────────────────
_log_to_file() {
  local level="$1"
  shift
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [${level}] $*" >>"${LOG_FILE}"
}

# ─── Public log functions ───────────────────────────────────────────────────────

log::header() {
  local msg="$*"
  local width=70
  local line
  line=$(printf '%*s' "${width}" '' | tr ' ' '─')
  echo ""
  echo -e "${CLR_BOLD_BLUE}${line}${CLR_RESET}"
  echo -e "${CLR_BOLD_BLUE}  ◆  ${msg}${CLR_RESET}"
  echo -e "${CLR_BOLD_BLUE}${line}${CLR_RESET}"
  echo ""
  _log_to_file "HEADER" "${msg}"
}

log::section() {
  echo ""
  echo -e "${CLR_BOLD_CYAN}▸ $*${CLR_RESET}"
  _log_to_file "SECTION" "$*"
}

log::info() {
  echo -e "${CLR_BLUE}  ℹ  ${CLR_RESET}$*"
  _log_to_file "INFO" "$*"
}

log::success() {
  echo -e "${CLR_BOLD_GREEN}  ✓  ${CLR_RESET}$*"
  _log_to_file "SUCCESS" "$*"
}

log::warn() {
  echo -e "${CLR_BOLD_YELLOW}  ⚠  ${CLR_RESET}$*" >&2
  _log_to_file "WARN" "$*"
}

log::error() {
  echo -e "${CLR_BOLD_RED}  ✗  ${CLR_RESET}$*" >&2
  _log_to_file "ERROR" "$*"
}

log::fatal() {
  echo -e "${CLR_BOLD_RED}  ✗  FATAL: ${CLR_RESET}$*" >&2
  _log_to_file "FATAL" "$*"
  exit 1
}

log::step() {
  echo -e "${CLR_DIM}      → $*${CLR_RESET}"
  _log_to_file "STEP" "$*"
}

log::prompt() {
  echo -e "${CLR_BOLD_YELLOW}  ?  ${CLR_RESET}$*"
}

log::dim() {
  echo -e "${CLR_DIM}  $*${CLR_RESET}"
  _log_to_file "DEBUG" "$*"
}

# Print a separator line
log::sep() {
  echo -e "${CLR_DIM}      ─────────────────────────────────────${CLR_RESET}"
}

# ─── Spinner (for long operations) ─────────────────────────────────────────────
log::spinner_start() {
  local msg="${1:-Working...}"
  local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  local i=0
  # Spin in background, save PID
  (
    while true; do
      printf "\r${CLR_CYAN}  %s  ${CLR_RESET}%s" "${frames[$((i % ${#frames[@]}))]}" "${msg}"
      sleep 0.1
      ((i++)) || true
    done
  ) &
  SPINNER_PID=$!
}

log::spinner_stop() {
  if [[ -n "${SPINNER_PID:-}" ]]; then
    kill "${SPINNER_PID}" 2>/dev/null
    wait "${SPINNER_PID}" 2>/dev/null
    printf "\r%*s\r" "$(tput cols)" ""
    unset SPINNER_PID
  fi
}

# ─── Progress counter ───────────────────────────────────────────────────────────
log::progress() {
  local current="$1"
  local total="$2"
  local msg="${3:-}"
  local pct=$((current * 100 / total))
  local bar_width=30
  local filled=$((bar_width * current / total))
  local empty=$((bar_width - filled))
  local bar
  bar="$(printf '%*s' "${filled}" '' | tr ' ' '█')$(printf '%*s' "${empty}" '' | tr ' ' '░')"
  printf "\r${CLR_BOLD_BLUE}  [%s] %3d%%  ${CLR_RESET}%s" "${bar}" "${pct}" "${msg}"
  if [[ "${current}" -eq "${total}" ]]; then
    echo ""
  fi
}
