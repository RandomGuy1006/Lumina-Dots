#!/usr/bin/env bash
# lib/check.sh — Precondition checks for lumina-dots
# Requires: lib/log.sh sourced first
set -euo pipefail

# Check we are running on Arch Linux
check::arch_linux() {
  if [[ ! -f /etc/arch-release ]]; then
    log::fatal "Not an Arch Linux system. lumina-dots targets Arch Linux."
  fi
  log::success "Arch Linux detected"
}

# Check we are NOT running as root
check::not_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    log::fatal "Do not run install.sh as root. Run as a regular user with sudo access."
  fi
  log::success "Running as ${USER} (not root)"
}

# Check sudo works
check::sudo() {
  if ! sudo -n true 2>/dev/null; then
    if [[ "${LUMINA_DRY_RUN:-0}" == "1" || "${DRY_RUN:-false}" == "true" ]]; then
      log::warn "sudo access was not confirmed; a real install will require it"
      return 0
    fi

    log::info "Requesting sudo access..."
    if ! sudo true; then
      log::fatal "sudo access required. Add ${USER} to sudoers."
    fi
  fi
  log::success "sudo access confirmed"
}

# Check we have internet connectivity
check::internet() {
  if ! curl -fsSL --max-time 5 https://archlinux.org &>/dev/null; then
    log::fatal "No internet connection. Please connect before running install."
  fi
  log::success "Internet connection OK"
}

# Check required base tools are available
check::base_tools() {
  local -a required_cmds=(git curl wget make gcc pkg-config fakeroot)
  local -i missing=0

  for tool in "${required_cmds[@]}"; do
    if ! command -v "${tool}" &>/dev/null; then
      log::warn "Missing: ${tool}"
      ((missing++)) || true
    fi
  done

  if [[ ${missing} -gt 0 ]]; then
    if [[ "${LUMINA_DRY_RUN:-0}" == "1" || "${DRY_RUN:-false}" == "true" ]]; then
      log::info "[DRY-RUN] Would install missing base tools: git curl wget base-devel"
      return 0
    fi

    log::info "Installing missing base tools..."
    sudo pacman -S --needed --noconfirm git curl wget base-devel
  else
    log::success "Base tools OK"
  fi
}

# Check disk space (at least 10GB free in home)
check::disk_space() {
  local available_kb
  available_kb=$(df -k "${HOME}" | awk 'NR==2{print $4}')
  local required_kb=$((10 * 1024 * 1024)) # 10 GB

  if [[ "${available_kb}" -lt "${required_kb}" ]]; then
    log::warn "Less than 10GB free in ${HOME} ($((available_kb / 1024 / 1024))GB available)"
    log::warn "Continuing, but some operations may fail."
  else
    log::success "Disk space OK ($((available_kb / 1024 / 1024))GB free)"
  fi
}

# Check that the dotfiles dir is a proper git repo
check::git_repo() {
  local dotfiles_dir="${1:-${DOTFILES_DIR}}"
  if [[ ! -d "${dotfiles_dir}/.git" ]]; then
    log::warn "dotfiles directory is not a git repo: ${dotfiles_dir}"
    log::warn "Rollback and update features require git history."
  else
    log::success "Git repo OK: ${dotfiles_dir}"
  fi
}

# Run all standard precondition checks
check::all() {
  log::section "System precondition checks"
  check::arch_linux
  check::not_root
  check::sudo
  check::internet
  check::base_tools
  check::disk_space
  check::git_repo
}
