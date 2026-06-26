#!/usr/bin/env python3
"""Lumina Shell service and control entrypoint."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

APP_ROOT   = Path(__file__).resolve().parents[1]
CORE_PATH  = APP_ROOT / "lib"
SHELL_PATH = APP_ROOT / "shell"
for path in (CORE_PATH, SHELL_PATH):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))

from lumina_core.config import load_config
from lumina_core.contracts import capabilities, envelope
from lumina_core.errors import DependencyUnavailable
from lumina_core.hyprland import monitors, workspaces
from lumina_core.logging import get_logger
from lumina_core.notifications import notify
from lumina_core.services import service_status
from lumina_core.theme import load_tokens

from components.brightness import current_brightness
from components.dashboard import dashboard_summary
from components.modes import current_mode, mode_api_payload, set_mode
from components.osd import OSDController
from components.popups import dispatch_event
from components.volume import current_volume
from components.workspaces import workspace_summary
from adapters.hyprland_events import event_stream

DEFAULT_CONFIG = {
    "shell": {
        "enable_osd": True,
        "enable_notifications": False,
        "enable_dashboard": False,
        "enable_workspace_indicator": True,
        "enable_media": False,
        "hyprpanel_fallback": True,
    },
    "osd": {
        "timeout_ms": 1200,
        "anchor": "top",
    },
    "notifications": {
        "take_over_from_hyprpanel": False,
    },
    "dashboard": {
        "show_battery": True,
        "show_network": True,
        "show_audio": True,
        "show_theme": True,
    },
}


def load_shell_config() -> dict:
    return load_config("shell", DEFAULT_CONFIG)


def print_status() -> int:
    payload = status_payload()
    shell = payload["shell"]
    services = payload["services"]
    print("Lumina Shell")
    print(f"  service: {'active' if services['lumina-shell']['active'] else services['lumina-shell']['detail'] or 'inactive'}")
    print(f"  hyprpanel fallback: {'enabled' if shell['hyprpanel_fallback'] else 'disabled'}")
    print(f"  hyprpanel service: {'active' if services['hyprpanel']['active'] else services['hyprpanel']['detail'] or 'inactive'}")
    print(f"  osd: {'enabled' if shell['osd'] else 'disabled'}")
    print(f"  workspace indicator: {'enabled' if shell['workspace_indicator'] else 'disabled'}")
    print(f"  mode: {payload['mode']}")
    print(f"  workspaces: {payload['workspaces']}")
    print(f"  dashboard: {payload['dashboard']}")
    return 0


def status_payload() -> dict[str, object]:
    config = load_shell_config()
    shell = config.get("shell", {})
    lumina_shell = service_status("lumina-shell.service")
    hyprpanel = service_status("loq-hyprpanel.service")
    return {
        "shell": {
            "hyprpanel_fallback": bool(shell.get("hyprpanel_fallback", True)),
            "osd": bool(shell.get("enable_osd", True)),
            "workspace_indicator": bool(shell.get("enable_workspace_indicator", True)),
        },
        "services": {
            "lumina-shell": {
                "active": lumina_shell.active,
                "available": lumina_shell.available,
                "detail": lumina_shell.detail,
            },
            "hyprpanel": {
                "active": hyprpanel.active,
                "available": hyprpanel.available,
                "detail": hyprpanel.detail,
            },
        },
        "mode": current_mode(),
        "workspaces": workspace_summary(),
        "dashboard": dashboard_summary(),
    }


def snapshot_payload() -> dict[str, object]:
    return {
        "status": status_payload(),
        "modes": mode_api_payload(),
        "workspaces": [workspace.__dict__ for workspace in workspaces()],
        "monitors": [monitor.__dict__ for monitor in monitors()],
    }


def print_json(kind: str, data: object) -> int:
    print(json.dumps(envelope(kind, data), indent=2, sort_keys=True))
    return 0


def print_modes() -> int:
    print(json.dumps(mode_api_payload(), indent=2, sort_keys=True))
    return 0


def show_osd(kind: str, value: int | None, label: str | None) -> int:
    config = load_shell_config()
    if value is None:
        if kind == "volume":
            value = current_volume().percent
        elif kind == "brightness":
            value = current_brightness().percent
        else:
            value = 0
    controller = OSDController(timeout_ms=int(config.get("osd", {}).get("timeout_ms", 1200)))
    controller.show(kind=kind, value=value, label=label or kind.title())
    return 0


def show_popup(event: str, body: str, progress: int | None, urgency: str | None) -> int:
    dispatch_event(event, body=body, progress=progress, urgency=urgency)  # type: ignore[arg-type]
    return 0


def run_service() -> int:
    logger = get_logger("lumina-shell")
    config = load_shell_config()
    logger.info("Starting Lumina Shell with config: %s", config)
    try:
        from lumina_core.app import LuminaApplication
        from lumina_core.layer_shell import setup_layer_window

        class ShellApp(LuminaApplication):
            def build(self, window):
                self.load_css(css_path=Path(__file__).with_name("shell.css"))
                if config.get("shell", {}).get("enable_workspace_indicator", True):
                    setup_layer_window(window, anchor=str(config.get("osd", {}).get("anchor", "top")))
                label = self.Gtk.Label(label=f"Lumina Shell\n{workspace_summary()}")
                label.add_css_class("lumina-shell-status")
                window.set_content(label)

        return ShellApp("lumina-shell", "Lumina Shell").run(sys.argv)
    except DependencyUnavailable as exc:
        logger.warning("Lumina Shell GTK surface unavailable: %s", exc)
        notify("Lumina Shell unavailable", str(exc), app_name="Lumina Shell", logger=logger)
        return 1


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="lumina-shell")
    sub = parser.add_subparsers(dest="command")
    sub.add_parser("run")
    status_parser = sub.add_parser("status")
    status_parser.add_argument("--json", action="store_true", help="Emit a versioned machine-readable response")
    modes_parser = sub.add_parser("modes")
    modes_parser.add_argument("--json", action="store_true", help="Emit a versioned machine-readable response")
    sub.add_parser("capabilities")
    sub.add_parser("snapshot")
    sub.add_parser("tokens")
    sub.add_parser("events")
    osd_parser = sub.add_parser("osd")
    osd_parser.add_argument("kind", choices=["volume", "brightness", "custom"])
    osd_parser.add_argument("--value", type=int)
    osd_parser.add_argument("--label")
    popup_parser = sub.add_parser("popup")
    popup_parser.add_argument("event")
    popup_parser.add_argument("--body", default="")
    popup_parser.add_argument("--progress", type=int)
    popup_parser.add_argument("--urgency", choices=["low", "normal", "critical"])
    mode_parser = sub.add_parser("mode")
    mode_parser.add_argument("mode", choices=["quiet", "auto", "performance", "custom"])
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    command = args.command or "run"
    if command == "status":
        if getattr(args, "json", False):
            return print_json("shell.status", status_payload())
        return print_status()
    if command == "modes":
        if getattr(args, "json", False):
            return print_json("shell.modes", mode_api_payload())
        return print_modes()
    if command == "capabilities":
        print(json.dumps(capabilities(), indent=2, sort_keys=True))
        return 0
    if command == "snapshot":
        return print_json("shell.snapshot", snapshot_payload())
    if command == "tokens":
        return print_json("shell.visual-tokens", load_tokens(logger=get_logger("lumina-shell-tokens")))
    if command == "events":
        for event in event_stream():
            print(json.dumps(envelope("shell.hyprland-event", event.to_dict()), sort_keys=True), flush=True)
        return 0
    if command == "osd":
        return show_osd(args.kind, args.value, args.label)
    if command == "popup":
        return show_popup(args.event, args.body, args.progress, args.urgency)
    if command == "mode":
        set_mode(args.mode)
        return print_status()
    return run_service()


if __name__ == "__main__":
    raise SystemExit(main())
