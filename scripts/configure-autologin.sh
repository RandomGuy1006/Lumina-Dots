#!/usr/bin/env bash
set -euo pipefail

ROOT="${LOQDOTS_ROOT:-${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}}"
DOTFILES_DIR="${DOTFILES_DIR:-$ROOT}"
LOQDOTS_ROOT="${LOQDOTS_ROOT:-$DOTFILES_DIR}"
export DOTFILES_DIR LOQDOTS_ROOT
source "$ROOT/lib/common.sh"

load_host_profile
step "Configuring tty1 autologin"

local_dir="$(mktemp -d)"
trap 'rm -rf "$local_dir"' EXIT
cat >"$local_dir/override.conf" <<EOF
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin $USER --noclear %I \$TERM
Type=idle
EOF

install_root_file "$local_dir/override.conf" "/etc/systemd/system/getty@tty1.service.d/override.conf"

if unit_exists greetd.service; then
  sudo systemctl disable --now greetd.service >/dev/null 2>&1 || true
  pass "Disabled greetd in favor of tty1 autologin"
fi

sudo systemctl daemon-reload
pass "tty1 autologin configured"
