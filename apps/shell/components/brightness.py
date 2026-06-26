"""Brightness helpers."""

from __future__ import annotations

from dataclasses import dataclass

from lumina_core.subprocesses import run_command


@dataclass(frozen=True)
class BrightnessState:
    percent: int


def current_brightness() -> BrightnessState:
    result = run_command(["brightnessctl", "-m"], timeout=3)
    if not result.ok:
        return BrightnessState(percent=0)
    parts = result.stdout.strip().split(",")
    if len(parts) >= 4 and parts[3].endswith("%"):
        try:
            return BrightnessState(percent=int(parts[3].rstrip("%")))
        except ValueError:
            pass
    return BrightnessState(percent=0)

