#!/usr/bin/env python3
"""Lumina Pomodoro timer."""

from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path

APP_ROOT = Path(__file__).resolve().parents[1]
CORE_PATH = APP_ROOT / "lib"
SHELL_PATH = APP_ROOT / "shell"
for path in (CORE_PATH, SHELL_PATH):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))

from lumina_core.app import LuminaApplication
from lumina_core.errors import DependencyUnavailable
from lumina_core.state import load_json_state, save_json_state
from lumina_core.widgets import command_button, section_heading
from components.popups import dispatch_event

STATE = "pomodoro.json"
DEFAULTS = {"phase": "idle", "work_minutes": 25, "break_minutes": 5, "started_at": 0, "duration_seconds": 0}


def state() -> dict:
    raw = load_json_state(STATE, DEFAULTS)
    return {**DEFAULTS, **raw} if isinstance(raw, dict) else dict(DEFAULTS)


def start(minutes: int = 25, phase: str = "work") -> dict:
    data = {**state(), "phase": phase, "started_at": time.time(), "duration_seconds": max(1, minutes) * 60}
    save_json_state(STATE, data)
    dispatch_event("pomodoro", body=f"{phase.title()} started", progress=0)
    return data


def stop() -> dict:
    data = {**state(), "phase": "idle", "started_at": 0, "duration_seconds": 0}
    save_json_state(STATE, data)
    dispatch_event("pomodoro", body="Stopped")
    return data


def status() -> dict:
    data = state()
    elapsed = max(0, int(time.time() - float(data.get("started_at", 0)))) if data.get("started_at") else 0
    duration = int(data.get("duration_seconds", 0))
    data["remaining_seconds"] = max(0, duration - elapsed) if duration else 0
    data["progress"] = int((elapsed / duration) * 100) if duration else 0
    return data


class PomodoroApp(LuminaApplication):
    def __init__(self):
        super().__init__("lumina-pomodoro", "Pomodoro")

    def build(self, window):
        Gtk = self.Gtk
        data = status()
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        box.set_margin_top(16)
        box.set_margin_bottom(16)
        box.set_margin_start(16)
        box.set_margin_end(16)
        box.append(section_heading("Pomodoro"))
        box.append(Gtk.Label(label=f"{data['phase']} - {data['remaining_seconds']}s remaining", xalign=0))
        box.append(command_button("Start Work", lambda *_: start(25, "work")))
        box.append(command_button("Start Break", lambda *_: start(5, "break")))
        box.append(command_button("Stop", lambda *_: stop()))
        window.set_content(box)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="lumina-pomodoro")
    sub = parser.add_subparsers(dest="command")
    start_cmd = sub.add_parser("start")
    start_cmd.add_argument("--minutes", type=int, default=25)
    start_cmd.add_argument("--phase", choices=["work", "break"], default="work")
    sub.add_parser("break")
    sub.add_parser("stop")
    sub.add_parser("status")
    args = parser.parse_args(argv)
    if args.command == "start":
        print(json.dumps(start(args.minutes, args.phase), indent=2, sort_keys=True))
        return 0
    if args.command == "break":
        print(json.dumps(start(5, "break"), indent=2, sort_keys=True))
        return 0
    if args.command == "stop":
        print(json.dumps(stop(), indent=2, sort_keys=True))
        return 0
    if args.command == "status":
        print(json.dumps(status(), indent=2, sort_keys=True))
        return 0
    try:
        return PomodoroApp().run(sys.argv)
    except DependencyUnavailable:
        print(json.dumps(status(), indent=2, sort_keys=True))
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
