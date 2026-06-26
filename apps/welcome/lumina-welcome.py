#!/usr/bin/env python3
"""Lumina Welcome MVP."""

from __future__ import annotations

import argparse
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
from lumina_core.state import load_json_state, save_json_state
from lumina_core.subprocesses import run_command
from lumina_core.widgets import section_heading
from components.popups import dispatch_event

WELCOME_STATE = "welcome/state.json"
DOCS = {
    "README": "README.md",
    "Keybindings": "docs/keybindings.md",
    "Recovery": "docs/recovery.md",
}


def completed() -> bool:
    state = load_json_state(WELCOME_STATE, {"completed": False})
    return bool(state.get("completed", False)) if isinstance(state, dict) else False


def mark_complete(skipped: bool = False) -> None:
    save_json_state(WELCOME_STATE, {"completed": True, "skipped": skipped})


def apply_wallpaper(path: str) -> bool:
    result = run_command(["dotfiles", "theme", path], timeout=120)
    if result.ok:
        dispatch_event("wallpaper", body=Path(path).name)
    return result.ok


def create_snapshot() -> bool:
    result = run_command(["dotfiles", "backup", "Lumina Welcome snapshot"], timeout=120)
    if result.ok:
        dispatch_event("snapshot", body="Welcome snapshot created")
    return result.ok


def open_doc(label: str) -> bool:
    target = DOCS.get(label)
    if target is None:
        return False
    return run_command(["xdg-open", str(Path(target).resolve())], timeout=5).ok


def print_status() -> int:
    print("Lumina Welcome")
    print(f"  completed: {'yes' if completed() else 'no'}")
    print("  docs: " + ", ".join(DOCS))
    return 0


class WelcomeApp(LuminaApplication):
    def __init__(self):
        super().__init__("lumina-welcome", "Lumina Welcome")

    def build(self, window):
        Gtk = self.Gtk
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        box.set_margin_top(16)
        box.set_margin_bottom(16)
        box.set_margin_start(16)
        box.set_margin_end(16)

        box.append(section_heading("Lumina Dots"))

        subtitle = Gtk.Label(label="Set up your first wallpaper, theme, keybinds, docs, and safety snapshot.")
        subtitle.set_wrap(True)
        subtitle.set_xalign(0)
        box.append(subtitle)

        choose = Gtk.Button(label="Choose Wallpaper")
        choose.connect("clicked", lambda *_: dispatch_event("wallpaper", body="Use dotfiles theme <wallpaper> from a terminal"))
        box.append(choose)

        keybinds = Gtk.Button(label="Open Keybind Overview")
        keybinds.connect("clicked", lambda *_: run_command(["lumina-keybind-overlay"], timeout=5))
        box.append(keybinds)

        snapshot = Gtk.Button(label="Create Snapshot")
        snapshot.connect("clicked", lambda *_: create_snapshot())
        box.append(snapshot)

        skip = Gtk.Button(label="Skip")
        skip.connect("clicked", lambda *_: (mark_complete(skipped=True), window.close()))
        box.append(skip)

        done = Gtk.Button(label="Finish")
        done.connect("clicked", lambda *_: (mark_complete(skipped=False), window.close()))
        box.append(done)

        window.set_content(box)


def run_gui(force: bool = False) -> int:
    if completed() and not force:
        return 0
    try:
        return WelcomeApp().run(sys.argv)
    except DependencyUnavailable:
        print("Lumina Welcome is available. Run with --status, --skip, --snapshot, or --wallpaper <path>.")
        return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="lumina-welcome")
    parser.add_argument("--force", action="store_true", help="show Welcome even if completed")
    parser.add_argument("--status", action="store_true")
    parser.add_argument("--skip", action="store_true")
    parser.add_argument("--reset", action="store_true")
    parser.add_argument("--snapshot", action="store_true")
    parser.add_argument("--wallpaper")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.status:
        return print_status()
    if args.reset:
        save_json_state(WELCOME_STATE, {"completed": False})
        return print_status()
    if args.skip:
        mark_complete(skipped=True)
        return print_status()
    if args.snapshot:
        return 0 if create_snapshot() else 1
    if args.wallpaper:
        return 0 if apply_wallpaper(args.wallpaper) else 1
    return run_gui(force=args.force)


if __name__ == "__main__":
    raise SystemExit(main())
