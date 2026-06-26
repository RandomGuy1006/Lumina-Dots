"""Backend-neutral public contracts for Lumina shell consumers."""

from __future__ import annotations

import time
from dataclasses import asdict, dataclass, field
from typing import Any, Literal

SHELL_CONTRACT_VERSION = 1


@dataclass(frozen=True)
class ContractEnvelope:
    kind: str
    data: Any
    schema_version: int = SHELL_CONTRACT_VERSION
    timestamp: float = field(default_factory=time.time)

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass(frozen=True)
class WorkspaceSnapshot:
    id: int
    name: str
    monitor: str
    windows: int
    focused: bool = False


@dataclass(frozen=True)
class OSDPayload:
    kind: str
    value: int
    label: str
    timeout_ms: int


@dataclass(frozen=True)
class PopupPayload:
    id: str
    category: str
    title: str
    body: str
    urgency: Literal["low", "normal", "critical"]
    icon: str
    progress: int | None
    timeout_ms: int


@dataclass(frozen=True)
class ModeTransitionPayload:
    previous: str
    current: str
    animation: str
    animation_scale: float


def envelope(kind: str, data: Any) -> dict[str, Any]:
    return ContractEnvelope(kind=kind, data=data).to_dict()


def capabilities() -> dict[str, Any]:
    return envelope(
        "shell.capabilities",
        {
            "queries": ["status", "modes", "capabilities", "snapshot", "tokens"],
            "commands": ["mode", "osd", "popup"],
            "events": ["hyprland", "mode", "osd", "popup"],
            "production_frontends": ["gtk", "hyprpanel"],
            "experimental_frontends": [],
        },
    )
