#!/usr/bin/env python3
"""Lumina Doctor Dashboard."""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import asdict, dataclass
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
from lumina_core.widgets import section_heading, status_badge
from components.popups import dispatch_event


@dataclass(frozen=True)
class DoctorItem:
    status: str
    message: str


def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def parse_doctor_output(output: str, fallback_error: str = "") -> list[DoctorItem]:
    items: list[DoctorItem] = []
    for line in output.splitlines():
        parts = line.split("|", 1)
        if len(parts) == 2 and parts[0] in {"PASS", "FAIL", "WARN", "INFO"}:
            items.append(DoctorItem(parts[0].lower(), parts[1]))
    if fallback_error and not items:
        items.append(DoctorItem("fail", fallback_error))
    return items


def run_doctor() -> list[DoctorItem]:
    result = run_command(["bash", str(repo_root() / "scripts" / "doctor.sh"), "--porcelain"], timeout=120)
    fallback = result.stderr.strip() or "Doctor failed" if not result.ok else ""
    items = parse_doctor_output(result.stdout, fallback)
    failures = sum(1 for item in items if item.status == "fail")
    warnings = sum(1 for item in items if item.status == "warn")
    dispatch_event("doctor", body=f"{failures} failures, {warnings} warnings", urgency="critical" if failures else "normal")
    return items


class DoctorDashboardApp(LuminaApplication):
    def __init__(self):
        super().__init__("lumina-doctor-dashboard", "Doctor Dashboard")

    def build(self, window):
        Gtk = self.Gtk
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        box.set_margin_top(16)
        box.set_margin_bottom(16)
        box.set_margin_start(16)
        box.set_margin_end(16)
        box.append(section_heading("Doctor Dashboard"))
        scroll = Gtk.ScrolledWindow()
        rows = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        for item in run_doctor():
            row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
            row.append(status_badge(item.status.upper(), kind="danger" if item.status == "fail" else "warning" if item.status == "warn" else "neutral"))
            label = Gtk.Label(label=item.message)
            label.set_xalign(0)
            label.set_wrap(True)
            row.append(label)
            rows.append(row)
        scroll.set_child(rows)
        box.append(scroll)
        window.set_content(box)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="lumina-doctor-dashboard")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args(argv)
    if args.json:
        print(json.dumps([asdict(item) for item in run_doctor()], indent=2))
        return 0
    try:
        return DoctorDashboardApp().run(sys.argv)
    except DependencyUnavailable:
        for item in run_doctor():
            print(f"{item.status.upper():5} {item.message}")
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
