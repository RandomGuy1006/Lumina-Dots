#!/usr/bin/env python3
"""Searchable Lumina keybind overlay."""

from __future__ import annotations

import argparse
import json
import shlex
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
from lumina_core.hyprland import Keybind, parse_keybinds
from lumina_core.subprocesses import run_command
from lumina_core.layer_shell import setup_layer_window
from components.popups import dispatch_event


@dataclass(frozen=True)
class OverlayBind:
    bind: str
    category: str
    dispatcher: str
    command: str
    source: str
    description: str = ""

    @property
    def searchable(self) -> str:
        return f"{self.bind} {self.category} {self.description} {self.dispatcher} {self.command}".lower()


def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def bind_files() -> list[Path]:
    return [repo_root() / "hypr" / ".config" / "hypr" / "binds.conf"]


def category_map(path: Path) -> dict[int, str]:
    current = "general"
    mapping: dict[int, str] = {}
    for index, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        if line.strip().lower().startswith("# category:"):
            current = line.split(":", 1)[1].strip()
            mapping[index] = current
            continue
        mapping[index] = current
    return mapping


def load_binds() -> list[OverlayBind]:
    results: list[OverlayBind] = []
    for path in bind_files():
        categories = category_map(path)
        lines = path.read_text(encoding="utf-8").splitlines()
        bind_lines = [(i, line) for i, line in enumerate(lines, start=1) if line.lstrip().startswith("bind")]
        for bind, (line_no, source_line) in zip(parse_keybinds([path]), bind_lines, strict=False):
            description = lines[line_no - 1].split("# desc:", 1)[1].strip() if "# desc:" in lines[line_no - 1] else ""
            results.append(convert_bind(bind, categories.get(line_no, "general"), description))
    return results


def convert_bind(bind: Keybind, category: str, description: str = "") -> OverlayBind:
    combo = " + ".join(part for part in [bind.modifiers.replace("$mod", "Super"), bind.key] if part)
    return OverlayBind(combo, category, bind.dispatcher, bind.command, str(bind.source), description)


def search_binds(query: str = "") -> list[OverlayBind]:
    binds = load_binds()
    if not query:
        return binds
    needle = query.lower()
    if needle == "/":
        needle = "slash"
    return [bind for bind in binds if needle in bind.searchable]


def registered_exec_commands() -> set[str]:
    return {bind.command for bind in load_binds() if bind.dispatcher == "exec" and bind.command}


def run_bind(command: str) -> bool:
    if not command:
        return False
    if command not in registered_exec_commands():
        dispatch_event("keybind", body="Refused unregistered keybind command")
        return False
    try:
        argv = shlex.split(command)
    except ValueError as exc:
        dispatch_event("keybind", body=str(exc))
        return False
    if not argv:
        return False
    result = run_command(argv, timeout=10)
    dispatch_event("keybind", body=command if result.ok else result.stderr)
    return result.ok


def export_docs(path: Path) -> Path:
    lines = ["# Generated Keybind Index", "", "| Bind | Category | Action |", "|---|---|---|"]
    for bind in load_binds():
        action = bind.command or bind.dispatcher
        lines.append(f"| `{bind.bind}` | {bind.category} | `{action}` |")
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text("\n".join(lines) + "\n", encoding="utf-8")
    tmp.replace(path)
    return path


class KeybindOverlayApp(LuminaApplication):
    def __init__(self, query: str = "", start_hidden: bool = False):
        self.query = query
        super().__init__("lumina-keybind-overlay", "Keybind Overlay", start_hidden=start_hidden)

    def build(self, window):
        Gtk = self.Gtk
        from gi.repository import Gdk
        setup_layer_window(window, anchor="fullscreen", namespace="lumina-keybind-overlay")
        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        search = Gtk.SearchEntry(placeholder_text="Search keybinds")
        try:
            search.update_property(
                [Gtk.AccessibleProperty.LABEL, Gtk.AccessibleProperty.DESCRIPTION],
                ["Search keybinds", "Filter visible keybinds by key, category, description, or command."],
            )
        except (AttributeError, TypeError):
            pass
        root.append(search)
        scroll = Gtk.ScrolledWindow()
        list_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        list_box.set_margin_top(12)
        list_box.set_margin_bottom(12)
        list_box.set_margin_start(12)
        list_box.set_margin_end(12)
        all_binds=load_binds()
        def render(query=""):
            while child:=list_box.get_first_child(): list_box.remove(child)
            needle=query.lower()
            for bind in (item for item in all_binds if not needle or needle in item.searchable):
                row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
                label = Gtk.Label(label=f"{bind.bind} - {bind.category} - {bind.description or bind.command or bind.dispatcher}")
                label.set_xalign(0); label.set_hexpand(True); row.append(label)
                if bind.dispatcher == "exec" and bind.command:
                    button = Gtk.Button(label="Execute"); button.set_tooltip_text(f"Execute {bind.description or bind.command}"); button.connect("clicked", lambda _button, command=bind.command: run_bind(command)); row.append(button)
                    try:
                        button.update_property(
                            [Gtk.AccessibleProperty.LABEL, Gtk.AccessibleProperty.DESCRIPTION],
                            ["Execute keybind", f"Execute {bind.description or bind.command}"],
                        )
                    except (AttributeError, TypeError):
                        pass
                list_box.append(row)
        render(self.query); search.set_text(self.query); search.connect("search-changed",lambda entry:render(entry.get_text()))
        scroll.set_child(list_box)
        root.append(scroll); window.set_content(root)
        keys=Gtk.EventControllerKey(); keys.connect("key-pressed",lambda _c,key,*_a: (window.set_visible(False) or True) if key==Gdk.KEY_Escape else False); window.add_controller(keys)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="lumina-keybind-overlay")
    parser.add_argument("--query", default="")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--run")
    parser.add_argument("--export-docs")
    parser.add_argument("--daemon", action="store_true")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.json:
        print(json.dumps([asdict(bind) for bind in search_binds(args.query)], indent=2))
        return 0
    if args.run:
        return 0 if run_bind(args.run) else 1
    if args.export_docs:
        print(export_docs(Path(args.export_docs)))
        return 0
    try:
        return KeybindOverlayApp(args.query, start_hidden=args.daemon).run(sys.argv)
    except DependencyUnavailable:
        for bind in search_binds(args.query):
            print(f"{bind.bind:24} {bind.category:18} {bind.command or bind.dispatcher}")
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
