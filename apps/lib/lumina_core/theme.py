"""Lumina visual token loading and CSS helpers."""

from __future__ import annotations

import copy
import contextlib
import json
import logging
import os
import shutil
import subprocess
import tempfile
from collections.abc import Mapping
from pathlib import Path
from typing import Any

from .ipc import emit_settings_changed
from .schema import validate_config

LOGGER = logging.getLogger(__name__)

FALLBACK_TOKENS: dict[str, dict[str, Any]] = {
    "colors": {
        "fg": "#f0f4fc",
        "muted": "#8a93b8",
        "surface": "#08090f",
        "surface_alt": "#0f1220",
        "surface_high": "#171b2b",
        "accent": "#00f5ff",
        "accent_alt": "#bf00ff",
        "warning": "#ffb86b",
        "danger": "#ff003c",
        "outline": "#4a5278",
        "on_accent": "#040508",
        "primary_container": "#082f35",
        "on_primary_container": "#d7fbff",
        "secondary_container": "#2b1238",
        "primary": "#00f5ff",
        "primary_variant": "#00b8c0",
        "secondary": "#bf00ff",
        "surface_variant": "#0f1220",
        "on_surface": "#f0f4fc",
        "outline_variant": "#2b3048",
        "error": "#ff003c",
    },
    "spacing": {
        "xs": 4,
        "sm": 8,
        "md": 16,
        "lg": 24,
        "xl": 40,
        "gap_inner": 4,
        "gap_outer": 12,
        "chip": 8,
        "item": 12,
        "panel": 16,
        "shell": 24,
    },
    "typography": {
        "sans": "Inter, system-ui, sans-serif",
        "mono": "JetBrains Mono, monospace",
        "size_sm": 13,
        "size_md": 15,
        "size_lg": 17,
        "size_xl": 22,
        "ui_family": "Inter",
        "mono_family": "JetBrains Mono",
        "caption_px": 12,
        "body_px": 14,
        "title_px": 18,
        "display_px": 24,
        "line_height": 1.4,
    },
    "icons": {"small": 16, "regular": 20, "large": 24},
    "stroke": {"hairline": 1, "focus": 2},
    "opacity": {
        "surface": 0.88,
        "surface_strong": 0.96,
        "muted": 0.72,
        "disabled": 0.42,
    },
    "radius": {
        "xs": 4,
        "sm": 8,
        "md": 12,
        "lg": 18,
        "xl": 24,
        "chip": 8,
        "item": 12,
        "shell": 16,
    },
    "spatial": {
        "radius_xs": 4,
        "radius_sm": 8,
        "radius_md": 12,
        "radius_lg": 18,
        "radius_xl": 24,
        "spacing_xs": 4,
        "spacing_sm": 8,
        "spacing_md": 16,
        "spacing_lg": 24,
        "spacing_xl": 40,
    },
    "shadow": {
        "range": 20,
        "render_power": 3,
    },
    "motion": {
        "speed": 1.0,
        "easing_standard": "cubic-bezier(0.4, 0, 0.2, 1)",
        "easing_enter": "cubic-bezier(0, 0, 0.2, 1)",
        "easing_exit": "cubic-bezier(0.4, 0, 1, 1)",
        "easing_spring": "cubic-bezier(0.22, 1, 0.36, 1)",
        "duration_short": "150ms",
        "duration_medium": "280ms",
        "duration_long": "450ms",
        "curve_css": "0.22, 1.0, 0.36, 1.0",
        "micro_ms": 120,
        "panel_ms": 240,
        "exit_ms": 180,
        "wallpaper_ms": 900,
    },
}


def default_token_path() -> Path:
    configured = os.environ.get("LUMINA_TOKEN_PATH")
    if configured:
        return Path(configured).expanduser()
    return Path.home() / ".cache" / "lumina" / "visual-tokens.json"


def prefers_reduced_motion() -> bool:
    override = os.environ.get("LUMINA_REDUCED_MOTION")
    if override is not None:
        return override.lower() in {"1", "true", "yes"}
    if not shutil.which("gsettings"):
        return False
    completed = subprocess.run(
        ["gsettings", "get", "org.gnome.desktop.interface", "enable-animations"],
        capture_output=True, text=True, timeout=0.2, check=False,
    )
    return completed.returncode == 0 and completed.stdout.strip().lower() == "false"


def _warn(logger: Any | None, message: str) -> None:
    if logger is not None:
        warning = getattr(logger, "warning", None)
        if callable(warning):
            warning(message)
            return
    print(f"lumina_core.theme: {message}", flush=True)


def fallback_tokens() -> dict[str, dict[str, Any]]:
    return copy.deepcopy(FALLBACK_TOKENS)


def validate_tokens(tokens: Mapping[str, Any]) -> list[str]:
    """Return a list of missing or invalid required token paths."""

    problems: list[str] = []
    for group, fallback_values in FALLBACK_TOKENS.items():
        group_value = tokens.get(group)
        if not isinstance(group_value, Mapping):
            problems.append(group)
            continue
        for key, fallback_value in fallback_values.items():
            value = group_value.get(key)
            if isinstance(fallback_value, str):
                if not isinstance(value, str) or not value:
                    problems.append(f"{group}.{key}")
            elif isinstance(fallback_value, (int, float)):
                if not isinstance(value, (int, float)):
                    problems.append(f"{group}.{key}")
    return problems


def merge_with_fallback(tokens: Mapping[str, Any]) -> dict[str, dict[str, Any]]:
    merged = fallback_tokens()
    for group, fallback_values in FALLBACK_TOKENS.items():
        incoming = tokens.get(group)
        if not isinstance(incoming, Mapping):
            continue
        for key in fallback_values:
            if key in incoming:
                merged[group][key] = incoming[key]
    incoming_colors = tokens.get("colors")
    if isinstance(incoming_colors, Mapping):
        aliases = {
            "primary": "accent",
            "primary_variant": "accent",
            "secondary": "accent_alt",
            "surface_variant": "surface_alt",
            "on_surface": "fg",
            "outline_variant": "outline",
            "error": "danger",
        }
        for canonical, legacy in aliases.items():
            if canonical in incoming_colors:
                merged["colors"][canonical] = incoming_colors[canonical]
            elif legacy in incoming_colors:
                merged["colors"][canonical] = incoming_colors[legacy]
    return merged


def load_tokens(path: str | os.PathLike[str] | None = None, logger: Any | None = None) -> dict[str, dict[str, Any]]:
    token_path = Path(path).expanduser() if path is not None else default_token_path()
    try:
        raw = token_path.read_text(encoding="utf-8")
        loaded = json.loads(raw)
        if not isinstance(loaded, Mapping):
            raise ValueError("token root is not an object")
        problems = validate_tokens(loaded)
        if problems:
            _warn(logger, f"Invalid visual token file {token_path}: missing {', '.join(problems)}")
            return fallback_tokens()
        return merge_with_fallback(loaded)
    except FileNotFoundError:
        _warn(logger, f"Visual token file missing, using fallback tokens: {token_path}")
    except (OSError, json.JSONDecodeError, ValueError) as exc:
        _warn(logger, f"Could not load visual tokens from {token_path}: {exc}")
    return fallback_tokens()


def _css_name(group: str, key: str, prefix: str) -> str:
    normalized = f"{group}-{key}".replace("_", "-")
    return f"--{prefix}-{normalized}"


def tokens_to_css(tokens: Mapping[str, Mapping[str, Any]] | None = None, prefix: str = "lumina") -> str:
    data = merge_with_fallback(tokens or FALLBACK_TOKENS)
    lines = [":root {"]
    for group, values in data.items():
        for key, value in values.items():
            css_value = value
            if group in {"spacing", "radius", "spatial", "icons", "stroke"} or (group == "typography" and (key.endswith("_px") or key.startswith("size_"))):
                css_value = f"{value}px"
            lines.append(f"  {_css_name(group, key, prefix)}: {css_value};")
    lines.append("}")
    return "\n".join(lines) + "\n"


def write_css(path: str | os.PathLike[str], tokens: Mapping[str, Mapping[str, Any]] | None = None) -> Path:
    css_path = Path(path).expanduser()
    css_path.parent.mkdir(parents=True, exist_ok=True)
    tmp = css_path.with_suffix(css_path.suffix + ".tmp")
    tmp.write_text(tokens_to_css(tokens), encoding="utf-8")
    os.replace(tmp, css_path)
    return css_path


def _atomic_json(path: Path, data: Mapping[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    os.replace(tmp, path)


def _repo_root() -> Path | None:
    for parent in Path(__file__).resolve().parents:
        if (parent / "scripts/theme/sync-surfaces.sh").is_file():
            return parent
    return None


@contextlib.contextmanager
def theme_apply_lock():
    runtime_dir = Path(os.environ.get("XDG_RUNTIME_DIR", tempfile.gettempdir()))
    runtime_dir.mkdir(parents=True, exist_ok=True)
    lock_path = runtime_dir / "lumina-theme.lock"
    try:
        fd = os.open(lock_path, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    except FileExistsError as exc:
        raise RuntimeError(f"Theme switch already in progress: {lock_path}") from exc
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(f"pid={os.getpid()}\n")
        yield lock_path
    finally:
        try:
            lock_path.unlink()
        except FileNotFoundError:
            pass


def sync_surfaces() -> None:
    root = _repo_root()
    if root is None:
        raise RuntimeError("Could not locate scripts/theme/sync-surfaces.sh")
    completed = subprocess.run(
        ["bash", str(root / "scripts/theme/sync-surfaces.sh")],
        check=False,
    )
    if completed.returncode != 0:
        raise RuntimeError(f"sync-surfaces.sh failed with exit {completed.returncode}")


def _rgb(value: str) -> tuple[int, int, int]:
    normalized = value.removeprefix("#")
    if len(normalized) != 6:
        raise ValueError(f"Unsupported color value: {value}")
    return tuple(int(normalized[index:index + 2], 16) for index in (0, 2, 4))  # type: ignore[return-value]


def _luminance(value: str) -> float:
    channels = []
    for channel in _rgb(value):
        component = channel / 255.0
        channels.append(component / 12.92 if component <= 0.04045 else ((component + 0.055) / 1.055) ** 2.4)
    return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]


def contrast_ratio(foreground: str, background: str) -> float:
    high, low = sorted((_luminance(foreground), _luminance(background)), reverse=True)
    return (high + 0.05) / (low + 0.05)


def _accessible_foreground(background: str) -> str:
    dark = "#" + "00" * 3
    light = "#" + "ff" * 3
    return light if contrast_ratio(light, background) >= contrast_ratio(dark, background) else dark


def enforce_contrast(tokens: Mapping[str, Any]) -> dict[str, Any]:
    """Return tokens whose canonical text/UI pairs meet WCAG AA thresholds."""
    corrected = copy.deepcopy(dict(tokens))
    colors = corrected.setdefault("colors", {})
    pairs = (
        ("on_surface", "surface", 4.5),
        ("on_accent", "primary", 4.5),
        ("error", "surface", 4.5),
        ("outline", "surface", 3.0),
    )
    for foreground_key, background_key, target in pairs:
        foreground = colors.get(foreground_key)
        background = colors.get(background_key)
        try:
            if not isinstance(foreground, str) or not isinstance(background, str) or contrast_ratio(foreground, background) < target:
                if not isinstance(background, str):
                    raise ValueError(background_key)
                colors[foreground_key] = _accessible_foreground(background)
        except ValueError:
            fallback = FALLBACK_TOKENS["colors"]
            colors[background_key] = fallback[background_key]
            colors[foreground_key] = fallback[foreground_key]
    colors["fg"] = colors["on_surface"]
    colors["danger"] = colors["error"]
    return corrected


def contrast_problems(tokens: Mapping[str, Any]) -> list[str]:
    colors = tokens.get("colors", {})
    if not isinstance(colors, Mapping):
        return ["colors"]
    problems: list[str] = []
    for foreground, background, target in (("on_surface", "surface", 4.5), ("on_accent", "primary", 4.5), ("error", "surface", 4.5), ("outline", "surface", 3.0)):
        try:
            if contrast_ratio(str(colors[foreground]), str(colors[background])) < target:
                problems.append(f"{foreground}/{background}")
        except (KeyError, ValueError):
            problems.append(f"{foreground}/{background}")
    return problems


def _template_path() -> Path | None:
    candidates = (
        Path(__file__).resolve().parents[3] / "matugen/.config/matugen/templates/visual-tokens.json",
        Path.home() / ".config/matugen/templates/visual-tokens.json",
    )
    return next((candidate for candidate in candidates if candidate.is_file()), None)


def _preview_matugen(wallpaper_path: str) -> Mapping[str, Any]:
    template = _template_path()
    if not shutil.which("matugen") or template is None or not Path(wallpaper_path).expanduser().is_file():
        return FALLBACK_TOKENS
    with tempfile.TemporaryDirectory(prefix="lumina-theme-preview-") as raw_home:
        home = Path(raw_home)
        template_dir = home / ".config/matugen/templates"
        output = home / ".cache/lumina/visual-tokens.json"
        template_dir.mkdir(parents=True)
        output.parent.mkdir(parents=True)
        shutil.copy2(template, template_dir / "visual-tokens.json")
        config = home / ".config/matugen/config.toml"
        config.write_text(
            '[config]\nreload_gtk_theme = false\n\n[templates.visual-tokens]\n'
            'input_path = "~/.config/matugen/templates/visual-tokens.json"\n'
            'output_path = "~/.cache/lumina/visual-tokens.json"\n',
            encoding="utf-8",
        )
        env = {**os.environ, "HOME": str(home), "XDG_CONFIG_HOME": str(home / ".config"), "XDG_CACHE_HOME": str(home / ".cache")}
        completed = subprocess.run(
            ["matugen", "image", str(Path(wallpaper_path).expanduser()), "--type", "scheme-tonal-spot"],
            env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=1.8, check=False,
        )
        if completed.returncode != 0 or not output.is_file():
            return FALLBACK_TOKENS
        try:
            loaded = json.loads(output.read_text(encoding="utf-8"))
            return loaded if isinstance(loaded, Mapping) else FALLBACK_TOKENS
        except (OSError, json.JSONDecodeError) as exc:
            LOGGER.warning("Theme preview token read failed: %s", exc)
            return FALLBACK_TOKENS


def _finalize_tokens(generated: Mapping[str, Any], overrides: Mapping[str, Any] | None, color_temperature: int) -> dict[str, Any]:
    tokens: dict[str, Any] = merge_with_fallback(generated)
    if overrides:
        validate_config("palette-overrides", overrides)
        tokens = deep_token_merge(tokens, overrides)
    tokens.setdefault("metadata", {})["color_temperature"] = max(2700, min(6500, int(color_temperature)))
    corrected = enforce_contrast(tokens)
    problems = contrast_problems(corrected)
    if problems:
        raise ValueError(f"Theme contrast validation failed: {', '.join(problems)}")
    return corrected


def regenerate_tokens(
    wallpaper_path: str | None,
    overrides: dict[str, Any] | None = None,
    color_temperature: int = 6500,
) -> dict[str, dict[str, Any]]:
    """Regenerate and atomically publish the complete token set."""
    path = default_token_path()
    generated: Mapping[str, Any] = FALLBACK_TOKENS
    if wallpaper_path is None and path.exists():
        try:
            current = json.loads(path.read_text(encoding="utf-8"))
            if isinstance(current, Mapping): generated = current
        except (OSError, json.JSONDecodeError) as exc:
            LOGGER.warning("Current visual token read failed, regenerating from fallback: %s", exc)
    if wallpaper_path and shutil.which("matugen") and Path(wallpaper_path).expanduser().is_file():
        subprocess.run(
            ["matugen", "image", str(Path(wallpaper_path).expanduser()), "--type", "scheme-tonal-spot"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=1.8, check=False,
        )
        if path.exists():
            try:
                loaded = json.loads(path.read_text(encoding="utf-8"))
                if isinstance(loaded, Mapping):
                    generated = loaded
            except (OSError, json.JSONDecodeError) as exc:
                LOGGER.warning("Generated visual token read failed, using previous fallback: %s", exc)
    override_data = overrides
    override_path = Path(os.environ.get("LUMINA_CONFIG_HOME", Path.home() / ".config/lumina")) / "palette-overrides.json"
    if override_data is None and override_path.exists():
        try:
            candidate = json.loads(override_path.read_text(encoding="utf-8"))
            if not isinstance(candidate, Mapping):
                raise ValueError("palette-overrides root is not an object")
            validate_config("palette-overrides", candidate)
            override_data = dict(candidate)
        except (OSError, json.JSONDecodeError) as exc:
            LOGGER.warning("Palette override read failed, ignoring overrides: %s", exc)
    tokens = _finalize_tokens(generated, override_data, color_temperature)
    if shutil.which("hyprsunset"):
        subprocess.run(["pkill", "-x", "hyprsunset"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
        subprocess.Popen(["hyprsunset", "-t", str(tokens["metadata"]["color_temperature"])], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    _atomic_json(path, tokens)
    emit_settings_changed("theme", str(path))
    return tokens


def preview_tokens(wallpaper_path: str, overrides: Mapping[str, Any] | None = None, color_temperature: int = 6500) -> dict[str, Any]:
    """Generate a preview in an isolated temporary home without publishing state."""
    return _finalize_tokens(_preview_matugen(wallpaper_path), overrides, color_temperature)


def deep_token_merge(base: Mapping[str, Any], override: Mapping[str, Any]) -> dict[str, Any]:
    merged: dict[str, Any] = copy.deepcopy(dict(base))
    for key, value in override.items():
        if isinstance(value, Mapping) and isinstance(merged.get(key), Mapping):
            merged[key] = deep_token_merge(merged[key], value)
        else:
            merged[key] = copy.deepcopy(value)
    return merged


def tokens_to_hypr(tokens: Mapping[str, Mapping[str, Any]]) -> str:
    colors = merge_with_fallback(tokens)["colors"]
    primary = str(colors["primary"]).lstrip("#")
    secondary = str(colors["secondary"]).lstrip("#")
    outline = str(colors["outline"]).lstrip("#")
    surface = str(colors["surface"]).lstrip("#")
    warning = str(colors["warning"]).lstrip("#")
    danger = str(colors["danger"]).lstrip("#")
    return "\n".join((
        f"$accent = rgb({primary})",
        f"$accent_alt = rgb({secondary})",
        f"$border_active_a = rgb({primary})",
        f"$border_active_b = rgb({secondary})",
        f"$border_inactive = rgb({outline})",
        f"$surface = rgb({surface})",
        f"$warning = rgb({warning})",
        f"$danger = rgb({danger})",
        "",
    ))


def apply_hypr_colors(tokens: Mapping[str, Mapping[str, Any]]) -> Path:
    path = Path(os.environ.get("LUMINA_HYPR_CONFIG", Path.home() / ".config/hypr")) / "conf.d/tokens-colors.conf"
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".conf.tmp")
    tmp.write_text("# Generated by lumina-theme. Do not edit.\n" + tokens_to_hypr(tokens), encoding="utf-8")
    os.replace(tmp, path)
    return path


def apply_gtk_theme(tokens: Mapping[str, Mapping[str, Any]]) -> None:
    emit_settings_changed("theme.css", tokens_to_css(tokens))


def apply_theme(wallpaper_path: str | None, overrides: dict[str, Any] | None = None, color_temperature: int = 6500) -> dict[str, Any]:
    """Apply Theme Engine output through every owned platform surface."""
    with theme_apply_lock():
        if wallpaper_path:
            wallpaper = Path(wallpaper_path).expanduser()
            if wallpaper.is_file():
                cache = Path.home() / ".cache/matugen/wallpaper-cache"
                cache.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(wallpaper, cache)
        tokens = regenerate_tokens(wallpaper_path, overrides, color_temperature)
        apply_hypr_colors(tokens)
        apply_gtk_theme(tokens)
        sync_surfaces()
    return tokens
