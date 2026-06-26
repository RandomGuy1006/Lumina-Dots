#!/usr/bin/env python3
"""Lumina Activity History."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

APP_ROOT = Path(__file__).resolve().parents[1]
CORE_PATH = APP_ROOT / "lib"
for path in (CORE_PATH,):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))

from lumina_core.app import LuminaApplication
from lumina_core.errors import DependencyUnavailable
from lumina_core.state import load_json_state, save_json_state
from lumina_core.widgets import section_heading


def history(limit: int = 50) -> list[dict]:
    raw = load_json_state("activity/history.json", [])
    if not isinstance(raw, list):
        return []
    return [item for item in raw[-limit:] if isinstance(item, dict)]


def clear_history() -> None:
    save_json_state("activity/history.json", [])


class ActivityHistoryApp(LuminaApplication):
    def __init__(self):
        super().__init__("lumina-activity-history", "Activity History")

    def build(self, window):
        Gtk = self.Gtk
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        box.set_margin_top(16)
        box.set_margin_bottom(16)
        box.set_margin_start(16)
        box.set_margin_end(16)
        box.append(section_heading("Activity History"))
        scroll = Gtk.ScrolledWindow()
        rows = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        for item in reversed(history()):
            label = Gtk.Label(label=f"{item.get('category', item.get('type', 'event'))}: {item.get('title', '')} {item.get('body', '')}")
            label.set_xalign(0)
            label.set_wrap(True)
            rows.append(label)
        scroll.set_child(rows)
        box.append(scroll)
        window.set_content(box)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="lumina-activity-history")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--clear", action="store_true")
    args = parser.parse_args(argv)
    if args.clear:
        clear_history()
        return 0
    if args.json:
        print(json.dumps(history(), indent=2, sort_keys=True))
        return 0
    try:
        return ActivityHistoryApp().run(sys.argv)
    except DependencyUnavailable:
        print(json.dumps(history(), indent=2, sort_keys=True))
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
