#!/usr/bin/env python3
"""Lumina Control Center MVP."""

from __future__ import annotations

import argparse
import datetime
import json
import os
import sys
from pathlib import Path
from typing import Any

APP_ROOT = Path(__file__).resolve().parents[1]
CORE_PATH = APP_ROOT / "lib"
SHELL_PATH = APP_ROOT / "shell"
for path in (CORE_PATH, SHELL_PATH):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))

from lumina_core.app import LuminaApplication
from lumina_core.glass import GlassMode
from lumina_core.mood import MOOD_PROFILES, Mood, current_mood
from lumina_core.toasts import toast
from lumina_core.layer_shell import setup_layer_window
from lumina_core.errors import DependencyUnavailable
from lumina_core.subprocesses import run_command
from lumina_core.widgets import section_heading
from components.brightness import current_brightness
from components.media import media_status
from components.modes import current_mode, set_mode
from components.popups import dispatch_event
from components.session import lock_session, open_power_menu
from components.volume import current_volume
from adapters.brightnessctl import set_brightness
from adapters.pipewire import set_volume
from adapters.playerctl import play_pause


def audio_action(action: str) -> bool:
    if action == "up":
        result_ok = set_volume("5%+")
    elif action == "down":
        result_ok = set_volume("5%-")
    elif action == "mute":
        result_ok = run_command(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"], timeout=3).ok
    elif action == "mic-mute":
        result = run_command(["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"], timeout=3)
        dispatch_event("microphone", body="Mute toggled")
        return result.ok
    else:
        raise ValueError(f"Unsupported audio action: {action}")
    state = current_volume()
    dispatch_event("volume", body="Muted" if state.muted else "Volume", progress=state.percent)
    return result_ok


def brightness_action(action: str) -> bool:
    if action == "up":
        result_ok = set_brightness("5%+")
    elif action == "down":
        result_ok = set_brightness("5%-")
    else:
        raise ValueError(f"Unsupported brightness action: {action}")
    dispatch_event("brightness", body="Brightness", progress=current_brightness().percent)
    return result_ok




def audio_devices() -> dict[str, list[dict[str, str]]]:
    devices: dict[str, list[dict[str, str]]] = {"sinks": [], "sources": []}
    for kind, command in {"sinks": "sinks", "sources": "sources"}.items():
        result = run_command(["pactl", "list", "short", command], timeout=3)
        if not result.ok:
            continue
        for line in result.stdout.splitlines():
            parts = line.split("\t")
            if len(parts) >= 2:
                devices[kind].append({"id": parts[0], "name": parts[1]})
    return devices


def set_default_audio(kind: str, name: str) -> bool:
    if kind == "sink":
        command = ["pactl", "set-default-sink", name]
    elif kind == "source":
        command = ["pactl", "set-default-source", name]
    else:
        raise ValueError(f"Unsupported audio device kind: {kind}")
    result = run_command(command, timeout=3)
    dispatch_event("audio", body=f"Default {kind}: {name}" if result.ok else result.stderr.strip(), urgency="normal" if result.ok else "critical")
    return result.ok

def network_status() -> str:
    result = run_command(["nmcli", "-t", "-f", "STATE", "general"], timeout=3)
    return result.stdout.strip() if result.ok else "unavailable"


def bluetooth_status() -> str:
    result = run_command(["bluetoothctl", "show"], timeout=3)
    if not result.ok:
        return "unavailable"
    return "powered" if "Powered: yes" in result.stdout else "off"


def night_light_toggle() -> bool:
    if run_command(["pkill", "-x", "hyprsunset"], timeout=3).ok:
        dispatch_event("theme", body="Night Light off")
        return True
    result = run_command(["hyprsunset", "-t", "4500"], timeout=3)
    dispatch_event("theme", body="Night Light on" if result.ok else "Night Light unavailable")
    return result.ok


def dnd_toggle() -> bool:
    state = run_command(["dunstctl", "is-paused"], timeout=3)
    if not state.ok:
        dispatch_event("notifications", body="Do Not Disturb unavailable", urgency="critical")
        return False
    paused = state.stdout.strip().lower() == "true"
    result = run_command(["dunstctl", "set-paused", "false" if paused else "true"], timeout=3)
    dispatch_event("notifications", body=f"Do Not Disturb {'off' if paused else 'on'}" if result.ok else result.stderr.strip(), urgency="normal" if result.ok else "critical")
    return result.ok


def quick_action(action: str) -> bool:
    screenshot_path = os.path.expanduser(
        f"~/Pictures/Screenshots/{datetime.datetime.now().strftime('%Y%m%d-%H%M%S')}.png"
    )
    commands = {
        "media": ["playerctl", "play-pause"],
        "screenshot": ["grimblast", "--notify", "save", "area", screenshot_path],
        "keybinds": ["lumina-keybind-overlay"],
        "welcome": ["lumina-welcome", "--force"],
        "doctor": ["lumina-doctor-dashboard"],
        "snapshot": ["lumina-snapshot-manager"],
        "activity": ["lumina-activity-history"],
        "theme-studio": ["lumina-theme-studio"],
        "hub": ["lumina-hub"],
        "mission-control": ["lumina-mission-control"],
        "ai": ["lumina-ai"],
        "pomodoro": ["lumina-pomodoro"],
        "cleanup": ["lumina-cleanup-manager"],
    }
    if action == "lock":
        return lock_session()
    if action == "power":
        return open_power_menu()
    if action == "media":
        return play_pause()
    command = commands.get(action)
    if command is None:
        raise ValueError(f"Unsupported quick action: {action}")
    result = run_command(command, timeout=10)
    if action == "screenshot":
        dispatch_event("screenshot", body="Area capture requested")
    return result.ok


def status_payload() -> dict[str, object]:
    volume = current_volume()
    brightness = current_brightness()
    return {
        "audio": {"volume": volume.percent, "muted": volume.muted},
        "brightness": brightness.percent,
        "network": network_status(),
        "bluetooth": bluetooth_status(),
        "media": media_status(),
        "mode": current_mode(),
        "audio_devices": audio_devices(),
    }


class ControlCenterApp(LuminaApplication):
    def __init__(self, start_hidden: bool = False):
        super().__init__("lumina-control-center", "Control Center", start_hidden=start_hidden)

    def _set_accessible(self, widget: Any, name: str, description: str) -> Any:
        try:
            widget.update_property(
                [self.Gtk.AccessibleProperty.LABEL, self.Gtk.AccessibleProperty.DESCRIPTION],
                [name, description],
            )
        except (AttributeError, TypeError):
            pass
        return widget

    def _icon_button(self, icon_name: str, label: str, description: str, callback: Any) -> Any:
        button = self.Gtk.Button()
        content = self.Gtk.Box(orientation=self.Gtk.Orientation.HORIZONTAL, spacing=6)
        content.append(self.Gtk.Image.new_from_icon_name(icon_name))
        content.append(self.Gtk.Label(label=label))
        button.set_child(content)
        button.set_tooltip_text(description)
        button.connect("clicked", callback)
        return self._set_accessible(button, label, description)

    def build(self, window):
        Gtk = self.Gtk
        from gi.repository import Gdk
        setup_layer_window(window, anchor="top-right", namespace="lumina-control-center")
        window.set_default_size(360, -1)
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        box.set_margin_top(16)
        box.set_margin_bottom(16)
        box.set_margin_start(16)
        box.set_margin_end(16)
        mood = MOOD_PROFILES[current_mood()]
        status = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        mood_button = self._icon_button("weather-clear-symbolic", f"{mood.emoji} {mood.display_name}", "Current mood; activate to choose a mood.", lambda *_: None)
        popover = Gtk.Popover()
        mood_grid = Gtk.Grid(column_spacing=6, row_spacing=6, margin_top=8, margin_bottom=8, margin_start=8, margin_end=8)
        def refresh_mood_label() -> None:
            profile = MOOD_PROFILES[current_mood()]
            label = mood_button.get_child().get_last_child()
            if label is not None:
                label.set_label(f"{profile.emoji} {profile.display_name}")
        for index, mood_item in enumerate(Mood):
            profile = MOOD_PROFILES[mood_item]
            button = self._icon_button("weather-clear-symbolic", profile.display_name, f"Apply {profile.display_name} mood.", lambda _button, m=mood_item: (run_command(["lumina-mood", "set", m.value], timeout=5), toast(f"Mood: {m.value} requested"), popover.popdown()))
            mood_grid.attach(button, index % 4, index // 4, 1, 1)
        popover.set_child(mood_grid)
        popover.set_parent(mood_button)
        mood_button.connect("clicked", lambda *_: popover.popup())
        status.append(mood_button); status.append(Gtk.Label(label="Battery —")); box.append(status)
        try:
            bus=self.Gio.bus_get_sync(self.Gio.BusType.SESSION,None)
            def refresh_from_signal(_c,_sender,_path,interface,signal,params,_u):
                self.load_css()
                if interface == "dev.lumina.settings":
                    key, _value = params.unpack()
                    if key in {"mood", "glass", "wallpaper"}:
                        refresh_mood_label()
                elif interface in {"dev.lumina.mood", "dev.lumina.glass", "dev.lumina.wallpaper"}:
                    refresh_mood_label()
            for interface, signal in (("dev.lumina.settings", "Changed"), ("dev.lumina.mood", "Changed"), ("dev.lumina.glass", "Changed"), ("dev.lumina.wallpaper", "Changed")):
                bus.signal_subscribe("dev.lumina.core", interface, signal, "/dev/lumina/core", None, self.Gio.DBusSignalFlags.NONE, refresh_from_signal)
        except Exception as exc:
            self.logger.warning("D-Bus signal subscription unavailable: %s", exc)
        toggles = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
        def action(command, message): run_command(command); toast(message)
        for icon, label, callback in (("notifications-disabled-symbolic", "DND", lambda *_: dnd_toggle()), ("alarm-symbolic", "Focus", lambda *_: action([os.path.expanduser("~/.config/hypr/scripts/focus-mode.sh"), "toggle"],"Focus mode toggled")), ("bluetooth-active-symbolic", "Bluetooth", lambda *_: action(["bluetoothctl", "power", "on"],"Bluetooth enabled")), ("network-wireless-symbolic", "Wi-Fi", lambda *_: action(["nmcli", "radio", "wifi", "on"],"Wi-Fi enabled")), ("weather-clear-night-symbolic", "Night light", lambda *_: (night_light_toggle(), toast("Night Light toggled")))):
            toggles.append(self._icon_button(icon, label, label, callback))
        box.append(toggles)
        glass_row=Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL,spacing=4)
        def set_glass(mode):
            run_command(["lumina-glass", "set", mode.value], timeout=5)
            toast(f"Glass: {mode.value} requested")
        for mode in GlassMode:
            glass_row.append(self._icon_button("weather-fog-symbolic", mode.value.title(), f"Apply {mode.value} glass", lambda _b,m=mode:set_glass(m)))
        box.append(glass_row)
        levels=Gtk.Box(orientation=Gtk.Orientation.VERTICAL,spacing=4); levels.append(Gtk.Label(label=f"Volume {current_volume().percent}%",xalign=0)); levels.append(Gtk.Label(label=f"Brightness {current_brightness().percent}%",xalign=0)); box.append(levels)
        media=media_status(); box.append(Gtk.Label(label=f"Music: {media}",xalign=0))
        actions=Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL,spacing=4)
        for icon,label,command in (("preferences-system-symbolic","Open Settings",["lumina-settings-studio"]),("camera-photo-symbolic","Take Screenshot",[os.path.expanduser("~/.config/hypr/scripts/capture-screenshots.sh")]),("system-lock-screen-symbolic","Lock Screen",["hyprlock"]),("system-log-out-symbolic","Log Out",["hyprctl","dispatch","exit"])):
            actions.append(self._icon_button(icon, label, label, lambda _b,c=command,l=label: (run_command(c),toast(l))))
        box.append(actions)
        window.set_content(box)
        keys=Gtk.EventControllerKey(); keys.connect("key-pressed",lambda _c,key,*_a: (window.set_visible(False) or True) if key==Gdk.KEY_Escape else False); window.add_controller(keys)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="lumina-control-center")
    sub = parser.add_subparsers(dest="command")
    parser.add_argument("--daemon", action="store_true")
    sub.add_parser("status")
    audio = sub.add_parser("audio")
    audio.add_argument("action", choices=["up", "down", "mute", "mic-mute"])
    bright = sub.add_parser("brightness")
    bright.add_argument("action", choices=["up", "down"])
    devices = sub.add_parser("audio-devices")
    devices.add_argument("--json", action="store_true")
    default_audio = sub.add_parser("audio-default")
    default_audio.add_argument("kind", choices=["sink", "source"])
    default_audio.add_argument("name")
    sub.add_parser("night-light")
    mode = sub.add_parser("mode")
    mode.add_argument("mode", choices=["quiet", "auto", "performance", "custom"])
    quick = sub.add_parser("quick")
    quick.add_argument("action", choices=["lock", "screenshot", "power", "keybinds", "welcome", "media", "doctor", "snapshot", "activity", "theme-studio", "hub", "mission-control", "ai", "pomodoro", "cleanup"])
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.command == "status":
        print(json.dumps(status_payload(), indent=2, sort_keys=True))
        return 0
    if args.command == "audio":
        return 0 if audio_action(args.action) else 1
    if args.command == "brightness":
        return 0 if brightness_action(args.action) else 1
    if args.command == "audio-devices":
        print(json.dumps(audio_devices(), indent=2, sort_keys=True))
        return 0
    if args.command == "audio-default":
        return 0 if set_default_audio(args.kind, args.name) else 1
    if args.command == "night-light":
        return 0 if night_light_toggle() else 1
    if args.command == "mode":
        set_mode(args.mode)
        return 0
    if args.command == "quick":
        return 0 if quick_action(args.action) else 1
    try:
        return ControlCenterApp(start_hidden=args.daemon).run(sys.argv)
    except DependencyUnavailable:
        print(json.dumps(status_payload(), indent=2, sort_keys=True))
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
