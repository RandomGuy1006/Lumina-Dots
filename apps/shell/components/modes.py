"""Lumina Modes Framework."""

from __future__ import annotations

from collections.abc import Mapping
from dataclasses import asdict, dataclass

from lumina_core.contracts import ModeTransitionPayload
from lumina_core.errors import StateError
from lumina_core.state import load_json_state, load_versioned_state, save_versioned_state

from components.popups import dispatch_event

VALID_MODES = {"quiet", "auto", "performance", "custom"}


@dataclass(frozen=True)
class ModeProfile:
    name: str
    label: str
    description: str
    animation_scale: float
    polling_ms: int
    visual_effects: str
    hardware_aware: bool
    identity: str
    selection_animation: str


MODE_PROFILES: dict[str, ModeProfile] = {
    "quiet": ModeProfile(
        name="quiet",
        label="Quiet Mode",
        description="Reduced animations, lower polling rates, and battery-friendly shell behavior.",
        animation_scale=0.45,
        polling_ms=5000,
        visual_effects="reduced",
        hardware_aware=False,
        identity="calm",
        selection_animation="soft-fade",
    ),
    "auto": ModeProfile(
        name="auto",
        label="Auto Mode",
        description="Hardware-aware defaults that balance visual polish and power use.",
        animation_scale=1.0,
        polling_ms=2000,
        visual_effects="balanced",
        hardware_aware=True,
        identity="adaptive",
        selection_animation="adaptive-slide",
    ),
    "performance": ModeProfile(
        name="performance",
        label="Performance Mode",
        description="Full visual effects, faster updates, and maximum responsiveness.",
        animation_scale=1.15,
        polling_ms=750,
        visual_effects="full",
        hardware_aware=True,
        identity="sharp",
        selection_animation="snap-rise",
    ),
    "custom": ModeProfile(
        name="custom",
        label="Custom Mode",
        description="User-configurable mode with a distinct visual identity and mode-selection animation.",
        animation_scale=1.0,
        polling_ms=1500,
        visual_effects="custom",
        hardware_aware=False,
        identity="custom-glow",
        selection_animation="custom-prism",
    ),
}


def current_mode() -> str:
    try:
        state = load_versioned_state("shell/mode.json", "shell.mode", {"mode": "auto"})
    except StateError:
        state = load_json_state("shell/mode.json", {"mode": "auto"})
    mode = str(state.get("mode", "auto")) if isinstance(state, dict) else "auto"
    return mode if mode in VALID_MODES else "auto"


def current_profile() -> ModeProfile:
    mode = current_mode()
    if mode != "custom":
        return MODE_PROFILES[mode]
    try:
        custom = load_versioned_state("shell/custom-mode.json", "shell.custom-mode", {})
    except StateError:
        custom = load_json_state("shell/custom-mode.json", {})
    if not isinstance(custom, Mapping):
        return MODE_PROFILES["custom"]
    base = MODE_PROFILES["custom"]
    return ModeProfile(
        name="custom",
        label=str(custom.get("label", base.label)),
        description=str(custom.get("description", base.description)),
        animation_scale=float(custom.get("animation_scale", base.animation_scale)),
        polling_ms=int(custom.get("polling_ms", base.polling_ms)),
        visual_effects=str(custom.get("visual_effects", base.visual_effects)),
        hardware_aware=bool(custom.get("hardware_aware", base.hardware_aware)),
        identity=str(custom.get("identity", base.identity)),
        selection_animation=str(custom.get("selection_animation", base.selection_animation)),
    )


def set_mode(mode: str) -> str:
    normalized = mode.lower()
    if normalized not in VALID_MODES:
        raise ValueError(f"Unsupported Lumina mode: {mode}")
    previous = current_mode()
    save_versioned_state("shell/mode.json", "shell.mode", {"mode": normalized})
    profile = current_profile()
    transition = ModeTransitionPayload(
        previous=previous,
        current=normalized,
        animation=profile.selection_animation,
        animation_scale=profile.animation_scale,
    )
    save_versioned_state(
        "shell/mode-transition.json",
        "shell.mode-transition",
        asdict(transition),
    )
    dispatch_event("mode", body=profile.label, progress=None)
    return normalized


def configure_custom_mode(settings: Mapping[str, object]) -> ModeProfile:
    allowed = {
        "label",
        "description",
        "animation_scale",
        "polling_ms",
        "visual_effects",
        "hardware_aware",
        "identity",
        "selection_animation",
    }
    save_versioned_state(
        "shell/custom-mode.json",
        "shell.custom-mode",
        {key: value for key, value in settings.items() if key in allowed},
    )
    return current_profile()


def mode_api_payload() -> dict[str, object]:
    return {
        "current": current_mode(),
        "profile": asdict(current_profile()),
        "available": {name: asdict(profile) for name, profile in MODE_PROFILES.items()},
    }
