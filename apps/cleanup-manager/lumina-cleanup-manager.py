#!/usr/bin/env python3
"""Lumina Cleanup Manager."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

APP_ROOT = Path(__file__).resolve().parents[1]
CORE_PATH = APP_ROOT / "lib"
SHELL_PATH = APP_ROOT / "shell"
for path in (CORE_PATH, SHELL_PATH):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))

from lumina_core.app import LuminaApplication
from lumina_core.errors import DependencyUnavailable
from lumina_core.subprocesses import run_command
from lumina_core.widgets import command_button, section_heading
from components.popups import dispatch_event


def cleanup_status() -> dict[str, object]:
    cache = Path.home() / ".cache" / "lumina"
    state = Path.home() / ".local" / "state" / "lumina"
    return {"cache_exists": cache.exists(), "state_exists": state.exists(), "cache_path": str(cache), "state_path": str(state)}


def run_cleanup() -> bool:
    root = Path(__file__).resolve().parents[2]
    result = run_command(["bash", str(root / "scripts" / "maintenance" / "cleanup.sh")], timeout=120)
    dispatch_event("cleanup", body="Cleanup complete" if result.ok else result.stderr.strip(), urgency="normal" if result.ok else "critical")
    return result.ok


class CleanupManagerApp(LuminaApplication):
    def __init__(self):
        super().__init__("lumina-cleanup-manager", "Cleanup Manager")

    def build(self, window):
        Gtk = self.Gtk
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        box.set_margin_top(16)
        box.set_margin_bottom(16)
        box.set_margin_start(16)
        box.set_margin_end(16)
        box.append(section_heading("Cleanup Manager"))
        box.append(Gtk.Label(label=json.dumps(cleanup_status(), indent=2), xalign=0))
        box.append(command_button("Run Safe Cleanup", lambda *_: run_cleanup()))
        window.set_content(box)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="lumina-cleanup-manager")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--run", action="store_true")
    args = parser.parse_args(argv)
    if args.run:
        return 0 if run_cleanup() else 1
    if args.json:
        print(json.dumps(cleanup_status(), indent=2, sort_keys=True))
        return 0
    try:
        return CleanupManagerApp().run(sys.argv)
    except DependencyUnavailable:
        print(json.dumps(cleanup_status(), indent=2, sort_keys=True))
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
