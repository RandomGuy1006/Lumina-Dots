#!/usr/bin/env python3
"""Unit-style coverage for Lumina Phase 5 AI assistant."""

from __future__ import annotations

import importlib.util
import os
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APPS = ROOT / "apps"
os.environ["LUMINA_STATE_HOME"] = tempfile.mkdtemp(prefix="lumina-phase5-state-")
os.environ["LUMINA_CONFIG_HOME"] = tempfile.mkdtemp(prefix="lumina-phase5-config-")
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


def test_pattern_keybind_response() -> None:
    ai = import_script(APPS / "lumina-ai" / "lumina-ai.py", "lumina_ai")
    response = ai.answer("How do I see keybinds?")
    assert response.backend == "pattern"
    assert response.action == "keybinds"
    assert "Super + /" in response.response


def test_no_cloud_fallback() -> None:
    ai = import_script(APPS / "lumina-ai" / "lumina-ai.py", "lumina_ai_cloud")
    config_dir = Path(os.environ["LUMINA_CONFIG_HOME"])
    (config_dir / "ai.toml").write_text('[ai]\nbackend = "openai"\nallow_cloud = false\n', encoding="utf-8")
    response = ai.answer("doctor")
    assert response.backend == "pattern"
    assert "Cloud backend disabled" in response.warning


def test_safe_actions() -> None:
    ai = import_script(APPS / "lumina-ai" / "lumina-ai.py", "lumina_ai_actions")
    actions = ai.safe_actions()
    assert "doctor" in actions
    assert "recovery" in actions
    assert str(ROOT / "docs" / "recovery.md") in actions["recovery"]


def main() -> int:
    test_pattern_keybind_response()
    test_no_cloud_fallback()
    test_safe_actions()
    print("Lumina Phase 5 tests passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
