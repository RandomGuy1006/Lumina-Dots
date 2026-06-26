#!/usr/bin/env bash
# lib/aur.sh — AUR helper wrapper for lumina-dots
# Wraps paru with consistent behavior
# Requires: lib/log.sh sourced first
set -euo pipefail

# Ensure paru exists, build from AUR if not
aur::ensure_paru() {
  if command -v paru &>/dev/null; then
    log::success "paru $(paru --version | head -1 | awk '{print $2}') already installed"
    return 0
  fi

  log::section "Building paru from AUR"
  log::info "This requires base-devel and git (installing if missing)..."
  sudo pacman -S --needed --noconfirm base-devel git

  local tmpdir
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "${tmpdir}"' RETURN

  git clone --depth=1 https://aur.archlinux.org/paru-bin.git "${tmpdir}/paru-bin"
  (cd "${tmpdir}/paru-bin" && makepkg -si --noconfirm)

  if command -v paru &>/dev/null; then
    log::success "paru installed"
  else
    log::fatal "paru installation failed"
  fi
}

# Install from AUR with paru
aur::install() {
  local -a pkgs=("$@")
  if ! command -v paru &>/dev/null; then
    log::fatal "paru not found. Run aur::ensure_paru first."
  fi

  local -a to_install=()
  for pkg in "${pkgs[@]}"; do
    if ! pacman -Qi "${pkg}" &>/dev/null; then
      to_install+=("${pkg}")
    else
      log::dim "AUR: already installed: ${pkg}"
    fi
  done

  if [[ ${#to_install[@]} -eq 0 ]]; then
    return 0
  fi

  log::step "paru -S ${to_install[*]}"
  paru -S --needed --noconfirm "${to_install[@]}"
}

# Update all AUR packages
aur::update() {
  log::step "Updating AUR packages..."
  paru -Su --noconfirm --aur
}

# Search AUR (informational)
aur::search() {
  paru -Ss "$@"
}
