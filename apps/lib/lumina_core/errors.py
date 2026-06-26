"""Common exception and user-facing error models."""

from __future__ import annotations

from dataclasses import dataclass


class LuminaError(Exception):
    """Base error for recoverable Lumina application failures."""


class DependencyUnavailable(LuminaError):
    """Raised when an optional desktop dependency is missing."""


class ConfigError(LuminaError):
    """Raised when a Lumina configuration file cannot be loaded."""


class StateError(LuminaError):
    """Raised when Lumina state cannot be read or written."""


class CommandError(LuminaError):
    """Raised when a wrapped command fails and check=True was requested."""


@dataclass(frozen=True)
class UserFacingError:
    title: str
    message: str
    detail: str = ""
    recoverable: bool = True

