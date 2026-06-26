"""Small, dependency-free helpers for the Lumina session D-Bus contract."""

from __future__ import annotations

import json
import logging
import shutil
import subprocess
from typing import Any

BUS_NAME = "dev.lumina.core"
OBJECT_PATH = "/dev/lumina/core"


def _gvariant(value: Any) -> str:
    if isinstance(value, bool):
        return f"<{'true' if value else 'false'}>"
    if isinstance(value, int):
        return f"<int64 {value}>"
    return f"<{json.dumps(str(value), ensure_ascii=False)}>"


def emit_settings_changed(key: str, value: Any) -> None:
    """Best-effort broadcast; configuration writes remain valid off-session."""
    if not shutil.which("gdbus"):
        logging.getLogger(__name__).warning("gdbus unavailable; settings change not broadcast: %s", key)
        return
    try:
        subprocess.Popen(
            [
                "gdbus", "call", "--session", "--dest", BUS_NAME,
                "--object-path", OBJECT_PATH,
                "--method", "dev.lumina.core.EmitSettingsChanged",
                key, _gvariant(value),
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except OSError as exc:
        logging.getLogger(__name__).warning("settings change broadcast failed for %s: %s", key, exc)


def _dbus_arg(value: Any) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        return str(value)
    return json.dumps(str(value), ensure_ascii=False)


def call(method: str, *args: Any) -> bool:
    if not shutil.which("gdbus"):
        return False
    completed = subprocess.run(
        ["gdbus", "call", "--session", "--dest", BUS_NAME,
         "--object-path", OBJECT_PATH, "--method", method, *(_dbus_arg(arg) for arg in args)],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        timeout=1,
        check=False,
    )
    return completed.returncode == 0
