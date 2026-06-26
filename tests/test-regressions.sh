#!/usr/bin/env bash
# tests/test-regressions.sh — Regression coverage for previously reported bugs
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${DOTFILES_DIR}/lib/log.sh"
source "${DOTFILES_DIR}/lib/link.sh"
source "${DOTFILES_DIR}/lib/host.sh"

log::header "Test: Regression Coverage"

ERRORS=0
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "${TMP_ROOT}"' EXIT

check() {
  log::success "$1"
}

fail() {
  log::error "$1"
  ((ERRORS++)) || true
}

# ─── Directory-backed config trees stay real directories ─────────────────────
ORIGINAL_HOME="${HOME}"
export HOME="${TMP_ROOT}/home"
export HOST_PROFILE="generic"
mkdir -p "${HOME}"

link::all

if [[ -d "${HOME}/.config/hypr" ]] && [[ ! -L "${HOME}/.config/hypr" ]]; then
  check "Hypr config root remains a real directory"
else
  fail "${HOME}/.config/hypr should be a directory, not a symlink"
fi

if [[ -L "${HOME}/.config/hypr/hyprland.conf" ]]; then
  check "Hyprland config file is linked individually"
else
  fail "hyprland.conf should be an individual symlink"
fi

echo "runtime" >"${HOME}/.config/hypr/runtime-generated.conf"
if [[ ! -e "${DOTFILES_DIR}/hypr/.config/hypr/runtime-generated.conf" ]]; then
  check "Runtime files no longer spill back into the repo"
else
  fail "Runtime file unexpectedly appeared inside hypr/.config/hypr"
fi

if link::verify; then
  check "Managed symlink verification passes in an isolated home"
else
  fail "Managed symlink verification failed in an isolated home"
fi

export HOME="${ORIGINAL_HOME}"

# ─── Host profile defaults ───────────────────────────────────────────────────
unset NVIDIA_MODE SWWW_PIXEL_FORMAT
if host::load "loq-15irx9"; then
  [[ "${NVIDIA_MODE}" == "integrated" ]] &&
    check "LOQ host profile defaults to integrated GPU mode" ||
    fail "LOQ host profile should default NVIDIA_MODE to integrated"

  [[ -v SWWW_PIXEL_FORMAT && -z "${SWWW_PIXEL_FORMAT}" ]] &&
    check "LOQ host profile leaves legacy wallpaper pixel format on auto-detect by default" ||
    fail "LOQ host profile should define SWWW_PIXEL_FORMAT as an empty opt-in override"

else
  fail "Failed to load the LOQ host profile"
fi

# Hardware scripts are intentionally not sourced here. They write system files
# and can change GPU mode when run as root, so static checks cover those paths.

# ─── ZProfile logic is tested by validate-repo.sh ────────────────────────────

[[ "${ERRORS}" -eq 0 ]] &&
  log::success "Regression coverage passed" ||
  log::error "${ERRORS} regression check(s) failed"

exit "${ERRORS}"
