#!/usr/bin/env bash
# lib/host.sh — Host detection and profile loading helpers
set -euo pipefail

host::canonical() {
  case "${1:-}" in
    loq | loq15irx9 | loq-15IRX9 | loq-15irx9 | lenovo-loq | lenovo-loq-15irx9)
      printf '%s\n' "loq-15irx9"
      ;;
    generic | "")
      printf '%s\n' "generic"
      ;;
    *)
      printf '%s\n' "$1"
      ;;
  esac
}

host::detect() {
  local dmi_product
  dmi_product="$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo "unknown")"

  if [[ "${dmi_product}" == *"LOQ"* ]] || [[ "${dmi_product}" == *"15IRX9"* ]]; then
    printf '%s\n' "loq-15irx9"
  else
    printf '%s\n' "generic"
  fi
}

host::profile_path() {
  local host_name="${1:-${HOST_PROFILE:-$(host::detect)}}"
  host_name="$(host::canonical "${host_name}")"
  printf '%s\n' "${DOTFILES_DIR}/hosts/${host_name}/profile.sh"
}

host::load() {
  local host_name="${1:-${HOST_PROFILE:-$(host::detect)}}"
  local profile_path

  host_name="$(host::canonical "${host_name}")"
  profile_path="$(host::profile_path "${host_name}")"
  export HOST_PROFILE="${host_name}"

  if [[ ! -f "${profile_path}" ]]; then
    return 1
  fi

  # shellcheck source=/dev/null
  source "${profile_path}"
  export HOST_PROFILE="${host_name}"
  return 0
}
