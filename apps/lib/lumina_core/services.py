"""systemd user service helpers."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from .subprocesses import CommandResult, run_command


@dataclass(frozen=True)
class ServiceStatus:
    name: str
    active: bool
    available: bool
    detail: str = ""


def user_bus_available(logger: Any | None = None) -> bool:
    result = run_command(["systemctl", "--user", "show-environment"], timeout=3, logger=logger)
    return result.ok


def service_status(unit: str, logger: Any | None = None) -> ServiceStatus:
    if not user_bus_available(logger):
        return ServiceStatus(name=unit, active=False, available=False, detail="systemd user bus unavailable")
    result = run_command(["systemctl", "--user", "is-active", unit], timeout=3, logger=logger)
    return ServiceStatus(name=unit, active=result.stdout.strip() == "active", available=True, detail=result.stdout.strip() or result.stderr.strip())


def service_action(action: str, unit: str, logger: Any | None = None) -> CommandResult:
    if action not in {"start", "stop", "restart", "enable", "disable"}:
        raise ValueError(f"Unsupported service action: {action}")
    return run_command(["systemctl", "--user", action, unit], timeout=10, logger=logger)


def enable_now(unit: str, logger: Any | None = None) -> CommandResult:
    return run_command(["systemctl", "--user", "enable", "--now", unit], timeout=10, logger=logger)

