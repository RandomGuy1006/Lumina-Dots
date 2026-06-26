#!/usr/bin/env bash
# lib/pkg.sh — Package installation helpers for lumina-dots
# Requires: lib/log.sh sourced first
set -euo pipefail

# ─── Check if a package is installed ───────────────────────────────────────────
pkg::canonical_pacman_name() {
  case "$1" in
    swww) printf '%s\n' "awww" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

pkg::is_installed() {
  pacman -Qi "$(pkg::canonical_pacman_name "$1")" &>/dev/null
}

# ─── Install pacman packages (idempotent) ───────────────────────────────────────
pkg::pacman() {
  local -a pkgs=("$@")
  local -a to_install=()
  local resolved_pkg

  for pkg in "${pkgs[@]}"; do
    resolved_pkg="$(pkg::canonical_pacman_name "${pkg}")"
    if ! pkg::is_installed "${pkg}"; then
      to_install+=("${resolved_pkg}")
    else
      log::dim "Already installed: ${pkg}"
    fi
  done

  if [[ ${#to_install[@]} -eq 0 ]]; then
    log::success "All pacman packages already installed"
    return 0
  fi

  log::step "Installing via pacman: ${to_install[*]}"
  if ! sudo pacman -S --needed --noconfirm "${to_install[@]}"; then
    log::error "pacman failed for: ${to_install[*]}"
    return 1
  fi
  log::success "Installed: ${to_install[*]}"
}

# ─── Install AUR packages via paru (idempotent) ─────────────────────────────────
pkg::aur() {
  local -a pkgs=("$@")
  local -a to_install=()

  if ! command -v paru &>/dev/null; then
    log::fatal "paru not found. Install paru first (scripts/install/01-system.sh)"
  fi

  for pkg in "${pkgs[@]}"; do
    if ! pkg::is_installed "${pkg}"; then
      to_install+=("${pkg}")
    else
      log::dim "Already installed (AUR): ${pkg}"
    fi
  done

  if [[ ${#to_install[@]} -eq 0 ]]; then
    log::success "All AUR packages already installed"
    return 0
  fi

  log::step "Installing via paru (AUR): ${to_install[*]}"
  if ! paru -S --needed --noconfirm "${to_install[@]}"; then
    log::error "paru failed for: ${to_install[*]}"
    return 1
  fi
  log::success "Installed (AUR): ${to_install[*]}"
}

# ─── Install packages from a manifest file ─────────────────────────────────────
# File format: one package per line, # comments ignored, blank lines ignored
pkg::from_file() {
  local file="$1"
  local use_aur="${2:-false}"

  if [[ ! -f "${file}" ]]; then
    log::error "Package file not found: ${file}"
    return 1
  fi

  local -a pkgs=()
  while IFS= read -r line; do
    # Strip comments and whitespace
    line="${line%%#*}"
    line="${line//[$'\t\r\n ']/}"
    [[ -z "${line}" ]] && continue
    pkgs+=("${line}")
  done <"${file}"

  if [[ ${#pkgs[@]} -eq 0 ]]; then
    log::warn "No packages found in ${file}"
    return 0
  fi

  log::info "Loading ${#pkgs[@]} packages from ${file##*/}"

  if [[ "${use_aur}" == "true" ]]; then
    pkg::aur "${pkgs[@]}"
  else
    pkg::pacman "${pkgs[@]}"
  fi
}

# ─── Remove packages (idempotent) ──────────────────────────────────────────────
pkg::remove() {
  local -a pkgs=("$@")
  local -a to_remove=()

  for pkg in "${pkgs[@]}"; do
    if pkg::is_installed "${pkg}"; then
      to_remove+=("${pkg}")
    else
      log::dim "Not installed (skip remove): ${pkg}"
    fi
  done

  if [[ ${#to_remove[@]} -eq 0 ]]; then
    return 0
  fi

  log::step "Removing: ${to_remove[*]}"
  sudo pacman -Rns --noconfirm "${to_remove[@]}"
}

# ─── Check for conflicting packages ────────────────────────────────────────────
# Usage: pkg::conflict_check "dunst" "mako" "notification-daemon"
pkg::conflict_check() {
  local -a conflicts=("$@")
  local found=false

  for pkg in "${conflicts[@]}"; do
    if pkg::is_installed "${pkg}"; then
      log::warn "Conflicting package installed: ${pkg}"
      found=true
    fi
  done

  if [[ "${found}" == "true" ]]; then
    log::warn "Conflicting notification/bar daemons may cause issues with Hyprpanel."
    log::warn "Remove them with: sudo pacman -Rns ${conflicts[*]}"
    return 1
  fi
  return 0
}
