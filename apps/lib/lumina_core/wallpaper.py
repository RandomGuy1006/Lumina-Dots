"""Wallpaper cascade helpers owned by Lumina's wallpaper experience."""

from __future__ import annotations

import hashlib
import json
import os
import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Mapping

from .schema import validate_config

IMAGE_EXTENSIONS = {".avif", ".bmp", ".gif", ".jpeg", ".jpg", ".png", ".webp"}
TRANSITION_ORDER = ("fade", "zoom", "wipe", "none")
SWWW_TRANSITIONS = {"fade": "fade", "zoom": "grow", "wipe": "wipe", "none": "none"}


@dataclass(frozen=True)
class WallpaperConfig:
    directory: str
    auto_rotate: bool = False
    rotation_interval: int = 30
    animated: bool = False
    transition: str = "fade"
    transition_duration: float = 1.2


def config_home() -> Path:
    return Path(os.environ.get("LUMINA_CONFIG_HOME", Path.home() / ".config/lumina")).expanduser()


def cache_home() -> Path:
    return Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")).expanduser() / "lumina"


def default_wallpaper_config() -> WallpaperConfig:
    return WallpaperConfig(directory=str(Path.home() / "Pictures/Wallpapers"))


def load_wallpaper_config(path: Path | None = None) -> WallpaperConfig:
    cfg_path = path or config_home() / "wallpaper.json"
    data: dict[str, Any] = default_wallpaper_config().__dict__.copy()
    try:
        loaded = json.loads(cfg_path.read_text(encoding="utf-8"))
    except (FileNotFoundError, OSError, json.JSONDecodeError):
        loaded = {}
    if isinstance(loaded, Mapping):
        data.update(loaded)
    data["transition"] = normalize_transition(str(data.get("transition", "fade")))
    data["transition_duration"] = normalize_duration(data.get("transition_duration", 1.2))
    validate_config("wallpaper", data)
    return WallpaperConfig(**data)


def normalize_transition(value: str) -> str:
    value = value.strip().lower()
    return value if value in TRANSITION_ORDER else "fade"


def normalize_duration(value: Any) -> float:
    try:
        duration = float(value)
    except (TypeError, ValueError):
        return 1.2
    return max(0.0, min(5.0, duration))


def reduced_motion_enabled() -> bool:
    if os.environ.get("LUMINA_REDUCED_MOTION", "").lower() in {"1", "true", "yes", "on"}:
        return True
    gsettings = shutil.which("gsettings")
    if not gsettings:
        return False
    result = subprocess.run(
        [gsettings, "get", "org.gnome.desktop.interface", "enable-animations"],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        timeout=1,
        check=False,
    )
    return result.stdout.strip() == "false"


def effective_transition(
    transition: str | None = None,
    duration: float | str | None = None,
    *,
    config: WallpaperConfig | None = None,
    reduced_motion: bool | None = None,
) -> tuple[str, float]:
    cfg = config or load_wallpaper_config()
    selected = normalize_transition(transition or cfg.transition)
    selected_duration = normalize_duration(cfg.transition_duration if duration is None else duration)
    motion_disabled = reduced_motion if reduced_motion is not None else reduced_motion_enabled()
    if motion_disabled:
        return "none", 0.0
    if selected == "none":
        return "none", 0.0
    return selected, selected_duration


def swww_transition(transition: str) -> str:
    return SWWW_TRANSITIONS[normalize_transition(transition)]


def wallpaper_candidates(directory: str | Path | None = None) -> list[Path]:
    root = Path(directory or load_wallpaper_config().directory).expanduser()
    if not root.is_dir():
        return []
    return sorted(
        (item.resolve() for item in root.iterdir() if item.is_file() and item.suffix.lower() in IMAGE_EXTENSIONS),
        key=lambda path: path.name.lower(),
    )


def thumbnail_path(wallpaper: str | Path, cache_dir: str | Path | None = None) -> Path:
    digest = hashlib.sha256(str(Path(wallpaper).expanduser().resolve()).encode("utf-8")).hexdigest()
    return Path(cache_dir).expanduser() / f"{digest}.jpg" if cache_dir else cache_home() / "thumbnails" / f"{digest}.jpg"


def generate_thumbnail(wallpaper: str | Path, cache_dir: str | Path | None = None) -> Path:
    source = Path(wallpaper).expanduser()
    if not source.is_file():
        raise FileNotFoundError(source)
    target = thumbnail_path(source, cache_dir)
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists() and target.stat().st_mtime >= source.stat().st_mtime:
        return target
    pillow_error: Exception | None = None
    try:
        from PIL import Image, ImageOps

        with Image.open(source) as image:
            thumb = ImageOps.fit(image.convert("RGB"), (200, 112), method=Image.Resampling.LANCZOS)
            thumb.save(target, "JPEG", quality=86, optimize=True)
        return target
    except Exception as exc:
        pillow_error = exc
    tool = shutil.which("magick") or shutil.which("convert")
    if tool:
        command = [tool, str(source), "-thumbnail", "200x112^", "-gravity", "center", "-extent", "200x112", str(target)]
        subprocess.run(command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5, check=False)
        if target.exists():
            return target
    if pillow_error is not None:
        shutil.copyfile(source, target)
    return target


def generate_directory_thumbnails(directory: str | Path | None = None) -> dict[str, str]:
    generated: dict[str, str] = {}
    for wallpaper in wallpaper_candidates(directory):
        try:
            generated[str(wallpaper)] = str(generate_thumbnail(wallpaper))
        except (FileNotFoundError, OSError):
            continue
    return generated


def picker_items(directory: str | Path | None = None) -> list[dict[str, str]]:
    thumbs = generate_directory_thumbnails(directory)
    return [{"path": path, "name": Path(path).name, "thumbnail": thumbs.get(path, "")} for path in sorted(thumbs)]
