"""Lumina state directory, JSON state, and simple lock helpers."""

from __future__ import annotations

import json
import os
import shutil
import tempfile
import time
from pathlib import Path
from typing import Any

from .errors import StateError


def state_home() -> Path:
    configured = os.environ.get("LUMINA_STATE_HOME")
    if configured:
        return Path(configured).expanduser()
    return Path.home() / ".local" / "state" / "lumina"


def ensure_state_dir(*parts: str) -> Path:
    path = state_home().joinpath(*parts)
    path.mkdir(parents=True, exist_ok=True)
    return path


def state_path(*parts: str) -> Path:
    return state_home().joinpath(*parts)


STATE_SCHEMA_VERSION = 1


def _backup_path(path: Path) -> Path:
    return path.with_suffix(path.suffix + ".bak")


def _read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def load_json_state(name: str, default: Any = None) -> Any:
    path = state_path(name)
    try:
        return _read_json(path)
    except FileNotFoundError:
        return default
    except (OSError, json.JSONDecodeError) as exc:
        backup = _backup_path(path)
        try:
            recovered = _read_json(backup)
        except (FileNotFoundError, OSError, json.JSONDecodeError):
            raise StateError(f"Could not load state {path}: {exc}") from exc
        corrupt = path.with_suffix(path.suffix + f".corrupt-{int(time.time())}")
        try:
            os.replace(path, corrupt)
        except OSError:
            pass
        return recovered


def save_json_state(name: str, data: Any) -> Path:
    path = state_path(name)
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = json.dumps(data, indent=2, sort_keys=True) + "\n"
    temporary: Path | None = None
    try:
        if path.exists():
            try:
                _read_json(path)
                shutil.copy2(path, _backup_path(path))
            except (OSError, json.JSONDecodeError):
                pass
        descriptor, temporary_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
        temporary = Path(temporary_name)
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            handle.write(payload)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    except OSError as exc:
        raise StateError(f"Could not write state {path}: {exc}") from exc
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)
    return path


def versioned_document(kind: str, data: Any, *, schema_version: int = STATE_SCHEMA_VERSION) -> dict[str, Any]:
    return {
        "schema_version": schema_version,
        "kind": kind,
        "updated_at": time.time(),
        "data": data,
    }


def save_versioned_state(name: str, kind: str, data: Any, *, schema_version: int = STATE_SCHEMA_VERSION) -> Path:
    return save_json_state(name, versioned_document(kind, data, schema_version=schema_version))


def load_versioned_state(
    name: str,
    kind: str,
    default: Any = None,
    *,
    schema_version: int = STATE_SCHEMA_VERSION,
) -> Any:
    document = load_json_state(name, None)
    if document is None:
        return default
    if not isinstance(document, dict):
        raise StateError(f"State {name} is not a versioned document")
    if document.get("kind") != kind:
        raise StateError(f"State {name} has kind {document.get('kind')!r}; expected {kind!r}")
    if document.get("schema_version") != schema_version:
        raise StateError(
            f"State {name} uses schema {document.get('schema_version')!r}; expected {schema_version}"
        )
    return document.get("data", default)


class LockFile:
    def __init__(self, name: str):
        self.path = state_path("locks", f"{name}.lock")
        self._fd: int | None = None

    def acquire(self) -> bool:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        for attempt in range(2):
            try:
                self._fd = os.open(str(self.path), os.O_CREAT | os.O_EXCL | os.O_WRONLY)
                os.write(self._fd, str(os.getpid()).encode("utf-8"))
                os.fsync(self._fd)
                return True
            except FileExistsError:
                if attempt or not self._remove_stale_lock():
                    return False
        return False

    def _remove_stale_lock(self) -> bool:
        try:
            pid = int(self.path.read_text(encoding="utf-8").strip())
            os.kill(pid, 0)
            return False
        except (ValueError, ProcessLookupError):
            self.path.unlink(missing_ok=True)
            return True
        except (FileNotFoundError, PermissionError, OSError):
            return False

    def release(self) -> None:
        if self._fd is not None:
            os.close(self._fd)
            self._fd = None
        try:
            self.path.unlink()
        except FileNotFoundError:
            pass

    def __enter__(self) -> "LockFile":
        if not self.acquire():
            raise StateError(f"Lock already held: {self.path}")
        return self

    def __exit__(self, exc_type: object, exc: object, traceback: object) -> None:
        self.release()
