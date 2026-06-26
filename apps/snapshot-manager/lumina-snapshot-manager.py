#!/usr/bin/env python3
"""Lumina Snapshot Manager."""

from __future__ import annotations

import argparse
import json
import re
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
from lumina_core.widgets import command_button, section_heading
from components.popups import dispatch_event


@dataclass(frozen=True)
class Snapshot:
    number: str
    date: str
    description: str


def parse_snapper_list(output: str) -> list[Snapshot]:
    snapshots: list[Snapshot] = []
    for line in output.splitlines():
        if not re.match(r"\s*\d+\s+\|", line):
            continue
        parts = [part.strip() for part in line.split("|")]
        if not parts:
            continue
        number = parts[0]
        date = parts[2] if len(parts) > 2 else ""
        description = parts[-1] if len(parts) > 0 else ""
        snapshots.append(Snapshot(number, date, description))
    return snapshots


def list_snapshots() -> list[Snapshot]:
    result = run_command(["sudo", "snapper", "-c", "root", "list"], timeout=20)
    return parse_snapper_list(result.stdout) if result.ok else []


def create_snapshot(description: str) -> bool:
    result = run_command(["dotfiles", "backup", description], timeout=120)
    dispatch_event("snapshot", body="Snapshot created" if result.ok else result.stderr, urgency="normal" if result.ok else "critical")
    return result.ok


class SnapshotManagerApp(LuminaApplication):
    def __init__(self):
        super().__init__("lumina-snapshot-manager", "Snapshot Manager")

    def build(self, window):
        Gtk = self.Gtk
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        box.set_margin_top(16)
        box.set_margin_bottom(16)
        box.set_margin_start(16)
        box.set_margin_end(16)
        box.append(section_heading("Snapshot Manager"))
        box.append(command_button("Create Snapshot", lambda *_: create_snapshot("Lumina manual snapshot")))
        scroll = Gtk.ScrolledWindow()
        rows = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        snapshots = list_snapshots()
        if not snapshots:
            rows.append(Gtk.Label(label="No snapshots available or Snapper is unavailable."))
        for snapshot in snapshots:
            label = Gtk.Label(label=f"{snapshot.number}  {snapshot.date}  {snapshot.description}")
            label.set_xalign(0)
            rows.append(label)
        scroll.set_child(rows)
        box.append(scroll)
        window.set_content(box)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="lumina-snapshot-manager")
    sub = parser.add_subparsers(dest="command")
    sub.add_parser("list")
    create = sub.add_parser("create")
    create.add_argument("description", nargs="?", default="Lumina manual snapshot")
    args = parser.parse_args(argv)
    if args.command == "list":
        print(json.dumps([asdict(snapshot) for snapshot in list_snapshots()], indent=2))
        return 0
    if args.command == "create":
        return 0 if create_snapshot(args.description) else 1
    try:
        return SnapshotManagerApp().run(sys.argv)
    except DependencyUnavailable:
        print(json.dumps([asdict(snapshot) for snapshot in list_snapshots()], indent=2))
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
