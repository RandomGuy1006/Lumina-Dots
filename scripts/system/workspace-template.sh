#!/usr/bin/env bash
set -euo pipefail

ROOT="${LOQDOTS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
# shellcheck source=../../lib/common.sh
source "${ROOT}/lib/common.sh"

template="${1:-dev}"
if [[ ! "${template}" =~ ^[A-Za-z0-9_-]+$ ]]; then
  fail "Invalid workspace template identifier: ${template}"
  exit 1
fi

config_home="${LUMINA_CONFIG_HOME:-${HOME}/.config/lumina}"
file="${config_home}/workspace-templates/${template}.toml"

if [[ ! -f "${file}" ]]; then
  fail "Workspace template not found: ${file}"
  exit 1
fi

workspace=""
while IFS= read -r line; do
  case "${line}" in
    workspace\ =*)
      workspace="${line#*=}"
      workspace="${workspace//\"/}"
      workspace="${workspace// /}"
      ;;
    command\ =*)
      command_text="${line#*=}"
      command_text="${command_text# }"
      command_text="${command_text%\"}"
      command_text="${command_text#\"}"
      [[ -n "${workspace}" ]] && hyprctl dispatch workspace "${workspace}" >/dev/null 2>&1 || true
      if [[ -n "${command_text}" ]]; then
        mapfile -t _argv < <(
          python3 -c "import shlex,sys; [print(t) for t in shlex.split(sys.argv[1])]" \
            "${command_text}"
        )
        [[ "${#_argv[@]}" -gt 0 ]] || continue
        if command -v uwsm >/dev/null 2>&1; then
          uwsm app -- "${_argv[@]}" >/dev/null 2>&1 &
          disown
        else
          "${_argv[@]}" >/dev/null 2>&1 &
          disown
        fi
      fi
      ;;
  esac
done <"${file}"
