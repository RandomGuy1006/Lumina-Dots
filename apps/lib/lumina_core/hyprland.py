"""Hyprland query wrappers and static config parsers."""

from __future__ import annotations

from collections.abc import Iterable
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from .subprocesses import run_json_command


@dataclass(frozen=True)
class HyprClient:
    address: str
    title: str
    class_name: str
    workspace: str
    focused: bool = False


@dataclass(frozen=True)
class HyprWorkspace:
    id: int
    name: str
    monitor: str = ""
    windows: int = 0
    focused: bool = False


@dataclass(frozen=True)
class HyprMonitor:
    id: int
    name: str
    width: int = 0
    height: int = 0
    focused: bool = False


def monitors(logger: Any | None = None) -> list[HyprMonitor]:
    result, data = run_json_command(["hyprctl", "-j", "monitors"], timeout=3, logger=logger)
    if not result.ok or not isinstance(data, list):
        return []
    return [
        HyprMonitor(
            id=int(item.get("id", 0)),
            name=str(item.get("name", "")),
            width=int(item.get("width", 0)),
            height=int(item.get("height", 0)),
            focused=bool(item.get("focused", False)),
        )
        for item in data
        if isinstance(item, dict)
    ]


def workspaces(logger: Any | None = None) -> list[HyprWorkspace]:
    result, data = run_json_command(["hyprctl", "-j", "workspaces"], timeout=3, logger=logger)
    if not result.ok or not isinstance(data, list):
        return []
    return [
        HyprWorkspace(
            id=int(item.get("id", 0)),
            name=str(item.get("name", "")),
            monitor=str(item.get("monitor", "")),
            windows=int(item.get("windows", 0)),
            focused=bool(item.get("focused", False)),
        )
        for item in data
        if isinstance(item, dict)
    ]


def clients(logger: Any | None = None) -> list[HyprClient]:
    result, data = run_json_command(["hyprctl", "-j", "clients"], timeout=3, logger=logger)
    if not result.ok or not isinstance(data, list):
        return []
    parsed: list[HyprClient] = []
    for item in data:
        if not isinstance(item, dict):
            continue
        workspace = item.get("workspace", {})
        workspace_name = workspace.get("name", "") if isinstance(workspace, dict) else ""
        parsed.append(
            HyprClient(
                address=str(item.get("address", "")),
                title=str(item.get("title", "")),
                class_name=str(item.get("class", "")),
                workspace=str(workspace_name),
                focused=bool(item.get("focusHistoryID", -1) == 0),
            )
        )
    return parsed


def focused_window(logger: Any | None = None) -> HyprClient | None:
    for client in clients(logger):
        if client.focused:
            return client
    return None


@dataclass(frozen=True)
class Keybind:
    modifiers: str
    key: str
    dispatcher: str
    command: str
    source: Path


def parse_keybind_line(line: str, source: Path) -> Keybind | None:
    stripped = line.split("#", 1)[0].strip()
    if not stripped.startswith("bind"):
        return None
    _, _, rhs = stripped.partition("=")
    if not rhs:
        return None
    parts = [part.strip() for part in rhs.split(",", 3)]
    if len(parts) < 3:
        return None
    while len(parts) < 4:
        parts.append("")
    return Keybind(parts[0], parts[1], parts[2], parts[3], source)


def parse_keybinds(paths: Iterable[str | Path]) -> list[Keybind]:
    binds: list[Keybind] = []
    for raw_path in paths:
        path = Path(raw_path)
        try:
            for line in path.read_text(encoding="utf-8").splitlines():
                bind = parse_keybind_line(line, path)
                if bind is not None:
                    binds.append(bind)
        except FileNotFoundError:
            continue
    return binds
