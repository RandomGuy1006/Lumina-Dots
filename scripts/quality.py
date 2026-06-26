#!/usr/bin/env python3
"""Profile-based Lumina quality gate runner."""

from __future__ import annotations

import argparse
import json
import platform
import subprocess
import sys
import time
from dataclasses import asdict, dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

PROFILES: dict[str, list[tuple[str, list[str]]]] = {
    "static": [
        ("repo", ["bash", "tests/validate-repo.sh"]),
        ("docs", ["bash", "tests/validate-docs.sh"]),
        ("website", [sys.executable, "tests/test-website.py"]),
        ("core", [sys.executable, "tests/validate-lumina-core.py"]),
        ("architecture", [sys.executable, "tests/validate-lumina-architecture.py"]),
        ("ruff", [sys.executable, "-m", "ruff", "check", "apps", "tests", "scripts/quality.py"]),
    ],
    "unit": [
        (f"phase-{phase}", [sys.executable, f"tests/test-lumina-phase{phase}.py"])
        for phase in range(2, 7)
    ] + [("shell-contracts", [sys.executable, "tests/test-shell-contracts.py"])],
    "integration": [
        ("regressions", ["bash", "tests/test-regressions.sh"]),
        ("links", ["bash", "tests/test-links.sh"]),
        ("services", ["bash", "tests/test-services.sh"]),
        ("theme", ["bash", "tests/test-theme.sh"]),
        ("theme-render", ["bash", "tests/test-theme-render.sh"]),
        ("hardware", ["bash", "tests/test-hardware.sh"]),
    ],
    "recovery": [("recovery", ["bash", "tests/test-recovery.sh"])],
    "visual": [("visual-system", [sys.executable, "tests/test-visual-system.py"])],
    "runtime": [("runtime", ["bash", "scripts/validate.sh", "all"])],
}


@dataclass(frozen=True)
class CheckResult:
    check_id: str
    category: str
    status: str
    duration_ms: int
    exit_code: int
    evidence: str
    remediation: str = ""


def checks_for(profile: str) -> list[tuple[str, str, list[str]]]:
    names = [profile]
    if profile == "all":
        names = ["static", "unit", "integration", "recovery", "visual"]
    elif profile == "release":
        names = ["static", "unit", "integration", "recovery", "visual", "runtime"]
    return [(category, check_id, command) for category in names for check_id, command in PROFILES[category]]


def run_check(category: str, check_id: str, command: list[str]) -> CheckResult:
    started = time.monotonic()
    try:
        completed = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, check=False)
        output = (completed.stdout + completed.stderr).strip()
        status = "pass" if completed.returncode == 0 else "fail"
        remediation = "Run the failing command directly and resolve its reported checks." if completed.returncode else ""
        return CheckResult(
            check_id=check_id,
            category=category,
            status=status,
            duration_ms=round((time.monotonic() - started) * 1000),
            exit_code=completed.returncode,
            evidence=output[-12000:],
            remediation=remediation,
        )
    except FileNotFoundError as exc:
        return CheckResult(
            check_id=check_id,
            category=category,
            status="fail",
            duration_ms=round((time.monotonic() - started) * 1000),
            exit_code=127,
            evidence=str(exc),
            remediation=f"Install the missing command: {command[0]}",
        )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("profile", choices=[*PROFILES, "all", "release"], nargs="?", default="all")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--output", type=Path, help="Write a JSON release-evidence file")
    args = parser.parse_args()
    results = [run_check(*check) for check in checks_for(args.profile)]
    evidence = {
        "schema_version": 1,
        "profile": args.profile,
        "generated_at": time.time(),
        "environment": {
            "platform": platform.platform(),
            "python": platform.python_version(),
        },
        "checks": [asdict(item) for item in results],
    }
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        tmp = args.output.with_suffix(args.output.suffix + ".tmp")
        tmp.write_text(json.dumps(evidence, indent=2) + "\n", encoding="utf-8")
        tmp.replace(args.output)
    if args.json:
        print(json.dumps(evidence, indent=2))
    else:
        for result in results:
            marker = "PASS" if result.status == "pass" else "FAIL"
            print(f"{marker} [{result.category}] {result.check_id} ({result.duration_ms}ms)")
            if result.status == "fail" and result.evidence:
                print(result.evidence)
    return 1 if any(result.status == "fail" for result in results) else 0


if __name__ == "__main__":
    raise SystemExit(main())
