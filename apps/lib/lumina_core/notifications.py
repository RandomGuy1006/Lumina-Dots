"""Compatibility adapter for the canonical Lumina toast API."""

from __future__ import annotations

from typing import Any

from .toasts import toast


def notify(
    title: str,
    body: str = "",
    *,
    urgency: str = "normal",
    app_name: str = "Lumina",
    timeout_ms: int | None = None,
    logger: Any | None = None,
) -> bool:
    category = "error" if urgency == "critical" else "info" if urgency == "low" else "warning"
    toast(title, body, category=category)
    return True
