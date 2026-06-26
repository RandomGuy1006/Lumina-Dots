#!/usr/bin/env python3
"""Unit-style coverage for Lumina Phase 2 surfaces."""

from __future__ import annotations

import importlib.util
import os
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APPS = ROOT / "apps"
os.environ["LUMINA_STATE_HOME"] = tempfile.mkdtemp(prefix="lumina-phase2-")
sys.path.insert(0, str(APPS / "lib"))
sys.path.insert(0, str(APPS / "shell"))

from adapters.hyprland_events import event_socket_path, parse_event
from components.modes import MODE_PROFILES, current_mode, mode_api_payload, set_mode
from components.popups import PopupEngine, PopupQueue, event_popup, popup_style_tokens
from lumina_core.contracts import capabilities, envelope
from lumina_core.state import load_json_state, load_versioned_state, save_json_state


def import_script(path: Path, name: str):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise AssertionError(f"Could not import {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def test_popups() -> None:
    queue = PopupQueue("test/popup-queue.json")
    engine = PopupEngine(queue)
    shown = engine.show(event_popup("volume", body="Volume", progress=57))
    assert shown.category == "volume"
    assert shown.normalized_progress() == 57
    style = popup_style_tokens()
    assert style["font_family"] == "Inter"
    assert style["icon_size"] == 24
    assert style["border_width"] == 1


def test_modes() -> None:
    assert "custom" in MODE_PROFILES
    assert "crazy" not in MODE_PROFILES
    assert MODE_PROFILES["custom"].selection_animation == "custom-prism"
    assert set_mode("quiet") == "quiet"
    assert current_mode() == "quiet"
    transition = load_versioned_state("shell/mode-transition.json", "shell.mode-transition", {})
    assert transition["current"] == "quiet"
    assert transition["animation"] == "soft-fade"
    payload = mode_api_payload()
    assert payload["current"] == "quiet"
    assert "performance" in payload["available"]


def test_public_contracts() -> None:
    contract = envelope("test.payload", {"ok": True})
    assert contract["schema_version"] == 1
    assert contract["kind"] == "test.payload"
    assert capabilities()["data"]["production_frontends"] == ["gtk", "hyprpanel"]
    event = parse_event("workspace>>2")
    assert event is not None and event.name == "workspace" and event.payload == "2"
    assert parse_event("invalid") is None
    path = event_socket_path({"XDG_RUNTIME_DIR": "/run/user/1000", "HYPRLAND_INSTANCE_SIGNATURE": "abc"})
    assert path is not None and path.parts[-3:] == ("hypr", "abc", ".socket2.sock")


def test_atomic_state_recovery() -> None:
    path = save_json_state("test/atomic.json", {"value": 1})
    save_json_state("test/atomic.json", {"value": 2})
    path.write_text("{broken", encoding="utf-8")
    assert load_json_state("test/atomic.json") == {"value": 1}


def test_keybind_overlay() -> None:
    overlay = import_script(APPS / "keybind-overlay" / "lumina-keybind-overlay.py", "lumina_keybind_overlay")
    binds = overlay.search_binds("/")
    assert any("slash" in bind.bind.lower() for bind in binds)
    all_binds = overlay.search_binds()
    assert any(bind.bind == "Super + C" for bind in all_binds)


def test_control_center() -> None:
    control = import_script(APPS / "control-center" / "lumina-control-center.py", "lumina_control_center")
    payload = control.status_payload()
    assert "audio" in payload
    assert "brightness" in payload
    assert "mode" in payload


def test_welcome() -> None:
    welcome = import_script(APPS / "welcome" / "lumina-welcome.py", "lumina_welcome")
    welcome.mark_complete(skipped=True)
    assert welcome.completed() is True


def main() -> int:
    test_popups()
    test_modes()
    test_public_contracts()
    test_atomic_state_recovery()
    test_keybind_overlay()
    test_control_center()
    test_welcome()
    print("Lumina Phase 2 tests passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
