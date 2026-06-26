#!/usr/bin/env bash
# Install current-Arch compatibility wrappers while keeping the runtime API named swww.
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "${DOTFILES_DIR}/lib/log.sh"

install_wrapper() {
  local target="$1"
  local backend="$2"
  local backend_path

  if command -v "${target}" >/dev/null 2>&1; then
    log::dim "${target} already exists"
    return 0
  fi

  backend_path="$(command -v "${backend}" 2>/dev/null || true)"
  if [[ -z "${backend_path}" ]]; then
    log::warn "Cannot create ${target} wrapper; ${backend} is missing"
    return 0
  fi

  sudo tee "/usr/local/bin/${target}" >/dev/null <<EOF
#!/usr/bin/env bash
exec ${backend_path@Q} "\$@"
EOF
  sudo chmod 0755 "/usr/local/bin/${target}"
  log::success "Installed ${target} compatibility wrapper -> ${backend}"
}

install_wrapper swww awww
install_wrapper swww-daemon awww-daemon
