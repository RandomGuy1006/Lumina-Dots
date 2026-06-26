#!/usr/bin/env python3
"""Lumina Hub."""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass
from pathlib import Path

APP_ROOT = Path(__file__).resolve().parents[1]
CORE_PATH = APP_ROOT / "lib"
SHELL_PATH = APP_ROOT / "shell"
for path in (CORE_PATH, SHELL_PATH):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))

from lumina_core.app import LuminaApplication
from lumina_core.errors import DependencyUnavailable
from lumina_core.state import load_json_state
from lumina_core.subprocesses import run_command
from lumina_core.widgets import command_button, section_heading
from components.modes import current_mode, mode_api_payload
from components.popups import dispatch_event


@dataclass(frozen=True)
class HubAction:
    key: str
    label: str
    command: tuple[str, ...]


HUB_ACTIONS: tuple[HubAction, ...] = (
    HubAction("control", "Control Center", ("lumina-control-center",)),
    HubAction("theme", "Theme Studio", ("lumina-theme-studio",)),
    HubAction("mission", "Mission Control", ("lumina-mission-control",)),
    HubAction("keybinds", "Keybind Overlay", ("lumina-keybind-overlay",)),
    HubAction("doctor", "Doctor Dashboard", ("lumina-doctor-dashboard",)),
    HubAction("snapshots", "Snapshot Manager", ("lumina-snapshot-manager",)),
    HubAction("activity", "Activity History", ("lumina-activity-history",)),
    HubAction("welcome", "Welcome", ("lumina-welcome", "--force")),
    HubAction("ai", "Lumina AI", ("lumina-ai",)),
    HubAction("pomodoro", "Pomodoro", ("lumina-pomodoro",)),
    HubAction("cleanup", "Cleanup Manager", ("lumina-cleanup-manager",)),
)


def recent_activity(limit: int = 8) -> list[dict]:
    raw = load_json_state("activity/history.json", [])
    if not isinstance(raw, list):
        return []
    return [item for item in raw[-limit:] if isinstance(item, dict)]


def shell_status() -> str:
    result = run_command(["lumina-shell", "status"], timeout=5)
    if result.ok:
        return result.stdout.strip() or "available"
    return "unavailable"


def launch_action(key: str) -> bool:
    action = next((item for item in HUB_ACTIONS if item.key == key), None)
    if action is None:
        raise ValueError(f"Unsupported Hub action: {key}")
    result = run_command(["uwsm", "app", "--", *action.command], timeout=5)
    if result.missing:
        result = run_command(action.command, timeout=5)
    dispatch_event("hub", body=action.label if result.ok else result.stderr.strip(), urgency="normal" if result.ok else "critical")
    return result.ok


def hub_payload() -> dict[str, object]:
    return {
        "mode": current_mode(),
        "mode_profile": mode_api_payload()["profile"],
        "shell": shell_status(),
        "actions": [{"key": action.key, "label": action.label} for action in HUB_ACTIONS],
        "activity": recent_activity(),
    }


class LuminaHubApp(LuminaApplication):
    def __init__(self):
        super().__init__("lumina-hub", "Lumina Hub")

    def build(self, window):
        Gtk = self.Gtk
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        box.set_margin_top(16)
        box.set_margin_bottom(16)
        box.set_margin_start(16)
        box.set_margin_end(16)
        data = hub_payload()
        box.append(section_heading("Lumina Hub"))
        box.append(Gtk.Label(label=f"Mode: {data['mode']}", xalign=0))
        box.append(Gtk.Label(label=f"Shell: {data['shell']}", xalign=0))
        for action in HUB_ACTIONS:
            box.append(command_button(action.label, lambda _button, key=action.key: launch_action(key)))
        activity = data.get("activity", [])
        if activity:
            box.append(section_heading("Recent Activity"))
            for item in reversed(activity if isinstance(activity, list) else []):
                box.append(Gtk.Label(label=f"{item.get('category', 'event')}: {item.get('body', '')}", xalign=0))
        window.set_content(box)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="lumina-hub")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--launch", choices=[action.key for action in HUB_ACTIONS])
    args = parser.parse_args(argv)
    if args.launch:
        return 0 if launch_action(args.launch) else 1
    if args.json:
        print(json.dumps(hub_payload(), indent=2, sort_keys=True))
        return 0
    try:
        return LuminaHubApp().run(sys.argv)
    except DependencyUnavailable:
        print(json.dumps(hub_payload(), indent=2, sort_keys=True))
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
