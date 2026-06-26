#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for file in \
  "$ROOT/docs/vision.md" \
  "$ROOT/docs/problems-in-old-setup.md" \
  "$ROOT/docs/why-this-stack-wins.md" \
  "$ROOT/docs/comparison-table.md" \
  "$ROOT/docs/component-matrix.md" \
  "$ROOT/docs/install-archinstall.md" \
  "$ROOT/docs/install-manual.md" \
  "$ROOT/docs/maintenance.md" \
  "$ROOT/docs/recovery.md" \
  "$ROOT/docs/boot-flow.md" \
  "$ROOT/docs/troubleshooting-tree.md" \
  "$ROOT/docs/compatibility.md" \
  "$ROOT/docs/design-system.md" \
  "$ROOT/docs/migration.md" \
  "$ROOT/docs/hardware-lenovo-loq-15irx9.md" \
  "$ROOT/docs/features/lumina-shell.md" \
  "$ROOT/docs/features/universal-popup-framework.md" \
  "$ROOT/docs/features/lumina-modes.md" \
  "$ROOT/docs/features/welcome-app.md" \
  "$ROOT/docs/features/keybind-overlay.md" \
  "$ROOT/docs/features/control-center.md" \
  "$ROOT/docs/features/doctor-dashboard.md" \
  "$ROOT/docs/features/snapshot-manager.md" \
  "$ROOT/docs/features/activity-history.md" \
  "$ROOT/docs/features/theme-studio.md" \
  "$ROOT/docs/features/lumina-hub.md" \
  "$ROOT/docs/features/mission-control.md" \
  "$ROOT/docs/features/ai-assistant.md" \
  "$ROOT/docs/features/random-wallpaper.md" \
  "$ROOT/docs/features/idle-inhibitor.md" \
  "$ROOT/docs/features/media-overlay.md" \
  "$ROOT/docs/features/scratch-notes.md" \
  "$ROOT/docs/features/scratchpad-terminal.md" \
  "$ROOT/docs/features/color-picker.md" \
  "$ROOT/docs/features/workspace-templates.md" \
  "$ROOT/docs/features/cleanup-manager.md" \
  "$ROOT/docs/features/pomodoro.md" \
  "$ROOT/docs/features/focus-mode.md" \
  "$ROOT/docs/features/presentation-mode.md" \
  "$ROOT/docs/design/open-source-governance.md" \
  "$ROOT/docs/implementation/phase-2-architecture-snapshot.md" \
  "$ROOT/docs/implementation/phase-3-report.md" \
  "$ROOT/docs/implementation/phase-4.5-report.md" \
  "$ROOT/docs/implementation/phase-4-report.md" \
  "$ROOT/docs/implementation/phase-5-report.md" \
  "$ROOT/docs/implementation/phase-6-report.md" \
  "$ROOT/RELEASE_CANDIDATE_TEST_PLAN.md" \
  "$ROOT/TEST_CHECKLIST.md" \
  "$ROOT/BUG_REPORT_TEMPLATE.md" \
  "$ROOT/ARCH_INSTALL_VALIDATION.md" \
  "$ROOT/RUNTIME_RISK_MATRIX.md" \
  "$ROOT/website/index.html"; do
  [[ -f "$file" ]] || {
    printf 'Missing required doc: %s\n' "$file"
    exit 1
  }
done

if grep -R -n -i -- 'SDDM\|sddm.service\|Super+L is lock' "$ROOT/README.md" "$ROOT/docs" "$ROOT/website/index.html" >/dev/null 2>&1; then
  printf 'Found stale display-manager or keybind claim in docs/website\n'
  exit 1
fi

python3 - "$ROOT" <<'PY'
from __future__ import annotations
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])

def normalize_combo(value: str) -> str:
    value = (
        value.replace("$mod", "Super")
        .replace("SUPER", "Super")
        .replace("SHIFT", "Shift")
        .replace("CTRL", "Ctrl")
        .replace("ALT", "Alt")
    )
    aliases = {"slash": "/", "grave": "`", "comma": ",", "escape": "Escape"}
    parts = [part.strip() for part in re.split(r"\s*\+\s*|\s+", value) if part.strip()]
    return "+".join(aliases.get(part, part) for part in parts).lower()

binds_conf = root / "hypr" / ".config" / "hypr" / "binds.conf"
docs = root / "docs" / "keybindings.md"
documented = set()
for line in docs.read_text(encoding="utf-8").splitlines():
    match = re.match(r"\| `([^`]+)` \| [^|]+ \| `[^`]*` \|", line)
    if match:
        documented.add(normalize_combo(match.group(1)))

missing: list[str] = []
for line in binds_conf.read_text(encoding="utf-8").splitlines():
    stripped = line.split("#", 1)[0].strip()
    if not stripped.startswith("bind") or "=" not in stripped:
        continue
    parts = [part.strip() for part in stripped.split("=", 1)[1].split(",", 3)]
    if len(parts) < 3:
        continue
    combo = " + ".join(part for part in (parts[0].replace("$mod", "Super"), parts[1]) if part)
    if normalize_combo(combo) not in documented:
        missing.append(combo)

if missing:
    print("Keybinds missing from docs/keybindings.md:")
    for combo in missing:
        print(f"  {combo}")
    raise SystemExit(1)
PY

printf 'Documentation validation passed\n'
