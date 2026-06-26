"""Universal popup framework for Lumina Shell surfaces."""

from __future__ import annotations

import time
import uuid
from collections import deque
from collections.abc import Iterable
from dataclasses import asdict, dataclass, field
from typing import Literal

from lumina_core.animations import motion
from lumina_core.contracts import PopupPayload
from lumina_core.logging import get_logger
from lumina_core.notifications import notify
from lumina_core.state import load_json_state, save_json_state, save_versioned_state
from lumina_core.subprocesses import CommandResult, run_command
from lumina_core.theme import load_tokens

PopupUrgency = Literal["low", "normal", "critical"]


@dataclass(frozen=True)
class PopupAction:
    label: str
    command: tuple[str, ...]
    icon: str = "system-run-symbolic"

    def run(self) -> CommandResult:
        return run_command(self.command, timeout=10)


@dataclass(frozen=True)
class PopupRequest:
    category: str
    title: str
    body: str = ""
    urgency: PopupUrgency = "normal"
    icon: str = "dialog-information-symbolic"
    progress: int | None = None
    actions: tuple[PopupAction, ...] = ()
    timeout_ms: int = 1200
    created_at: float = field(default_factory=time.time)
    popup_id: str = field(default_factory=lambda: uuid.uuid4().hex)

    def normalized_progress(self) -> int | None:
        if self.progress is None:
            return None
        return max(0, min(100, int(self.progress)))


@dataclass(frozen=True)
class PopupAnimation:
    enter_ms: int
    exit_ms: int
    curve_css: str


class PopupQueue:
    def __init__(self, state_name: str = "shell/popup-queue.json"):
        self.state_name = state_name
        self.logger = get_logger("lumina-popup-queue")
        self._queue: deque[PopupRequest] = deque(self._load())

    def _load(self) -> list[PopupRequest]:
        raw = load_json_state(self.state_name, [])
        requests: list[PopupRequest] = []
        if not isinstance(raw, list):
            return requests
        for item in raw:
            if not isinstance(item, dict):
                continue
            actions = tuple(
                PopupAction(
                    label=str(action.get("label", "Run")),
                    command=tuple(str(part) for part in action.get("command", [])),
                    icon=str(action.get("icon", "system-run-symbolic")),
                )
                for action in item.get("actions", [])
                if isinstance(action, dict) and action.get("command")
            )
            requests.append(
                PopupRequest(
                    category=str(item.get("category", "general")),
                    title=str(item.get("title", "Lumina")),
                    body=str(item.get("body", "")),
                    urgency=str(item.get("urgency", "normal")),  # type: ignore[arg-type]
                    icon=str(item.get("icon", "dialog-information-symbolic")),
                    progress=item.get("progress"),
                    actions=actions,
                    timeout_ms=int(item.get("timeout_ms", 1200)),
                    created_at=float(item.get("created_at", time.time())),
                    popup_id=str(item.get("popup_id", uuid.uuid4().hex)),
                )
            )
        return requests

    def _save(self) -> None:
        save_json_state(
            self.state_name,
            [
                {
                    **asdict(request),
                    "actions": [asdict(action) for action in request.actions],
                    "progress": request.normalized_progress(),
                }
                for request in self._queue
            ],
        )

    def enqueue(self, request: PopupRequest) -> None:
        self._queue.append(request)
        self._save()
        self.logger.info("Queued popup %s: %s", request.category, request.title)

    def pop(self) -> PopupRequest | None:
        if not self._queue:
            return None
        request = self._queue.popleft()
        self._save()
        return request

    def pending(self) -> list[PopupRequest]:
        return list(self._queue)


class PopupEngine:
    def __init__(self, queue: PopupQueue | None = None):
        self.queue = queue or PopupQueue()
        self.logger = get_logger("lumina-popup")

    def animation(self) -> PopupAnimation:
        current_motion = motion()
        return PopupAnimation(
            enter_ms=current_motion.panel_ms,
            exit_ms=current_motion.exit_ms,
            curve_css=current_motion.curve_css,
        )

    def show(self, request: PopupRequest) -> PopupRequest:
        self.queue.enqueue(request)
        active = self.queue.pop()
        if active is None:
            return request
        contract = PopupPayload(
            id=active.popup_id,
            category=active.category,
            title=active.title,
            body=active.body,
            urgency=active.urgency,
            icon=active.icon,
            progress=active.normalized_progress(),
            timeout_ms=active.timeout_ms,
        )
        save_versioned_state(
            "shell/popup-last.json",
            "shell.popup",
            {
                **asdict(contract),
                "actions": [asdict(action) for action in active.actions],
                "animation": asdict(self.animation()),
                "style": popup_style_tokens(),
            },
        )
        append_activity(
            {
                "type": "popup",
                "category": active.category,
                "title": active.title,
                "body": active.body,
                "urgency": active.urgency,
                "progress": active.normalized_progress(),
                "created_at": active.created_at,
            }
        )
        body = active.body
        progress = active.normalized_progress()
        if progress is not None:
            body = f"{body}\n{progress}%" if body else f"{progress}%"
        notify(
            active.title,
            body,
            urgency="critical" if active.urgency == "critical" else "normal",
            app_name="Lumina Shell",
            timeout_ms=active.timeout_ms,
            logger=self.logger,
        )
        return active

    def show_many(self, requests: Iterable[PopupRequest]) -> list[PopupRequest]:
        return [self.show(request) for request in requests]


def popup_style_tokens() -> dict:
    tokens = load_tokens()
    return {
        "surface": tokens["colors"]["surface"],
        "foreground": tokens["colors"]["fg"],
        "accent": tokens["colors"]["accent"],
        "warning": tokens["colors"]["warning"],
        "danger": tokens["colors"]["danger"],
        "radius": tokens["radius"]["shell"],
        "padding": tokens["spacing"]["panel"],
        "gap": tokens["spacing"]["item"],
        "font_family": tokens["typography"]["ui_family"],
        "body_size": tokens["typography"]["body_px"],
        "title_size": tokens["typography"]["title_px"],
        "line_height": tokens["typography"]["line_height"],
        "icon_size": tokens["icons"]["large"],
        "border_width": tokens["stroke"]["hairline"],
        "surface_opacity": tokens["opacity"]["surface_strong"],
        "curve": tokens["motion"]["curve_css"],
    }


EVENT_DEFAULTS: dict[str, dict[str, object]] = {
    "volume": {"title": "Volume", "icon": "audio-volume-high-symbolic"},
    "brightness": {"title": "Brightness", "icon": "display-brightness-symbolic"},
    "microphone": {"title": "Microphone", "icon": "audio-input-microphone-symbolic"},
    "camera": {"title": "Camera", "icon": "camera-web-symbolic"},
    "wallpaper": {"title": "Wallpaper changed", "icon": "preferences-desktop-wallpaper-symbolic"},
    "theme": {"title": "Theme changed", "icon": "preferences-desktop-theme-symbolic"},
    "screenshot": {"title": "Screenshot saved", "icon": "camera-photo-symbolic"},
    "bluetooth-connected": {"title": "Bluetooth connected", "icon": "bluetooth-active-symbolic"},
    "bluetooth-disconnected": {"title": "Bluetooth disconnected", "icon": "bluetooth-disabled-symbolic"},
    "battery": {"title": "Battery warning", "icon": "battery-caution-symbolic", "urgency": "critical"},
    "mode": {"title": "Lumina mode changed", "icon": "preferences-system-symbolic"},
}


def event_popup(
    event: str,
    *,
    body: str = "",
    progress: int | None = None,
    actions: Iterable[PopupAction] = (),
    urgency: PopupUrgency | None = None,
) -> PopupRequest:
    defaults = EVENT_DEFAULTS.get(event, {"title": event.replace("-", " ").title(), "icon": "dialog-information-symbolic"})
    return PopupRequest(
        category=event,
        title=str(defaults.get("title", event.title())),
        body=body,
        urgency=urgency or str(defaults.get("urgency", "normal")),  # type: ignore[arg-type]
        icon=str(defaults.get("icon", "dialog-information-symbolic")),
        progress=progress,
        actions=tuple(actions),
    )


def dispatch_event(event: str, *, body: str = "", progress: int | None = None, urgency: PopupUrgency | None = None) -> PopupRequest:
    return PopupEngine().show(event_popup(event, body=body, progress=progress, urgency=urgency))


def append_activity(entry: dict[str, object], limit: int = 200) -> None:
    history = load_json_state("activity/history.json", [])
    if not isinstance(history, list):
        history = []
    history.append(entry)
    save_json_state("activity/history.json", history[-limit:])
