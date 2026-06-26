#!/usr/bin/env python3
"""Structural and repository-sync checks for the static website."""

from __future__ import annotations

import json
import re
import subprocess
import sys
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlsplit


ROOT = Path(__file__).resolve().parents[1]
INDEX = ROOT / "website" / "index.html"


class SiteParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.ids: list[str] = []
        self.refs: list[str] = []
        self.inline_handlers: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        values = dict(attrs)
        if values.get("id"):
            self.ids.append(values["id"] or "")
        for name in ("href", "src"):
            if values.get(name):
                self.refs.append(values[name] or "")
        self.inline_handlers.extend(name for name, _ in attrs if name.lower().startswith("on"))


def fail(message: str) -> None:
    raise AssertionError(message)


def main() -> int:
    check = subprocess.run(
        [sys.executable, "website/build-site.py", "--check"], cwd=ROOT, text=True, capture_output=True, check=False
    )
    if check.returncode:
        fail(check.stdout.strip() or check.stderr.strip())

    source = INDEX.read_text(encoding="utf-8")
    parser = SiteParser()
    parser.feed(source)
    duplicates = sorted({item for item in parser.ids if parser.ids.count(item) > 1})
    if duplicates:
        fail(f"Duplicate HTML ids: {duplicates}")
    if parser.inline_handlers:
        fail(f"Inline event handlers are not allowed: {parser.inline_handlers}")

    ids = set(parser.ids)
    for ref in parser.refs:
        if ref.startswith("#") and ref != "#" and ref[1:] not in ids:
            fail(f"Missing anchor target: {ref}")
        parts = urlsplit(ref)
        if parts.scheme or parts.netloc or ref.startswith(("#", "data:", "mailto:")):
            continue
        local = (INDEX.parent / parts.path).resolve()
        if parts.path and not local.is_file():
            fail(f"Missing local website asset: {ref}")

    match = re.search(r'<script type="application/json" id="lumina-embed-data">\s*(.*?)\s*</script>', source, re.DOTALL)
    if not match:
        fail("Missing embedded repository data")
    data = json.loads(match.group(1))
    version = (ROOT / ".version").read_text(encoding="utf-8").strip()
    if data["site"]["version"] != version:
        fail("Website version does not match .version")

    manifest = {item["path"] for item in data["site"]["manifest"]}
    required_manifest = {
        "apps/lib/lumina_core/contracts.py",
        "schemas/lumina-shell-envelope.schema.json",
        "website/index.html",
        "website/assets/desktop.png",
    }
    missing_manifest = sorted(required_manifest - manifest)
    if missing_manifest:
        fail(f"Embedded manifest is incomplete: {missing_manifest}")

    docs = {item["path"] for item in data["docs"]}
    required_docs = {"docs/architecture.md", "docs/quickshell-readiness.md", "docs/verification.md", "README.md"}
    missing_docs = sorted(required_docs - docs)
    if missing_docs:
        fail(f"Embedded documentation is incomplete: {missing_docs}")

    stale_claims = (
        "zero-config NVIDIA",
        "Strict Snapper snapshot gates on Btrfs",
        "ASUS ROG Zephyrus G14",
        "Framework 16",
        "ThinkPad X1 Carbon",
        "Spring physics, Material You, zero maintenance",
        "→ palette.json",
    )
    found = [claim for claim in stale_claims if claim.lower() in source.lower()]
    if found:
        fail(f"Stale website claims remain: {found}")

    print("Website validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
