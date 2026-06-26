#!/usr/bin/env python3
"""Static visual-system contract checks."""

from __future__ import annotations

import ast
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ALLOWED_SPACING = {0, 4, 8, 12, 16, 24}


def test_token_schema() -> None:
    path = ROOT / "matugen/.config/matugen/templates/visual-tokens.json"
    tokens = json.loads(path.read_text(encoding="utf-8"))
    required = {"colors", "spacing", "typography", "icons", "stroke", "opacity", "radius", "shadow", "motion"}
    assert required <= tokens.keys()
    assert "blur" not in tokens
    assert set(tokens["spacing"].values()) <= {4, 8, 12, 16, 24}
    assert list(tokens["icons"].values()) == [16, 20, 24]
    assert tokens["typography"]["body_px"] >= 14


def test_app_spacing_grid() -> None:
    pattern = re.compile(r"set_(?:margin_(?:top|bottom|start|end)|spacing)\((\d+)\)")
    violations: list[str] = []
    for path in (ROOT / "apps").rglob("*.py"):
        text = path.read_text(encoding="utf-8")
        ast.parse(text, filename=str(path))
        for match in pattern.finditer(text):
            value = int(match.group(1))
            if value not in ALLOWED_SPACING:
                violations.append(f"{path.relative_to(ROOT)}:{value}")
    assert not violations, "Off-grid spacing: " + ", ".join(violations)


def test_shell_css_contract() -> None:
    css = (ROOT / "apps/shell/shell.css").read_text(encoding="utf-8")
    for required in [
        "--lumina-typography-body-px",
        ".lumina-popup",
        ".lumina-icon",
        ":focus-visible",
        "--lumina-motion-micro-ms",
    ]:
        assert required in css


def test_renderer_covers_surfaces() -> None:
    renderer = (ROOT / "scripts/theme/render-visual-tokens.sh").read_text(encoding="utf-8")
    for surface in ["hypr/tokens.conf", "walker/themes/generated.css", "wlogout/colors.css", "hyprpanel/theme.generated.json"]:
        assert surface in renderer


def test_screenshot_baselines() -> None:
    directory = ROOT / "assets/screenshots"
    manifest = json.loads((directory / "baseline.json").read_text(encoding="utf-8"))
    assert manifest["schema_version"] == 1
    for name, expected in manifest["images"].items():
        actual = hashlib.sha256((directory / name).read_bytes()).hexdigest()
        assert actual == expected, f"Baseline metadata is stale for {name}"
    assert (ROOT / "tests/compare-visuals.py").exists()


def main() -> int:
    test_token_schema()
    test_app_spacing_grid()
    test_shell_css_contract()
    test_renderer_covers_surfaces()
    test_screenshot_baselines()
    print("Visual system contract tests passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
