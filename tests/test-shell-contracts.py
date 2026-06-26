#!/usr/bin/env python3
"""External-consumer checks for Lumina Shell public contracts."""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]


def validate_envelope(payload: Any) -> dict[str, Any]:
    assert isinstance(payload, dict)
    assert set(payload) == {"schema_version", "kind", "timestamp", "data"}
    assert payload["schema_version"] == 1
    assert isinstance(payload["kind"], str) and payload["kind"].startswith("shell.")
    assert isinstance(payload["timestamp"], (int, float)) and payload["timestamp"] >= 0
    return payload


def run_public_command(*args: str) -> dict[str, Any]:
    completed = subprocess.run(
        [sys.executable, "apps/shell/lumina-shell.py", *args],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )
    assert completed.returncode == 0, completed.stderr
    return validate_envelope(json.loads(completed.stdout))


def test_schema_and_fixture() -> None:
    schema = json.loads((ROOT / "schemas/lumina-shell-envelope.schema.json").read_text(encoding="utf-8"))
    assert schema["properties"]["schema_version"]["const"] == 1
    fixture = json.loads((ROOT / "schemas/fixtures/shell-capabilities-v1.json").read_text(encoding="utf-8"))
    validate_envelope(fixture)


def test_external_consumer() -> None:
    capabilities = run_public_command("capabilities")
    assert "snapshot" in capabilities["data"]["queries"]
    assert capabilities["data"]["production_frontends"] == ["gtk", "hyprpanel"]
    tokens = run_public_command("tokens")
    assert "typography" in tokens["data"] and "motion" in tokens["data"]


def test_contract_layer_has_no_gtk_dependency() -> None:
    text = (ROOT / "apps/lib/lumina_core/contracts.py").read_text(encoding="utf-8")
    assert "Gtk" not in text and "gi.repository" not in text


def main() -> int:
    test_schema_and_fixture()
    test_external_consumer()
    test_contract_layer_has_no_gtk_dependency()
    print("Lumina Shell contract tests passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
