"""Reconnecting reader for Hyprland's event socket."""

from __future__ import annotations

import os
import socket
import time
from collections.abc import Callable, Iterator
from dataclasses import dataclass
from pathlib import Path

from lumina_core.logging import get_logger


@dataclass(frozen=True)
class HyprlandEvent:
    name: str
    payload: str

    def to_dict(self) -> dict[str, str]:
        return {"name": self.name, "payload": self.payload}


def parse_event(line: str) -> HyprlandEvent | None:
    name, separator, payload = line.strip().partition(">>")
    if not separator or not name:
        return None
    return HyprlandEvent(name=name, payload=payload)


def event_socket_path(environment: dict[str, str] | None = None) -> Path | None:
    env = environment or os.environ
    signature = env.get("HYPRLAND_INSTANCE_SIGNATURE")
    runtime = env.get("XDG_RUNTIME_DIR")
    if not signature or not runtime:
        return None
    return Path(runtime) / "hypr" / signature / ".socket2.sock"


def event_stream(
    *,
    stop: Callable[[], bool] | None = None,
    reconnect_delay: float = 1.0,
    socket_path: Path | None = None,
) -> Iterator[HyprlandEvent]:
    logger = get_logger("lumina-shell-hyprland-events")
    path = socket_path or event_socket_path()
    if path is None:
        logger.info("Hyprland event socket unavailable outside an active session")
        return
    should_stop = stop or (lambda: False)
    while not should_stop():
        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
                client.settimeout(1.0)
                client.connect(str(path))
                logger.info("Connected to Hyprland event socket: %s", path)
                buffer = ""
                while not should_stop():
                    try:
                        chunk = client.recv(4096)
                    except TimeoutError:
                        continue
                    if not chunk:
                        break
                    buffer += chunk.decode("utf-8", errors="replace")
                    while "\n" in buffer:
                        line, buffer = buffer.split("\n", 1)
                        event = parse_event(line)
                        if event is not None:
                            yield event
        except (FileNotFoundError, ConnectionError, OSError) as exc:
            logger.warning("Hyprland event socket unavailable: %s", exc)
        if not should_stop():
            time.sleep(max(0.1, reconnect_delay))
