"""OSD model and fallback presentation for Lumina Shell."""

from __future__ import annotations

from dataclasses import dataclass

from lumina_core.contracts import OSDPayload
from lumina_core.logging import get_logger
from lumina_core.state import save_versioned_state

from components.popups import PopupEngine, event_popup


@dataclass(frozen=True)
class OSDState:
    kind: str
    value: int
    label: str
    timeout_ms: int


class OSDController:
    def __init__(self, timeout_ms: int = 1200):
        self.timeout_ms = timeout_ms
        self.logger = get_logger("lumina-shell-osd")

    def show(self, *, kind: str, value: int, label: str) -> OSDState:
        value = max(0, min(100, int(value)))
        state = OSDState(kind=kind, value=value, label=label, timeout_ms=self.timeout_ms)
        contract = OSDPayload(kind=kind, value=value, label=label, timeout_ms=self.timeout_ms)
        save_versioned_state("shell/osd-last.json", "shell.osd", contract.__dict__)
        self.logger.info("OSD %s: %s%%", kind, value)
        PopupEngine().show(event_popup(kind, body=label, progress=value))
        return state
