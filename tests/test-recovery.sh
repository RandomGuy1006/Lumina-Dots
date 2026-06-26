#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "${TMP_ROOT}"' EXIT

BIN="${TMP_ROOT}/bin"
mkdir -p "${BIN}" "${TMP_ROOT}/home" "${TMP_ROOT}/state"
touch "${TMP_ROOT}/snapper-root.conf"

cat >"${BIN}/sudo" <<'EOF'
#!/usr/bin/env bash
exec "$@"
EOF
cat >"${BIN}/snapper" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == *" list"* ]]; then printf '1 | single | Lumina test\n'; fi
exit 0
EOF
cat >"${BIN}/timeshift" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == *"--list"* ]]; then printf '2026-06-13_00-00-00 D Lumina test\n'; fi
exit 0
EOF
cat >"${BIN}/pacman" <<'EOF'
#!/usr/bin/env bash
printf 'bash\npython\n'
EOF
cat >"${BIN}/git" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod +x "${BIN}"/*

run_backup_case() {
  local fstype="$1"
  local backend="$2"
  local case_state="${TMP_ROOT}/state-${fstype}"
  mkdir -p "${case_state}"
  PATH="${BIN}:${PATH}" \
    HOME="${TMP_ROOT}/home" \
    XDG_STATE_HOME="${case_state}" \
    LOG_FILE="${case_state}/recovery-test.log" \
    DOTFILES_DIR="${ROOT}" \
    LUMINA_ROOT_FSTYPE="${fstype}" \
    LUMINA_SNAPPER_CONFIG="${TMP_ROOT}/snapper-root.conf" \
    bash "${ROOT}/scripts/maintenance/backup.sh" "test-${fstype}" >/dev/null

  local manifest
  manifest="$(find "${case_state}" -name manifest.json -type f | head -n1)"
  [[ -n "${manifest}" ]]
  grep -q "\"filesystem\": \"${fstype}\"" "${manifest}"
  grep -q "\"backend\": \"${backend}\"" "${manifest}"
  [[ -s "$(dirname "${manifest}")/packages.txt" ]]
}

run_backup_case btrfs snapper
run_backup_case ext4 timeshift

grep -q 'Refusing to replace the active root subvolume' "${ROOT}/scripts/rollback.sh"
grep -q 'Type the snapshot id to continue' "${ROOT}/scripts/rollback.sh"
grep -q 'status=complete' "${ROOT}/scripts/rollback.sh"

printf 'Recovery contract tests passed\n'
