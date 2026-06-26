#!/usr/bin/env python3
"""Unit-style coverage for Lumina Phase 6 surfaces."""

from __future__ import annotations

import importlib.util
import os
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APPS = ROOT / "apps"
os.environ["LUMINA_STATE_HOME"] = tempfile.mkdtemp(prefix="lumina-phase6-state-")
sys.path.insert(0, str(APPS / "lib"))
sys.path.insert(0, str(APPS / "shell"))


def import_script(path: Path, name: str):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise AssertionError(f"Could not import {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def test_pomodoro_state() -> None:
    pomodoro = import_script(APPS / "pomodoro" / "lumina-pomodoro.py", "lumina_pomodoro")
    data = pomodoro.start(1, "work")
    assert data["phase"] == "work"
    assert pomodoro.status()["remaining_seconds"] <= 60
    assert pomodoro.stop()["phase"] == "idle"


def test_cleanup_status() -> None:
    cleanup = import_script(APPS / "cleanup-manager" / "lumina-cleanup-manager.py", "lumina_cleanup_manager")
    data = cleanup.cleanup_status()
    assert "cache_path" in data
    assert "state_path" in data


def test_phase6_files_and_binds() -> None:
    for rel in [
        "scripts/system/presentation-mode.sh",
        "scripts/system/focus-mode.sh",
        "scripts/system/idle-inhibit.sh",
        "scripts/system/media-overlay.sh",
        "scripts/system/session-health.sh",
        "scripts/system/workspace-template.sh",
        "scripts/system/scratch-notes.sh",
        "scripts/system/scratchpad-terminal.sh",
        "scripts/system/color-picker.sh",
        "scripts/theme/random-wallpaper.sh",
        "lumina/.config/lumina/workspace-templates/dev.toml",
        "lumina/.config/lumina/workspace-templates/media.toml",
        "docs/features/media-overlay.md",
        "docs/features/scratch-notes.md",
        "docs/features/scratchpad-terminal.md",
        "docs/features/color-picker.md",
    ]:
        assert (ROOT / rel).exists(), rel
    binds = (ROOT / "hypr" / ".config" / "hypr" / "binds.conf").read_text(encoding="utf-8")
    assert "presentation-mode.sh" in binds
    assert "focus-mode.sh" in binds
    assert "idle-inhibit.sh" in binds
    assert "media-overlay.sh" in binds
    assert "scratch-notes.sh" in binds
    assert "scratchpad-terminal.sh" in binds
    assert "color-picker.sh" in binds
    assert "random-wallpaper.sh" in binds
    assert "lumina-pomodoro" in binds


def main() -> int:
    test_pomodoro_state()
    test_cleanup_status()
    test_phase6_files_and_binds()
    print("Lumina Phase 6 tests passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
