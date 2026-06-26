#!/usr/bin/env python3
"""Lumina Theme Studio."""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import asdict, dataclass
from pathlib import Path

APP_ROOT = Path(__file__).resolve().parents[1]
CORE_PATH = APP_ROOT / "lib"
SHELL_PATH = APP_ROOT / "shell"
for path in (CORE_PATH, SHELL_PATH):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))

from lumina_core.app import LuminaApplication
from lumina_core.errors import DependencyUnavailable
from lumina_core.subprocesses import run_command
from lumina_core.theme import load_tokens
from lumina_core.widgets import command_button, section_heading
from components.popups import dispatch_event

IMAGE_EXTENSIONS = {".avif", ".jpeg", ".jpg", ".png", ".webp"}


@dataclass(frozen=True)
class WallpaperCandidate:
    path: str
    name: str
    selected: bool = False


def wallpaper_root(path: str | None = None) -> Path:
    return Path(path).expanduser() if path else Path.home() / "Pictures" / "Wallpapers"


def current_wallpaper(root: Path | None = None) -> str:
    marker = (root or wallpaper_root()) / ".current"
    try:
        return marker.read_text(encoding="utf-8").strip()
    except OSError:
        return ""


def wallpaper_candidates(path: str | None = None) -> list[WallpaperCandidate]:
    root = wallpaper_root(path)
    selected = current_wallpaper(root)
    if not root.exists():
        return []
    candidates: list[WallpaperCandidate] = []
    for item in sorted(root.iterdir()):
        if item.is_file() and item.suffix.lower() in IMAGE_EXTENSIONS:
            resolved = str(item.resolve())
            candidates.append(WallpaperCandidate(path=resolved, name=item.name, selected=resolved == selected))
    return candidates


def palette_preview(wallpaper: str | None = None) -> dict[str, object]:
    tokens = load_tokens()
    colors = tokens["colors"]
    return {
        "wallpaper": str(Path(wallpaper).expanduser()) if wallpaper else current_wallpaper(),
        "colors": {
            key: colors[key]
            for key in ("accent", "accent_alt", "surface", "surface_alt", "fg", "muted", "warning", "danger")
        },
    }


def apply_theme(wallpaper: str) -> bool:
    target = Path(wallpaper).expanduser()
    if not target.is_file():
        dispatch_event("theme", body=f"Wallpaper missing: {target}", urgency="critical")
        return False
    result = run_command(["dotfiles", "theme", str(target)], timeout=180)
    dispatch_event("theme", body=target.name if result.ok else result.stderr.strip(), urgency="normal" if result.ok else "critical")
    return result.ok


class ThemeStudioApp(LuminaApplication):
    def __init__(self):
        super().__init__("lumina-theme-studio", "Theme Studio")

    def build(self, window):
        Gtk = self.Gtk
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        box.set_margin_top(16)
        box.set_margin_bottom(16)
        box.set_margin_start(16)
        box.set_margin_end(16)
        box.append(section_heading("Theme Studio"))
        preview = palette_preview()
        box.append(Gtk.Label(label=f"Current wallpaper: {preview.get('wallpaper') or 'none'}", xalign=0))
        colors = preview.get("colors", {})
        if isinstance(colors, dict):
            box.append(Gtk.Label(label="Palette: " + ", ".join(f"{key} {value}" for key, value in colors.items()), xalign=0))
        scroll = Gtk.ScrolledWindow()
        rows = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        candidates = wallpaper_candidates()
        if not candidates:
            rows.append(Gtk.Label(label="No wallpapers found in ~/Pictures/Wallpapers.", xalign=0))
        for candidate in candidates:
            rows.append(command_button(("Apply " if not candidate.selected else "Reapply ") + candidate.name, lambda _button, path=candidate.path: apply_theme(path)))
        scroll.set_child(rows)
        box.append(scroll)
        window.set_content(box)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="lumina-theme-studio")
    sub = parser.add_subparsers(dest="command")
    list_cmd = sub.add_parser("list")
    list_cmd.add_argument("--dir")
    preview = sub.add_parser("preview")
    preview.add_argument("wallpaper", nargs="?")
    apply = sub.add_parser("apply")
    apply.add_argument("wallpaper")
    args = parser.parse_args(argv)
    if args.command == "list":
        print(json.dumps([asdict(item) for item in wallpaper_candidates(args.dir)], indent=2))
        return 0
    if args.command == "preview":
        print(json.dumps(palette_preview(args.wallpaper), indent=2, sort_keys=True))
        return 0
    if args.command == "apply":
        return 0 if apply_theme(args.wallpaper) else 1
    try:
        return ThemeStudioApp().run(sys.argv)
    except DependencyUnavailable:
        print(json.dumps(palette_preview(), indent=2, sort_keys=True))
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
