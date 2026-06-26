"""Configuration helpers for Lumina TOML files."""

from __future__ import annotations

import os
import tomllib
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
    filename = name if name.endswith(".toml") else f"{name}.toml"
    root = Path(base).expanduser() if base is not None else config_home()
    return root / filename


def load_toml(path: str | os.PathLike[str]) -> dict[str, Any]:
    toml_path = Path(path).expanduser()
    try:
        with toml_path.open("rb") as handle:
            loaded = tomllib.load(handle)
    except FileNotFoundError:
        raise
    except tomllib.TOMLDecodeError as exc:
        raise ConfigError(f"Invalid TOML: {toml_path}: {exc}") from exc
    except OSError as exc:
        raise ConfigError(f"Could not read config: {toml_path}: {exc}") from exc
    return loaded


def load_config(
    name: str,
    defaults: Mapping[str, Any] | None = None,
    base: str | os.PathLike[str] | None = None,
) -> dict[str, Any]:
    defaults_dict = dict(defaults or {})
    path = config_path(name, base)
    try:
        loaded = load_toml(path)
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


def _format_value(value: Any) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int | float):
        return str(value)
    return '"' + str(value).replace("\\", "\\\\").replace('"', '\\"') + '"'


def toml_from_mapping(data: Mapping[str, Any]) -> str:
    lines: list[str] = []
    for key, value in data.items():
        if isinstance(value, Mapping):
            if lines:
                lines.append("")
            lines.append(f"[{key}]")
            for child_key, child_value in value.items():
                lines.append(f"{child_key} = {_format_value(child_value)}")
        else:
            lines.append(f"{key} = {_format_value(value)}")
    return "\n".join(lines) + "\n"


def ensure_config(name: str, defaults: Mapping[str, Any], base: str | os.PathLike[str] | None = None) -> Path:
    path = config_path(name, base)
    if not path.exists():
        path.parent.mkdir(parents=True, exist_ok=True)
        tmp = path.with_suffix(path.suffix + ".tmp")
        tmp.write_text(toml_from_mapping(defaults), encoding="utf-8")
        os.replace(tmp, path)
    return path
