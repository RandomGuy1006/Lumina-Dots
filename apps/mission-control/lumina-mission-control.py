#!/usr/bin/env python3
"""Lumina Mission Control."""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import asdict
from pathlib import Path

APP_ROOT = Path(__file__).resolve().parents[1]
CORE_PATH = APP_ROOT / "lib"
SHELL_PATH = APP_ROOT / "shell"
for path in (CORE_PATH, SHELL_PATH):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))

from lumina_core.app import LuminaApplication
from lumina_core.errors import DependencyUnavailable
from lumina_core.hyprland import clients, workspaces
from lumina_core.layer_shell import setup_layer_window
from lumina_core.subprocesses import run_command
from lumina_core.widgets import command_button, section_heading
from components.popups import dispatch_event


def overview_payload() -> dict[str, object]:
    return {
        "workspaces": [asdict(workspace) for workspace in workspaces()],
        "clients": [asdict(client) for client in clients()],
    }


def switch_workspace(workspace: int | str) -> bool:
    result = run_command(["hyprctl", "dispatch", "workspace", str(workspace)], timeout=3)
    dispatch_event("mission-control", body=f"Workspace {workspace}" if result.ok else result.stderr.strip(), urgency="normal" if result.ok else "critical")
    return result.ok


def focus_window(address: str) -> bool:
    result = run_command(["hyprctl", "dispatch", "focuswindow", f"address:{address}"], timeout=3)
    dispatch_event("mission-control", body="Window focused" if result.ok else result.stderr.strip(), urgency="normal" if result.ok else "critical")
    return result.ok


class MissionControlApp(LuminaApplication):
    def __init__(self, start_hidden: bool = False):
        self.overview_content = None
        super().__init__("lumina-mission-control", "Mission Control", start_hidden=start_hidden)

    def _set_accessible(self, widget, name: str, description: str):
        try:
            widget.update_property(
                [self.Gtk.AccessibleProperty.LABEL, self.Gtk.AccessibleProperty.DESCRIPTION],
                [name, description],
            )
        except (AttributeError, TypeError):
            pass
        return widget

    def _populate_overview_content(self) -> None:
        if self.overview_content is None:
            return
        Gtk = self.Gtk
        while child := self.overview_content.get_first_child():
            self.overview_content.remove(child)
        data = overview_payload()
        workspace_rows = data.get("workspaces", [])
        client_rows = data.get("clients", [])
        if not workspace_rows and not client_rows:
            self.overview_content.append(Gtk.Label(label="Hyprland is unavailable or has no active clients.", xalign=0))
        if workspace_rows:
            self.overview_content.append(section_heading("Workspaces"))
            for workspace in workspace_rows if isinstance(workspace_rows, list) else []:
                names = [str(client.get("title") or client.get("class_name")) for client in client_rows if isinstance(client, dict) and client.get("workspace") == workspace.get("name")]
                accessible = f"Workspace {workspace.get('name')}: {', '.join(names) if names else 'empty'}"
                button = command_button(accessible, lambda _button, name=workspace.get("name"): switch_workspace(str(name)))
                button.set_tooltip_text(f"Switch to {accessible}")
                self.overview_content.append(self._set_accessible(button, accessible, f"Switch to {accessible}"))
        if client_rows:
            self.overview_content.append(section_heading("Windows"))
            for client in client_rows if isinstance(client_rows, list) else []:
                title = client.get("title") or client.get("class_name") or client.get("address")
                button = command_button(str(title), lambda _button, address=client.get("address"): focus_window(str(address)))
                button.set_tooltip_text(f"Focus window {title}")
                self.overview_content.append(self._set_accessible(button, f"Window: {title}", f"Focus window {title}"))

    def _activate(self, application):
        if self.window is not None:
            self._populate_overview_content()
        super()._activate(application)

    def build(self, window):
        Gtk = self.Gtk
        from gi.repository import Gdk
        setup_layer_window(window, anchor="fullscreen", namespace="lumina-mission-control")
        window.add_css_class("glass-surface")
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        box.set_margin_top(16)
        box.set_margin_bottom(16)
        box.set_margin_start(16)
        box.set_margin_end(16)
        box.append(section_heading("Mission Control"))
        self.overview_content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        box.append(self.overview_content)
        self._populate_overview_content()
        window.set_content(box)
        keys=Gtk.EventControllerKey(); keys.connect("key-pressed",lambda _c,key,*_a: (window.set_visible(False) or True) if key==Gdk.KEY_Escape else False); window.add_controller(keys)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="lumina-mission-control")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--workspace")
    parser.add_argument("--focus")
    parser.add_argument("--fallback-ui", action="store_true")
    parser.add_argument("--daemon", action="store_true")
    args = parser.parse_args(argv)
    if args.workspace:
        return 0 if switch_workspace(args.workspace) else 1
    if args.focus:
        return 0 if focus_window(args.focus) else 1
    if args.json:
        print(json.dumps(overview_payload(), indent=2, sort_keys=True))
        return 0
    try:
        return MissionControlApp(start_hidden=args.daemon).run(sys.argv)
    except DependencyUnavailable:
        print(json.dumps(overview_payload(), indent=2, sort_keys=True))
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
