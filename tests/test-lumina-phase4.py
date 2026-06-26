#!/usr/bin/env python3
"""Unit-style coverage for Lumina Phase 4 product apps."""

from __future__ import annotations

import importlib.util
import os
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APPS = ROOT / "apps"
STATE_HOME = tempfile.mkdtemp(prefix="lumina-phase4-")
os.environ["LUMINA_STATE_HOME"] = STATE_HOME
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


def test_theme_studio() -> None:
    theme = import_script(APPS / "theme-studio" / "lumina-theme-studio.py", "lumina_theme_studio")
    root = Path(tempfile.mkdtemp(prefix="lumina-wallpapers-"))
    wallpaper = root / "sample.png"
    wallpaper.write_bytes(b"not-a-real-image-but-a-valid-path")
    (root / ".current").write_text(str(wallpaper.resolve()), encoding="utf-8")
    candidates = theme.wallpaper_candidates(str(root))
    assert len(candidates) == 1
    assert candidates[0].selected is True
    preview = theme.palette_preview(str(wallpaper))
    assert "colors" in preview
    assert preview["wallpaper"].endswith("sample.png")


def test_lumina_hub() -> None:
    hub = import_script(APPS / "lumina-hub" / "lumina-hub.py", "lumina_hub")
    payload = hub.hub_payload()
    keys = {action["key"] for action in payload["actions"]}
    assert "theme" in keys
    assert "mission" in keys
    assert payload["mode"] in {"quiet", "auto", "performance", "custom"}


def test_mission_control_empty_off_hyprland() -> None:
    mission = import_script(APPS / "mission-control" / "lumina-mission-control.py", "lumina_mission_control")
    payload = mission.overview_payload()
    assert "workspaces" in payload
    assert "clients" in payload
    assert isinstance(payload["workspaces"], list)
    assert isinstance(payload["clients"], list)


def main() -> int:
    test_theme_studio()
    test_lumina_hub()
    test_mission_control_empty_off_hyprland()
    print("Lumina Phase 4 tests passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
