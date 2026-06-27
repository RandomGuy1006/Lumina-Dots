"""Configuration helpers for Lumina JSON files."""

from __future__ import annotations

import json
import os
from collections.abc import Mapping
from pathlib import Path
from typing import Any

from .errors import ConfigError


def config_home() -> Path:
    configured = os.environ.get("LUMINA_CONFIG_HOME")
    if configured:
        return Path(configured).expanduser()
    return Path.home() / ".config" / "lumina"


def config_path(name: str, base: str | os.PathLike[str] | None = None) -> Path:
    filename = name if name.endswith(".json") else f"{name}.json"
    root = Path(base).expanduser() if base is not None else config_home()
    return root / filename


def load_json(path: str | os.PathLike[str]) -> dict[str, Any]:
    json_path = Path(path).expanduser()
    try:
        loaded = json.loads(json_path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        raise
    except json.JSONDecodeError as exc:
        raise ConfigError(f"Invalid JSON: {json_path}: {exc}") from exc
    except OSError as exc:
        raise ConfigError(f"Could not read config: {json_path}: {exc}") from exc
    if not isinstance(loaded, dict):
        raise ConfigError(f"Invalid JSON: {json_path}: root must be an object")
    return loaded


def load_config(
    name: str,
    defaults: Mapping[str, Any] | None = None,
    base: str | os.PathLike[str] | None = None,
) -> dict[str, Any]:
    defaults_dict = dict(defaults or {})
    path = config_path(name, base)
    try:
        loaded = load_json(path)
    except FileNotFoundError:
        return defaults_dict
    return deep_merge(defaults_dict, loaded)


def deep_merge(base: Mapping[str, Any], override: Mapping[str, Any]) -> dict[str, Any]:
    merged: dict[str, Any] = dict(base)
    for key, value in override.items():
        if isinstance(value, Mapping) and isinstance(merged.get(key), Mapping):
            merged[key] = deep_merge(merged[key], value)  # type: ignore[arg-type]
        else:
            merged[key] = value
    return merged


def ensure_config(name: str, defaults: Mapping[str, Any], base: str | os.PathLike[str] | None = None) -> Path:
    path = config_path(name, base)
    if not path.exists():
        path.parent.mkdir(parents=True, exist_ok=True)
        tmp = path.with_suffix(path.suffix + ".tmp")
        tmp.write_text(json.dumps(defaults, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        os.replace(tmp, path)
    return path
