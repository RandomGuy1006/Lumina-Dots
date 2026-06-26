"""Canonical system and in-app action feedback."""

from __future__ import annotations

import shutil
import subprocess
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
    if call("dev.lumina.toast.Send", message, subtitle, category):
        return
    _system_fallback(message, subtitle, category)


def _system_fallback(message: str, subtitle: str = "", category: str = "info", icon: str = "", duration: int | None = None) -> None:
    """Notification-daemon fallback used only inside the platform toast layer."""
    category = category if category in ICON_MAP else "info"
    if not shutil.which("notify-send"): return
    timeout = DURATIONS[category] if duration is None else int(duration)
    args = ["notify-send", "--app-name=Lumina", f"--expire-time={timeout}", f"--icon={icon or ICON_MAP[category]}", message, subtitle]
    subprocess.Popen(args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


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
