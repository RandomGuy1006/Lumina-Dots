#!/usr/bin/env python3
"""Unit-style coverage for Lumina Phase 3 surfaces."""

from __future__ import annotations

import importlib.util
import os
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APPS = ROOT / "apps"
os.environ["LUMINA_STATE_HOME"] = tempfile.mkdtemp(prefix="lumina-phase3-")
sys.path.insert(0, str(APPS / "lib"))
sys.path.insert(0, str(APPS / "shell"))

from components.popups import dispatch_event


def import_script(path: Path, name: str):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise AssertionError(f"Could not import {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def test_doctor_parser() -> None:
    doctor = import_script(APPS / "doctor-dashboard" / "lumina-doctor-dashboard.py", "lumina_doctor_dashboard")
    items = doctor.parse_doctor_output("PASS|Shell linked\nWARN|Battery missing\nSUMMARY|errors=0|warnings=1|log=/tmp/x\n")
    assert [item.status for item in items] == ["pass", "warn"]
    assert items[1].message == "Battery missing"


def test_snapshot_parser() -> None:
    snapshots = import_script(APPS / "snapshot-manager" / "lumina-snapshot-manager.py", "lumina_snapshot_manager")
    parsed = snapshots.parse_snapper_list(
        """
 # | Type   | Pre # | Date                     | User | Used Space | Cleanup | Description
---+--------+-------+--------------------------+------+------------+---------+----------------
 1 | single |       | 2026-06-04 21:00:00      | root | 16.00 KiB  |         | Lumina manual snapshot
"""
    )
    assert len(parsed) == 1
    assert parsed[0].number == "1"
    assert parsed[0].description == "Lumina manual snapshot"


def test_activity_history() -> None:
    activity = import_script(APPS / "activity-history" / "lumina-activity-history.py", "lumina_activity_history")
    activity.clear_history()
    dispatch_event("theme", body="Test theme")
    events = activity.history()
    assert events
    assert events[-1]["type"] == "popup"
    assert events[-1]["category"] == "theme"
    activity.clear_history()
    assert activity.history() == []


def main() -> int:
    test_doctor_parser()
    test_snapshot_parser()
    test_activity_history()
    print("Lumina Phase 3 tests passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
