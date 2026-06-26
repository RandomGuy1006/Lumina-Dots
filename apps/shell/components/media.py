"""Media state helpers."""

from __future__ import annotations

from lumina_core.subprocesses import run_command


def media_status() -> str:
    result = run_command(["playerctl", "status"], timeout=3)
    return result.stdout.strip() if result.ok else "unavailable"

