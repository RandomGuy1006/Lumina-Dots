"""Semantic mood orchestration for the Lumina platform."""

from __future__ import annotations

import asyncio
import atexit
import json
import os
import shutil
import subprocess
import sys
from concurrent.futures import Future, ThreadPoolExecutor
from dataclasses import asdict, dataclass
from enum import Enum
from pathlib import Path

from .glass import GlassMode, set_glass_mode
from .ipc import emit_settings_changed
from .schema import validate_config
from .theme import apply_theme, prefers_reduced_motion
from .toasts import toast


_DETECTOR = ThreadPoolExecutor(max_workers=1, thread_name_prefix="lumina-mood-detect")
atexit.register(_DETECTOR.shutdown, wait=False, cancel_futures=True)


class Mood(str, Enum):
    CYBERPUNK = "cyberpunk"
    NATURE = "nature"
    OCEAN = "ocean"
    DARK = "dark"
    WARM = "warm"
    MINIMAL = "minimal"
    SPACE = "space"
    RETRO = "retro"


@dataclass(frozen=True)
class MoodProfile:
    emoji: str
    display_name: str
    glass_mode: GlassMode
    sound_pack: str | None
    color_temperature: int
    clock_style: str
    motion_speed: float
    wallpaper_hint: str


MOOD_PROFILES = {
    Mood.CYBERPUNK: MoodProfile("🌃", "Cyberpunk", GlassMode.CRYSTAL, "synthwave", 4000, "cyber", 1.2, "neon magenta cyan city"),
    Mood.NATURE: MoodProfile("🌿", "Nature", GlassMode.FROSTED, "forest", 5500, "minimal", .8, "green forest plants"),
    Mood.OCEAN: MoodProfile("🌊", "Ocean", GlassMode.FROSTED, "ocean", 5200, "android", .9, "blue sea water"),
    Mood.DARK: MoodProfile("🌑", "Dark", GlassMode.MICA, None, 3500, "terminal", .7, "dark black shadow"),
    Mood.WARM: MoodProfile("☕", "Warm", GlassMode.MATERIAL, "cafe", 3200, "material", .8, "orange amber sunset"),
    Mood.MINIMAL: MoodProfile("◻️", "Minimal", GlassMode.MINIMAL, None, 6500, "minimal", .5, "white gray clean"),
    Mood.SPACE: MoodProfile("🚀", "Space", GlassMode.CRYSTAL, "space", 4500, "cyber", 1.0, "purple stars galaxy"),
    Mood.RETRO: MoodProfile("📻", "Retro", GlassMode.MATERIAL, "vinyl", 4000, "windows", .9, "sepia vintage muted"),
}


def mood_config_path() -> Path:
    return Path(os.environ.get("LUMINA_CONFIG_HOME", Path.home() / ".config/lumina")) / "mood.json"


def _lumina_command(name: str) -> list[str] | None:
    installed = shutil.which(name)
    if installed:
        return [installed]
    repo_candidate = Path(__file__).resolve().parents[3] / "local-bin" / ".local" / "bin" / name
    if not repo_candidate.exists():
        return None
    if os.name == "nt":
        return [sys.executable, str(repo_candidate)]
    return [str(repo_candidate)]


def current_mood() -> Mood:
    try:
        data = json.loads(mood_config_path().read_text(encoding="utf-8"))
        return Mood(data.get("mood", Mood.NATURE.value))
    except (FileNotFoundError, OSError, ValueError, json.JSONDecodeError):
        return Mood.NATURE


async def _apply_async(mood: Mood, auto_sound: bool, auto_glass: bool, auto_clock: bool) -> None:
    profile = MOOD_PROFILES[mood]
    path = mood_config_path()
    try:
        existing = json.loads(path.read_text(encoding="utf-8"))
        if not isinstance(existing, dict):
            existing = {}
    except (FileNotFoundError, OSError, json.JSONDecodeError):
        existing = {}
    reduced_motion = prefers_reduced_motion()
    motion_speed = 0.1 if reduced_motion else profile.motion_speed
    payload = {
        **existing,
        "mood": mood.value,
        "auto_detect": bool(existing.get("auto_detect", True)),
        "auto_sound": auto_sound,
        "auto_glass": auto_glass,
        "auto_clock": auto_clock,
        "color_temperature": profile.color_temperature,
        "reduced_motion": reduced_motion,
        "profile": {**asdict(profile), "glass_mode": profile.glass_mode.value, "motion_speed": motion_speed},
    }
    validate_config("mood", payload)

    async def glass_job() -> None:
        if auto_glass:
            command = _lumina_command("lumina-glass")
            if command:
                try:
                    await asyncio.to_thread(
                        subprocess.run,
                        [*command, "set", profile.glass_mode.value],
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL,
                        timeout=0.50,
                        check=False,
                    )
                except subprocess.TimeoutExpired:
                    await asyncio.to_thread(set_glass_mode, profile.glass_mode)
            else:
                await asyncio.to_thread(set_glass_mode, profile.glass_mode)

    async def theme_job() -> None:
        command = _lumina_command("lumina-theme")
        if command:
            await asyncio.to_thread(
                subprocess.run,
                [*command, "apply", f"--temperature={profile.color_temperature}"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=1.8,
                check=False,
            )
        else:
            await asyncio.to_thread(apply_theme, None, {"motion": {"speed": motion_speed}}, profile.color_temperature)

    await asyncio.gather(glass_job(), theme_job())
    if auto_clock: emit_settings_changed("lockscreen.clock_style", profile.clock_style)
    if auto_sound: emit_settings_changed("ambient.sound_pack", profile.sound_pack or "")
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    os.replace(tmp, path)
    emit_settings_changed("mood", mood.value)
    toast(f"Mood: {mood.value} {profile.emoji} active")


def apply_mood(mood: Mood | str, auto_sound: bool = True, auto_glass: bool = True, auto_clock: bool = True) -> None:
    selected = Mood(mood)
    try:
        asyncio.get_running_loop()
    except RuntimeError:
        asyncio.run(_apply_async(selected, auto_sound, auto_glass, auto_clock))
        return
    raise RuntimeError("apply_mood() cannot be called from an active event loop; await _apply_async()")


def _detect_mood_from_wallpaper(wallpaper_path: str) -> Mood:
    """Analyze a bounded dominant-color sample in a worker thread."""
    name = Path(wallpaper_path).stem.lower()
    hints = ((Mood.OCEAN, ("ocean", "sea", "blue", "water")), (Mood.NATURE, ("forest", "nature", "green", "plant")), (Mood.SPACE, ("space", "star", "galaxy", "purple")), (Mood.WARM, ("sunset", "warm", "orange", "amber")), (Mood.CYBERPUNK, ("cyber", "neon", "city")), (Mood.RETRO, ("retro", "vintage", "sepia")), (Mood.DARK, ("dark", "black", "night")))
    named = next((mood for mood, words in hints if any(word in name for word in words)), None)
    if named is not None: return named
    try:
        from PIL import Image, ImageStat
        with Image.open(wallpaper_path) as image:
            sample=image.convert("RGB"); sample.thumbnail((64,64)); red,green,blue=ImageStat.Stat(sample).mean
        brightness=(red+green+blue)/3
        if brightness < 55: return Mood.DARK
        if max(red,green,blue)-min(red,green,blue) < 18 and brightness > 190: return Mood.MINIMAL
        if blue > red*1.18 and blue > green*1.08: return Mood.OCEAN
        if green > red*1.08 and green > blue*1.05: return Mood.NATURE
        if red > blue*1.2 and red > green*1.05: return Mood.WARM
        if blue > green and red > green: return Mood.SPACE
    except (ImportError, OSError, ValueError): pass
    return Mood.NATURE


def detect_mood_from_wallpaper_sync(wallpaper_path: str) -> Mood:
    """Return the detected mood for command-line and worker-thread callers."""
    return _detect_mood_from_wallpaper(wallpaper_path)


def detect_mood_from_wallpaper(wallpaper_path: str) -> Future[Mood]:
    """Submit wallpaper analysis to a background worker and return immediately."""
    return _DETECTOR.submit(_detect_mood_from_wallpaper, wallpaper_path)


async def detect_mood_from_wallpaper_async(wallpaper_path: str) -> Mood:
    """Return the detected mood without blocking the caller's event loop."""
    return await asyncio.to_thread(_detect_mood_from_wallpaper, wallpaper_path)
