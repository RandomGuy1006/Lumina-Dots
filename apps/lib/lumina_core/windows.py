"""Shared GTK/libadwaita window helpers."""

from __future__ import annotations

from typing import Any

from .errors import DependencyUnavailable


def gtk_modules() -> tuple[Any, Any, Any]:
    try:
        import gi

        gi.require_version("Gtk", "4.0")
        gi.require_version("Adw", "1")
        from gi.repository import Adw, Gio, Gtk

        return Gtk, Adw, Gio
    except (ImportError, ValueError) as exc:
        raise DependencyUnavailable(f"GTK4/libadwaita bindings unavailable: {exc}") from exc


def create_window(application: Any, title: str, *, width: int = 720, height: int = 480, css_class: str = "lumina-window") -> Any:
    Gtk, Adw, _Gio = gtk_modules()
    window = Adw.ApplicationWindow(application=application)
    window.set_title(title)
    window.set_default_size(width, height)
    if css_class:
        window.add_css_class(css_class)
    return window


def close_on_escape(window: Any) -> None:
    Gtk, _Adw, _Gio = gtk_modules()
    from gi.repository import Gdk
    controller = Gtk.EventControllerKey()

    def on_key(_controller: Any, keyval: int, _keycode: int, _state: int) -> bool:
        if keyval == Gdk.KEY_Escape:
            window.close()
            return True
        return False

    controller.connect("key-pressed", on_key)
    window.add_controller(controller)
