#!/usr/bin/env bash
# Lightweight UFW profiles for local development without exposing services broadly.
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "${DOTFILES_DIR}/lib/log.sh"

usage() {
  cat <<'EOF'
Usage: lumina-firewall <status|workstation|dev-lan|lockdown>

Profiles:
  workstation  deny inbound, allow outbound, allow SSH only from RFC1918 LANs
  dev-lan      workstation + allow common dev ports from LAN only
  lockdown     deny inbound, allow outbound, remove broad dev allowances
EOF
}

require_ufw() {
  command -v ufw >/dev/null 2>&1 || log::fatal "ufw is not installed"
}

allow_lan() {
  local port="$1"
  local proto="${2:-tcp}"

  for cidr in 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16; do
    sudo ufw allow from "${cidr}" to any port "${port}" proto "${proto}" >/dev/null
  done
}

profile="${1:-status}"
require_ufw

case "${profile}" in
  status)
    sudo ufw status verbose
    ;;
  workstation)
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    allow_lan 22 tcp
    sudo ufw --force enable
    log::success "UFW workstation profile active"
    ;;
  dev-lan)
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    allow_lan 22 tcp
    for port in 3000 5173 8000 8080 11434; do
      allow_lan "${port}" tcp
    done
    sudo ufw --force enable
    log::success "UFW dev-lan profile active"
    ;;
  lockdown)
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    for port in 3000 5173 8000 8080 11434; do
      sudo ufw delete allow "${port}/tcp" >/dev/null 2>&1 || true
    done
    sudo ufw --force enable
    log::success "UFW lockdown profile active"
    ;;
  help | --help | -h)
    usage
    ;;
  *)
    usage
    exit 1
    ;;
esac
