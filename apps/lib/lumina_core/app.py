"""Base application wrapper for Lumina GTK/libadwaita apps."""

from __future__ import annotations

from pathlib import Path
from typing import Any

from .errors import DependencyUnavailable
from .logging import get_logger
from .theme import load_tokens, tokens_to_css
from .glass import glass_css, load_glass_config
from .windows import create_window, gtk_modules


def app_id(name: str) -> str:
    suffix = name.removeprefix("lumina-").replace("_", "-")
    return f"dev.lumina.{suffix}"


class LuminaApplication:
    def __init__(self, name: str, title: str | None = None, start_hidden: bool = False):
        self.name = name
        self.title = title or name.replace("-", " ").title()
        self.logger = get_logger(name)
        try:
            self.Gtk, self.Adw, self.Gio = gtk_modules()
        except DependencyUnavailable:
            self.logger.exception("GTK runtime unavailable")
            raise
        self.Adw.init()
        self.application = self.Adw.Application(application_id=app_id(name))
        self.application.connect("activate", self._activate)
        self.window: Any | None = None
        self.start_hidden = start_hidden
        self._initial_activation = True
        self._settings_subscription: int | None = None
        self._theme_css = ""

    def _activate(self, application: Any) -> None:
        if self.window is not None:
            if self.window.get_visible() and self.window.get_opacity() > 0:
                self.window.set_visible(False)
            else:
                self.window.set_opacity(1)
                self.window.present()
            return
        self.load_css()
        self.window = create_window(application, self.title)
        self.build(self.window)
        self._subscribe_to_settings()
        if self.start_hidden:
            from gi.repository import GLib
            self.window.set_opacity(0)
            self.window.present()
            GLib.idle_add(lambda: self.window.set_visible(False))
        else:
            self.window.present()
        self._initial_activation = False

    def _subscribe_to_settings(self) -> None:
        try:
            bus = self.Gio.bus_get_sync(self.Gio.BusType.SESSION, None)
            self._settings_subscription = bus.signal_subscribe(
                "dev.lumina.core", "dev.lumina.settings", "Changed", "/dev/lumina/core", None,
                self.Gio.DBusSignalFlags.NONE, self._handle_settings_changed,
            )
        except Exception as exc:
            self.logger.warning("D-Bus settings subscription unavailable: %s", exc)

    def _handle_settings_changed(self, _connection: Any, _sender: str, _path: str, _interface: str, _signal: str, params: Any, _user_data: Any) -> None:
        try:
            key, value = params.unpack()
            if key == "theme.css":
                self._theme_css = str(value)
        except Exception:
            pass
        self.load_css()

    def build(self, window: Any) -> None:
        label = self.Gtk.Label(label=self.title)
        window.set_content(label)

    def load_css(self, extra_css: str = "", css_path: str | Path | None = None) -> None:
        css = tokens_to_css(load_tokens(logger=self.logger)) + glass_css(load_glass_config()) + self._theme_css + extra_css
        if css_path is not None:
            path = Path(css_path).expanduser()
            if path.exists():
                css += "\n" + path.read_text(encoding="utf-8")
        provider = self.Gtk.CssProvider()
        provider.load_from_data(css.encode("utf-8"))
        from gi.repository import Gdk

        display = Gdk.Display.get_default()
        if display is None:
            self.logger.warning("No GTK display available for CSS provider")
            return
        self.Gtk.StyleContext.add_provider_for_display(
            display,
            provider,
            self.Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
        )

    def run(self, argv: list[str] | None = None) -> int:
        return int(self.application.run(argv))
