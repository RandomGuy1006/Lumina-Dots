"""JSON-schema validation for Lumina-owned configuration writes."""

from __future__ import annotations

import json
import os
import re
from collections.abc import Mapping
from pathlib import Path
from typing import Any

from .errors import ConfigError


def schema_home() -> Path:
    configured = os.environ.get("LUMINA_SCHEMA_HOME")
    if configured:
        return Path(configured).expanduser()
    repo_candidate = Path(__file__).resolve().parents[2] / "settings-studio" / "schemas"
    if repo_candidate.is_dir():
        return repo_candidate
    return Path.home() / ".local/share/lumina/settings-studio/schemas"


def load_schema(name: str) -> dict[str, Any]:
    path = schema_home() / f"{name}.schema.json"
    try:
        loaded = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise ConfigError(f"Missing JSON schema: {path}") from exc
    except (OSError, json.JSONDecodeError) as exc:
        raise ConfigError(f"Invalid JSON schema: {path}: {exc}") from exc
    if not isinstance(loaded, dict):
        raise ConfigError(f"JSON schema root is not an object: {path}")
    return loaded


def validate_config(name: str, data: Mapping[str, Any]) -> None:
    """Reject a configuration document unless it satisfies its canonical schema."""
    schema = load_schema(name)
    try:
        import jsonschema
    except ImportError as exc:
        _validate_subset(name, dict(data), schema)
        return
    try:
        jsonschema.validate(dict(data), schema)
    except jsonschema.ValidationError as exc:
        location = ".".join(str(part) for part in exc.absolute_path) or "<root>"
        raise ConfigError(f"Invalid {name}.json at {location}: {exc.message}") from exc


def _validate_subset(name: str, data: Mapping[str, Any], schema: Mapping[str, Any], path: str = "<root>") -> None:
    """Validate the JSON-schema subset used by Lumina config contracts."""
    if schema.get("type") == "object" and not isinstance(data, Mapping):
        raise ConfigError(f"Invalid {name}.json at {path}: expected object")
    for key in schema.get("required", []):
        if key not in data:
            raise ConfigError(f"Invalid {name}.json at {path}: missing required property {key}")
    properties = schema.get("properties", {})
    if isinstance(properties, Mapping):
        for key, value in data.items():
            child_schema = properties.get(key)
            child_path = key if path == "<root>" else f"{path}.{key}"
            if child_schema is None:
                if schema.get("additionalProperties") is False:
                    raise ConfigError(f"Invalid {name}.json at {child_path}: additional property is not allowed")
                continue
            _validate_value(name, value, child_schema, child_path)


def _validate_value(name: str, value: Any, schema: Mapping[str, Any], path: str) -> None:
    if "enum" in schema and value not in schema["enum"]:
        raise ConfigError(f"Invalid {name}.json at {path}: {value!r} is not an allowed value")
    expected = schema.get("type")
    if expected is not None and not _matches_type(value, expected):
        raise ConfigError(f"Invalid {name}.json at {path}: expected {expected}")
    if isinstance(value, Mapping) and schema.get("type") == "object":
        _validate_subset(name, value, schema, path)
    if isinstance(value, (int, float)):
        if "minimum" in schema and value < schema["minimum"]:
            raise ConfigError(f"Invalid {name}.json at {path}: value is below minimum")
        if "maximum" in schema and value > schema["maximum"]:
            raise ConfigError(f"Invalid {name}.json at {path}: value is above maximum")
    if isinstance(value, str):
        if "minLength" in schema and len(value) < schema["minLength"]:
            raise ConfigError(f"Invalid {name}.json at {path}: value is too short")
        if "pattern" in schema and re.fullmatch(str(schema["pattern"]), value) is None:
            raise ConfigError(f"Invalid {name}.json at {path}: value does not match pattern")


def _matches_type(value: Any, expected: Any) -> bool:
    if isinstance(expected, list):
        return any(_matches_type(value, item) for item in expected)
    if expected == "object":
        return isinstance(value, Mapping)
    if expected == "array":
        return isinstance(value, list)
    if expected == "string":
        return isinstance(value, str)
    if expected == "integer":
        return isinstance(value, int) and not isinstance(value, bool)
    if expected == "number":
        return isinstance(value, (int, float)) and not isinstance(value, bool)
    if expected == "boolean":
        return isinstance(value, bool)
    if expected == "null":
        return value is None
    return True
