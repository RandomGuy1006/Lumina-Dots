"""playerctl adapter using Lumina Core subprocess wrappers."""

from __future__ import annotations

from lumina_core.subprocesses import run_command


def play_pause() -> bool:
    return run_command(["playerctl", "play-pause"], timeout=3).ok

