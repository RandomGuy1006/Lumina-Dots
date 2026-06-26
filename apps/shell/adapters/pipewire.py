"""PipeWire adapter using Lumina Core subprocess wrappers."""

from __future__ import annotations

from lumina_core.subprocesses import run_command


def set_volume(delta: str) -> bool:
    return run_command(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", delta], timeout=3).ok

