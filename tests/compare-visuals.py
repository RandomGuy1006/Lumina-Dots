#!/usr/bin/env python3
"""Compare candidate desktop screenshots with Lumina visual baselines."""

from __future__ import annotations

import argparse
import math
from pathlib import Path


def normalized_rms(reference: Path, candidate: Path) -> float:
    try:
        from PIL import Image, ImageChops
    except ImportError as exc:
        raise SystemExit("Pillow is required for visual comparison: python -m pip install Pillow") from exc
    with Image.open(reference).convert("RGB") as expected, Image.open(candidate).convert("RGB") as actual:
        if actual.size != expected.size:
            return 1.0
        histogram = ImageChops.difference(expected, actual).histogram()
        squared = sum((index % 256) ** 2 * count for index, count in enumerate(histogram))
        return math.sqrt(squared / (expected.width * expected.height * 3)) / 255


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("candidate", type=Path)
    parser.add_argument("--baseline", type=Path, default=Path("assets/screenshots"))
    parser.add_argument("--threshold", type=float, default=0.025)
    args = parser.parse_args()
    failures = 0
    for reference in sorted(args.baseline.glob("*.png")):
        candidate = args.candidate / reference.name
        if not candidate.exists():
            print(f"FAIL missing candidate: {candidate}")
            failures += 1
            continue
        difference = normalized_rms(reference, candidate)
        status = "PASS" if difference <= args.threshold else "FAIL"
        print(f"{status} {reference.name}: normalized RMS {difference:.4f}")
        failures += difference > args.threshold
    return int(failures > 0)


if __name__ == "__main__":
    raise SystemExit(main())
