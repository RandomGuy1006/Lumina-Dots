"""Dashboard state collection for Lumina Shell."""

from __future__ import annotations

from lumina_core.services import service_status


def dashboard_summary() -> dict[str, str]:
    hyprpanel = service_status("loq-hyprpanel.service")
    shell = service_status("lumina-shell.service")
    return {
        "shell": "active" if shell.active else shell.detail or "inactive",
        "hyprpanel": "active" if hyprpanel.active else hyprpanel.detail or "inactive",
    }

