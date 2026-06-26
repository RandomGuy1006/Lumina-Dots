"""Safe subprocess wrappers for Lumina applications."""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from .errors import CommandError


def _resolve_executable(executable: str) -> str:
    if not executable or os.sep in executable or (os.altsep and os.altsep in executable):
        return executable
    installed = shutil.which(executable)
    if installed:
        return installed
    if executable.startswith("lumina-") or executable.startswith("wallpaper-"):
        repo_candidate = Path(__file__).resolve().parents[3] / "local-bin" / ".local" / "bin" / executable
        user_candidate = Path.home() / ".local" / "bin" / executable
        candidate = next((path for path in (repo_candidate, user_candidate) if path.exists()), None)
        if candidate is not None:
            return str(candidate) if os.name != "nt" else sys.executable
    return executable


def _normalize_args(args: Sequence[str]) -> tuple[str, ...]:
    normalized = tuple(str(arg) for arg in args)
    if not normalized:
        return normalized
    executable = normalized[0]
    resolved = _resolve_executable(executable)
    if os.name == "nt" and resolved == sys.executable and executable != sys.executable:
        for candidate in (
            Path(__file__).resolve().parents[3] / "local-bin" / ".local" / "bin" / executable,
            Path.home() / ".local" / "bin" / executable,
        ):
            if candidate.exists():
                return (sys.executable, str(candidate), *normalized[1:])
    return (resolved, *normalized[1:])


def _text_output(value: bytes | str | None) -> str:
    if value is None:
        return ""
    if isinstance(value, bytes):
        return value.decode(errors="replace")
    return value


@dataclass(frozen=True)
class CommandResult:
    args: tuple[str, ...]
    exit_code: int
    stdout: str = ""
    stderr: str = ""
    timed_out: bool = False
    missing: bool = False

    @property
    def ok(self) -> bool:
        return self.exit_code == 0 and not self.timed_out and not self.missing

    def raise_for_status(self) -> None:
        if not self.ok:
            raise CommandError(
                f"Command failed ({self.exit_code}): {' '.join(self.args)}\n"
                f"stdout: {self.stdout.strip()}\nstderr: {self.stderr.strip()}"
            )


def _log_result(logger: Any | None, result: CommandResult) -> None:
    if logger is None:
        return
    if result.ok:
        debug = getattr(logger, "debug", None)
        if callable(debug):
            debug("Command OK: %s", " ".join(result.args))
    else:
        warning = getattr(logger, "warning", None)
        if callable(warning):
            warning("Command failed: %s: %s", " ".join(result.args), result.stderr.strip())


def run_command(
    args: Sequence[str],
    *,
    timeout: float = 5,
    check: bool = False,
    cwd: str | os.PathLike[str] | None = None,
    env: Mapping[str, str] | None = None,
    input_text: str | None = None,
    logger: Any | None = None,
) -> CommandResult:
    normalized = _normalize_args(args)
    try:
        completed = subprocess.run(
            normalized,
            cwd=Path(cwd).expanduser() if cwd is not None else None,
            env=dict(env) if env is not None else None,
            input=input_text,
            text=True,
            capture_output=True,
            timeout=timeout,
            check=False,
        )
        result = CommandResult(
            args=normalized,
            exit_code=completed.returncode,
            stdout=completed.stdout,
            stderr=completed.stderr,
        )
    except FileNotFoundError as exc:
        result = CommandResult(args=normalized, exit_code=127, stderr=str(exc), missing=True)
    except PermissionError as exc:
        result = CommandResult(args=normalized, exit_code=126, stderr=str(exc))
    except OSError as exc:
        result = CommandResult(args=normalized, exit_code=1, stderr=str(exc))
    except subprocess.TimeoutExpired as exc:
        result = CommandResult(
            args=normalized,
            exit_code=124,
            stdout=_text_output(exc.stdout),
            stderr=_text_output(exc.stderr) or f"Timed out after {timeout}s",
            timed_out=True,
        )

    _log_result(logger, result)
    if check:
        result.raise_for_status()
    return result


def run_json_command(args: Sequence[str], *, timeout: float = 5, logger: Any | None = None) -> tuple[CommandResult, Any | None]:
    import json

    result = run_command(args, timeout=timeout, logger=logger)
    if not result.ok:
        return result, None
    try:
        return result, json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        return CommandResult(args=result.args, exit_code=1, stdout=result.stdout, stderr=str(exc)), None
