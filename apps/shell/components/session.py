"""Session action command builders."""

from __future__ import annotations

from lumina_core.subprocesses import run_command


def lock_session() -> bool:
    return run_command(["hyprlock"], timeout=3).ok


def open_power_menu() -> bool:
    return run_command(["wlogout", "--protocol", "layer-shell"], timeout=3).ok

