"""Optional gtk4-layer-shell integration."""

from __future__ import annotations

from typing import Any

from .errors import DependencyUnavailable


def layer_shell_module() -> Any:
    try:
        import gi

        gi.require_version("Gtk4LayerShell", "1.0")
        from gi.repository import Gtk4LayerShell

        return Gtk4LayerShell
    except (ImportError, ValueError) as exc:
        raise DependencyUnavailable(f"gtk4-layer-shell bindings unavailable: {exc}") from exc


def setup_layer_window(window: Any, *, anchor: str = "top", exclusive: bool = False, namespace: str = "lumina-shell") -> bool:
    try:
        layer_shell = layer_shell_module()
    except DependencyUnavailable:
        return False

    layer_shell.init_for_window(window)
    layer_shell.set_namespace(window, namespace)
    layer_shell.set_layer(window, layer_shell.Layer.OVERLAY)
    if anchor == "top":
        layer_shell.set_anchor(window, layer_shell.Edge.TOP, True)
    elif anchor == "top-right":
        layer_shell.set_anchor(window, layer_shell.Edge.TOP, True)
        layer_shell.set_anchor(window, layer_shell.Edge.RIGHT, True)
    elif anchor == "fullscreen":
        for edge in (layer_shell.Edge.TOP, layer_shell.Edge.RIGHT, layer_shell.Edge.BOTTOM, layer_shell.Edge.LEFT):
            layer_shell.set_anchor(window, edge, True)
    elif anchor == "bottom":
        layer_shell.set_anchor(window, layer_shell.Edge.BOTTOM, True)
    if exclusive:
        layer_shell.auto_exclusive_zone_enable(window)
    return True
