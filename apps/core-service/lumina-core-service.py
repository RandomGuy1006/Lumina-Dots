#!/usr/bin/env python3
"""Installed entry point for the Lumina session service."""
from __future__ import annotations
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "lib"))
from lumina_core.dbus_service import main
raise SystemExit(main())
