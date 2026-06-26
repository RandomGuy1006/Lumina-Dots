"""Shared GTK widget helpers for Lumina apps."""

from __future__ import annotations

from typing import Any

from .windows import gtk_modules


def section_heading(text: str) -> Any:
    Gtk, _Adw, _Gio = gtk_modules()
    label = Gtk.Label(label=text)
    label.set_xalign(0)
    label.add_css_class("title-3")
    return label


def status_badge(text: str, *, kind: str = "neutral") -> Any:
    Gtk, _Adw, _Gio = gtk_modules()
    label = Gtk.Label(label=text)
    label.add_css_class("lumina-badge")
    label.add_css_class(f"lumina-badge-{kind}")
    return label


def command_button(label: str, callback: Any, *, icon_name: str | None = None) -> Any:
    Gtk, _Adw, _Gio = gtk_modules()
    button = Gtk.Button(label=label)
    if icon_name:
        button.set_icon_name(icon_name)
    button.connect("clicked", callback)
    return button

