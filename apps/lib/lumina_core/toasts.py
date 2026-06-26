"""Canonical system and in-app action feedback."""

from __future__ import annotations

from typing import Any

from .ipc import call

ICON_MAP = {"info": "dialog-information-symbolic", "success": "emblem-ok-symbolic", "warning": "dialog-warning-symbolic", "error": "dialog-error-symbolic"}
DURATIONS = {"info": 2000, "success": 2000, "warning": 4000, "error": 6000}


def toast(
    message: str,
    subtitle: str = "",
    category: str = "info",
) -> None:
    category = category if category in ICON_MAP else "info"
    call("dev.lumina.toast.Send", message, subtitle, category)


class LuminaToastOverlay:
    def __init__(self, child: Any):
        from gi.repository import Adw
        self._overlay = Adw.ToastOverlay()
        self._overlay.set_child(child)

    def toast(self, message: str, timeout: int | None = None, action_label: str = "", action_callback: Any = None, category: str = "info") -> None:
        from gi.repository import Adw, Gtk
        item = Adw.Toast.new(message)
        seconds = (DURATIONS.get(category, DURATIONS["info"]) // 1000) if timeout is None else timeout
        item.set_timeout(seconds)
        if category == "error":
            item.set_priority(Adw.ToastPriority.HIGH)
        if action_label:
            item.set_button_label(action_label)
            if action_callback:
                item.connect("button-clicked", action_callback)
        self._overlay.add_toast(item)
        if hasattr(self._overlay, "announce"):
            self._overlay.announce(message, Gtk.AccessibleAnnouncementPriority.HIGH if category == "error" else Gtk.AccessibleAnnouncementPriority.MEDIUM)
        else:
            self._overlay.update_property([Gtk.AccessibleProperty.LABEL], [message])

    @property
    def widget(self) -> Any:
        return self._overlay
