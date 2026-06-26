"""Workspace indicator data source."""

from __future__ import annotations

from lumina_core.hyprland import workspaces


def workspace_summary() -> str:
    current = workspaces()
    if not current:
        return "Hyprland unavailable"
    names = [workspace.name or str(workspace.id) for workspace in sorted(current, key=lambda item: item.id)]
    return " ".join(names)

