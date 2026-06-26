"""brightnessctl adapter using Lumina Core subprocess wrappers."""

from __future__ import annotations

from lumina_core.subprocesses import run_command


def set_brightness(delta: str) -> bool:
    return run_command(["brightnessctl", "set", delta], timeout=3).ok

