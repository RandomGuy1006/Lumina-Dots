"""Session service implementing the stable dev.lumina.core D-Bus contract."""
from __future__ import annotations
import os
import sys
from pathlib import Path
from .glass import GlassMode, load_glass_config, set_glass_mode
from .mood import Mood, apply_mood, current_mood
from .search import search_results

XML = (Path(__file__).with_name("dev.lumina.core.xml")).read_text(encoding="utf-8")


def current_wallpaper() -> str:
    configured = os.environ.get("LUMINA_WALLPAPER")
    if configured:
        return configured
    marker = Path.home() / "Pictures/Wallpapers/.current"
    try:
        candidate = marker.read_text(encoding="utf-8").strip()
        return candidate if candidate and Path(candidate).is_file() else ""
    except OSError:
        return ""


def battery_state() -> tuple[int, bool]:
    for battery in sorted(Path("/sys/class/power_supply").glob("BAT*")):
        try:
            percent = int((battery / "capacity").read_text(encoding="utf-8").strip())
            status = (battery / "status").read_text(encoding="utf-8").strip().lower()
            return percent, status == "discharging"
        except (OSError, ValueError):
            continue
    return -1, False


def main() -> int:
    try:
        import gi
        gi.require_version("Gio", "2.0")
        from gi.repository import Gio, GLib
    except (ImportError, ValueError) as exc:
        print(f"lumina-core-service: {exc}", file=sys.stderr); return 1
    loop = GLib.MainLoop(); node = Gio.DBusNodeInfo.new_for_xml(XML)

    def variant_to_string(value):
        try:
            unpacked = value.unpack()
        except Exception:
            unpacked = value
        return str(unpacked)

    def method(connection, sender, path, interface, method, params, invocation):
        values = params.unpack()
        try:
            if interface == "dev.lumina.core" and method == "EmitSettingsChanged":
                value=params.get_child_value(1).get_variant(); key=values[0]
                connection.emit_signal(None, path, "dev.lumina.settings", "Changed", GLib.Variant("(sv)", (key, value)))
                related={"mood":("dev.lumina.mood","Changed"),"glass":("dev.lumina.glass","Changed"),"wallpaper":("dev.lumina.wallpaper","Changed")}.get(key)
                if related: connection.emit_signal(None,path,related[0],related[1],GLib.Variant("(s)",(variant_to_string(value),)))
            elif interface == "dev.lumina.toast" and method == "Send":
                from .toasts import _system_fallback
                message, subtitle, category = values
                _system_fallback(message, subtitle, category)
                connection.emit_signal(None, path, "dev.lumina.toast", "Toast", GLib.Variant("(ss)", (message, category)))
            elif interface == "dev.lumina.glass" and method == "Set":
                mode = GlassMode(values[0]); set_glass_mode(mode); connection.emit_signal(None, path, interface, "Changed", GLib.Variant("(s)", (mode.value,)))
            elif interface == "dev.lumina.mood" and method == "Apply":
                mood = Mood(values[0]); apply_mood(mood); connection.emit_signal(None, path, interface, "Changed", GLib.Variant("(s)", (mood.value,)))
            elif interface == "dev.lumina.search" and method == "Query": invocation.return_value(GLib.Variant("(a(sssss))", (search_results(values[0]),))); return
            invocation.return_value(None)
        except Exception as exc: invocation.return_dbus_error("dev.lumina.Error", str(exc))

    def get_property(_connection, _sender, _path, _interface, prop):
        if prop == "CurrentMood": return GLib.Variant("s", current_mood().value)
        if prop == "CurrentGlass": return GLib.Variant("s", load_glass_config().mode.value)
        if prop == "CurrentWallpaper": return GLib.Variant("s", current_wallpaper())
        if prop == "BatteryPercent": return GLib.Variant("i", battery_state()[0])
        if prop == "OnBattery": return GLib.Variant("b", battery_state()[1])
        return None

    def acquired(connection, _name):
        for interface in node.interfaces: connection.register_object("/dev/lumina/core", interface, method, get_property, None)
    owner = Gio.bus_own_name(Gio.BusType.SESSION, "dev.lumina.core", Gio.BusNameOwnerFlags.NONE, acquired, None, lambda *_: loop.quit())
    try: loop.run()
    finally: Gio.bus_unown_name(owner)
    return 0

if __name__ == "__main__": raise SystemExit(main())
