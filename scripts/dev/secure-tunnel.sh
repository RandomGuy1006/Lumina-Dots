#!/usr/bin/env bash
# Safe SSH tunnel helper: binds forwards to localhost and fails closed.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  lumina-tunnel forward <host> <local-port> <remote-host:remote-port>
  lumina-tunnel reverse <host> <remote-port> <local-host:local-port>
  lumina-tunnel socks <host> <local-port>

Examples:
  lumina-tunnel forward devbox 15432 127.0.0.1:5432
  lumina-tunnel reverse devbox 9000 127.0.0.1:5173
  lumina-tunnel socks devbox 1080
EOF
}

mode="${1:-}"
host="${2:-}"
[[ -n "${mode}" && -n "${host}" ]] || {
  usage
  exit 1
}

common_opts=(
  -N
  -o ExitOnForwardFailure=yes
  -o ServerAliveInterval=30
  -o ServerAliveCountMax=2
)

case "${mode}" in
  forward)
    local_port="${3:-}"
    remote="${4:-}"
    [[ -n "${local_port}" && -n "${remote}" ]] || {
      usage
      exit 1
    }
    exec ssh "${common_opts[@]}" -L "127.0.0.1:${local_port}:${remote}" "${host}"
    ;;
  reverse)
    remote_port="${3:-}"
    local_target="${4:-}"
    [[ -n "${remote_port}" && -n "${local_target}" ]] || {
      usage
      exit 1
    }
    exec ssh "${common_opts[@]}" -R "127.0.0.1:${remote_port}:${local_target}" "${host}"
    ;;
  socks)
    local_port="${3:-1080}"
    exec ssh "${common_opts[@]}" -D "127.0.0.1:${local_port}" "${host}"
    ;;
  help | --help | -h)
    usage
    ;;
  *)
    usage
    exit 1
    ;;
esac
