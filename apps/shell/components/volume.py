"""PipeWire volume helpers."""

from __future__ import annotations

import re
from dataclasses import dataclass

from lumina_core.subprocesses import run_command


@dataclass(frozen=True)
class VolumeState:
    percent: int
    muted: bool = False


def current_volume() -> VolumeState:
    result = run_command(["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"], timeout=3)
    if not result.ok:
        return VolumeState(percent=0, muted=False)
    match = re.search(r"Volume:\s+([0-9.]+)", result.stdout)
    muted = "[MUTED]" in result.stdout
    if not match:
        return VolumeState(percent=0, muted=muted)
    return VolumeState(percent=round(float(match.group(1)) * 100), muted=muted)

