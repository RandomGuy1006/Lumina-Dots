"""Motion constants derived from Lumina visual tokens."""

from __future__ import annotations

from collections.abc import Mapping
from dataclasses import dataclass
from typing import Any

from .theme import load_tokens


@dataclass(frozen=True)
class Motion:
    curve_css: str
    micro_ms: int
    panel_ms: int
    exit_ms: int
    wallpaper_ms: int


def motion(tokens: Mapping[str, Mapping[str, Any]] | None = None) -> Motion:
    data = tokens or load_tokens()
    raw = data.get("motion", {})
    return Motion(
        curve_css=str(raw.get("curve_css", "0.22, 1.0, 0.36, 1.0")),
        micro_ms=int(raw.get("micro_ms", 120)),
        panel_ms=int(raw.get("panel_ms", 250)),
        exit_ms=int(raw.get("exit_ms", 180)),
        wallpaper_ms=int(raw.get("wallpaper_ms", 900)),
    )
