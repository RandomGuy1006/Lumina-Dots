#!/usr/bin/env python3
"""Static validation for Lumina Core and Lumina-owned Python apps."""

from __future__ import annotations

import py_compile
import base64
import concurrent.futures
import json
import os
import re
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APPS = ROOT / "apps"
CORE = APPS / "lib" / "lumina_core"


def fail(message: str) -> None:
    print(message)
    raise SystemExit(1)


def assert_exists(path: Path) -> None:
    if not path.exists():
        fail(f"Missing required path: {path.relative_to(ROOT)}")


def compile_python() -> None:
    for path in sorted(APPS.rglob("*.py")):
        py_compile.compile(str(path), doraise=True)


def validate_import_policy() -> None:
    for path in sorted(APPS.rglob("*.py")):
        if CORE in path.parents or path == CORE / "__init__.py":
            continue
        text = path.read_text(encoding="utf-8")
        if "lumina_core" not in text:
            fail(f"GUI app bypasses lumina_core: {path.relative_to(ROOT)}")


def validate_no_core_bypass() -> None:
    forbidden = {
        "~/.cache/lumina/visual-tokens.json": "use lumina_core.theme",
        "~/.local/state/lumina": "use lumina_core.state",
        "notify-send": "use lumina_core.notifications",
    }
    for path in sorted(APPS.rglob("*.py")):
        if CORE in path.parents or path == CORE / "__init__.py":
            continue
        text = path.read_text(encoding="utf-8")
        for needle, guidance in forbidden.items():
            if needle in text:
                fail(f"{path.relative_to(ROOT)} hardcodes {needle}; {guidance}")


def validate_token_loader() -> None:
    sys.path.insert(0, str(APPS / "lib"))
    from lumina_core.theme import FALLBACK_TOKENS, load_tokens, tokens_to_css

    tokens = load_tokens(path=ROOT / "does-not-exist.json")
    if tokens != FALLBACK_TOKENS:
        fail("Fallback token loading does not match the canonical fallback shape")
    css = tokens_to_css(tokens)
    if "--lumina-colors-accent" not in css:
        fail("Token CSS helper did not emit Lumina CSS variables")


def validate_platform_foundation() -> None:
    sys.path.insert(0, str(APPS / "lib"))
    from lumina_core.glass import (
        GLASS_PRESETS,
        GlassMode,
        apply_glass_layerrules,
        glass_css,
        load_glass_config,
    )
    from lumina_core.mood import (
        MOOD_PROFILES,
        Mood,
        current_mood,
        detect_mood_from_wallpaper,
    )
    from lumina_core.schema import validate_config
    from lumina_core.toasts import ICON_MAP
    from lumina_core.wallpaper import (
        effective_transition,
        generate_directory_thumbnails,
        load_wallpaper_config,
        picker_items,
        swww_transition,
        wallpaper_candidates,
    )

    if len(GLASS_PRESETS) != 5 or len(MOOD_PROFILES) != 8 or len(ICON_MAP) != 4:
        fail("Platform preset tables are incomplete")
    with tempfile.TemporaryDirectory() as tmp:
        previous_config = os.environ.get("LUMINA_CONFIG_HOME")
        previous_hypr = os.environ.get("LUMINA_HYPR_CONFIG")
        os.environ["LUMINA_CONFIG_HOME"] = str(Path(tmp) / "config")
        os.environ["LUMINA_HYPR_CONFIG"] = str(Path(tmp) / "hypr")
        try:
            if load_glass_config().mode is not GlassMode.FROSTED:
                fail("Missing glass config does not fall back to Frosted")
            css = glass_css(GLASS_PRESETS[GlassMode.FROSTED])
            for token in ("bg", "blur", "noise", "border", "tint", "bright"):
                if f"--glass-{token}" not in css:
                    fail(f"Glass CSS is missing --glass-{token}")
            started = time.perf_counter()
            output = apply_glass_layerrules(GLASS_PRESETS[GlassMode.FROSTED])
            if (time.perf_counter() - started) * 1000 > 50:
                fail("Glass layerrule generation exceeded 50 ms")
            if not output.exists() or not output.read_text(encoding="utf-8").strip():
                fail("Glass rules output is empty")
            detected = detect_mood_from_wallpaper("ocean-blue.jpg")
            if (
                current_mood() is not Mood.NATURE
                or not isinstance(detected, concurrent.futures.Future)
                or detected.result(timeout=1) is not Mood.OCEAN
            ):
                fail("Mood fallback or non-blocking detection contract failed")
            wallpaper_config = Path(tmp) / "config" / "wallpaper.json"
            wallpaper_config.parent.mkdir(parents=True, exist_ok=True)
            wallpaper_config.write_text(
                json.dumps(
                    {
                        "directory": str(Path(tmp)),
                        "auto_rotate": False,
                        "rotation_interval": 30,
                        "animated": False,
                        "transition": "zoom",
                        "transition_duration": 1.7,
                    }
                ),
                encoding="utf-8",
            )
            if load_wallpaper_config().transition_duration != 1.7:
                fail("Wallpaper transition duration is not sourced from wallpaper.json")
            if effective_transition(
                config=load_wallpaper_config(), reduced_motion=True
            ) != ("none", 0.0):
                fail("Wallpaper reduced-motion transition override is missing")
            if swww_transition("zoom") != "grow":
                fail(
                    "Wallpaper transition mapping does not preserve the public zoom style"
                )
            validate_config(
                "wallpaper", json.loads(wallpaper_config.read_text(encoding="utf-8"))
            )
            invalid = json.loads(wallpaper_config.read_text(encoding="utf-8"))
            invalid.pop("transition_duration")
            invalid_rejected = False
            try:
                validate_config("wallpaper", invalid)
            except Exception:
                invalid_rejected = True
            if not invalid_rejected:
                fail(
                    "Incomplete wallpaper settings validated without transition_duration"
                )
            image = Path(tmp) / "sample.png"
            image.write_bytes(
                base64.b64decode(
                    "iVBORw0KGgoAAAANSUhEUgAAAMgAAABwCAIAAAD2HxkiAAAA0UlEQVR4nO3RMQEAIAzAMMC/5yFjRxMFfXpnZgLeZh8A7GQwGQwGQwGQwWQCGQwGg8FgMBgMBoPJBjIYDAaDwWAwGAyGkwlkMBgMBoPBYDAYDCYbyGAwGAwGg8FgMBhMNpDBYDAYDAaDwWAwGEw2kMFgMBgMBoPBYDCYbCCDwWAwGAwGg8FgMJlABoPBYDAYDAaDwWAymWwgg8FgMBgMBoPBYDCZQAaDwWAwGAwGg8FgMplABoPBYDAYDAaDwWAymWwgg8FgMBgMBoPBYDCZQAaDwWAwGAwGg8FgMplABoPBYDAYDAaDwWAw2QExGwH0mE8rFQAAAABJRU5ErkJggg=="
                )
            )
            thumbs = generate_directory_thumbnails(Path(tmp))
            if not thumbs or not any(Path(path).exists() for path in thumbs.values()):
                fail("Wallpaper directory thumbnail generation failed")
            if not wallpaper_candidates(Path(tmp)) or not picker_items(Path(tmp))[
                0
            ].get("thumbnail"):
                fail("Wallpaper picker thumbnail discovery is incomplete")
        finally:
            if previous_config is None:
                os.environ.pop("LUMINA_CONFIG_HOME", None)
            else:
                os.environ["LUMINA_CONFIG_HOME"] = previous_config
            if previous_hypr is None:
                os.environ.pop("LUMINA_HYPR_CONFIG", None)
            else:
                os.environ["LUMINA_HYPR_CONFIG"] = previous_hypr
    for schema in ("glass", "mood", "appearance", "wallpaper", "palette-overrides"):
        path = APPS / "settings-studio" / "schemas" / f"{schema}.schema.json"
        assert_exists(path)
        json.loads(path.read_text(encoding="utf-8"))
    xml = CORE / "dev.lumina.core.xml"
    assert_exists(xml)
    text = xml.read_text(encoding="utf-8")
    for interface in (
        "dev.lumina.settings",
        "dev.lumina.mood",
        "dev.lumina.glass",
        "dev.lumina.toast",
        "dev.lumina.wallpaper",
    ):
        if interface not in text:
            fail(f"D-Bus contract missing {interface}")
    for arg in ("message", "subtitle", "category"):
        if f'name="{arg}"' not in text:
            fail(f"D-Bus toast contract missing API argument: {arg}")
    for removed in ("icon", "duration", "action_label", "action_callback"):
        if f'name="{removed}"' in text:
            fail(
                f"D-Bus toast contract still exposes removed toast argument: {removed}"
            )
    dbus_service = (CORE / "dbus_service.py").read_text(encoding="utf-8")
    if "isinstance(values[1],str)" in dbus_service:
        fail(
            "D-Bus domain-specific signal emission still depends on unpacked string values"
        )
    if not all(
        fragment in dbus_service
        for fragment in ('"mood"', '"glass"', '"wallpaper"', "variant_to_string")
    ):
        fail("D-Bus domain-specific signal emission mapping is incomplete")
    if "from .search import search_results" not in dbus_service:
        fail("D-Bus search query path is not delegated to Lumina Search ownership")
    if "lumina-search.sock" in dbus_service or "socket.AF_UNIX" in dbus_service:
        fail("D-Bus service still depends on the removed phantom search socket")
    search_source = (CORE / "search.py").read_text(encoding="utf-8")
    if (
        "class SearchResult" not in search_source
        or "def search_results" not in search_source
    ):
        fail("Lumina Search source-owned query implementation is missing")
    toast_source = (CORE / "toasts.py").read_text(encoding="utf-8")
    if (
        '"error": 6000' not in toast_source
        or "dev.lumina.toast.Send" not in toast_source
    ):
        fail("Toast API defaults or D-Bus forwarding contract is incomplete")
    if 'call("dev.lumina.toast.Send", message, subtitle, category)' not in toast_source:
        fail("Toast API does not forward the canonical D-Bus toast contract")
    theme_source = (CORE / "theme.py").read_text(encoding="utf-8")
    if 'validate_config("palette-overrides"' not in theme_source:
        fail("Theme override read path does not validate palette-overrides schema")
    app_source = (CORE / "app.py").read_text(encoding="utf-8")
    if (
        "theme.css" not in app_source
        or "_theme_css" not in app_source
        or "_handle_settings_changed" not in app_source
    ):
        fail("GTK theme update path does not consume D-Bus CSS payloads")
    settings = APPS / "settings-studio" / "lumina-settings-studio.py"
    settings_text = settings.read_text(encoding="utf-8")
    appearance_schema = (
        APPS / "settings-studio" / "schemas" / "appearance.schema.json"
    ).read_text(encoding="utf-8")
    if (
        "Auto-set from Mood" not in settings_text
        or "auto_set_from_mood" not in appearance_schema
    ):
        fail(
            "Settings Studio lock-screen Mood sync setting or schema support is missing"
        )
    glass_schema = json.loads(
        (APPS / "settings-studio" / "schemas" / "glass.schema.json").read_text(
            encoding="utf-8"
        )
    )
    glass_required = set(glass_schema.get("required", []))
    for field in (
        "mode",
        "blur_size",
        "blur_passes",
        "opacity",
        "saturation",
        "tint_color",
        "noise",
        "brightness",
        "performance_mode",
        "battery_mode",
    ):
        if field not in glass_required:
            fail(f"Glass schema does not require {field}")
    for label in (
        "Glass Mode",
        "Advanced glass",
        "Opacity",
        "Blur",
        "Blur Passes",
        "Saturation",
        "Noise",
        "Brightness",
        "Tint Color",
        "Performance Mode",
        "Battery Mode",
    ):
        if label not in settings_text:
            fail(f"Settings Studio does not expose Glass setting: {label}")
    mood_source = (CORE / "mood.py").read_text(encoding="utf-8")
    mood_cli = (ROOT / "local-bin" / ".local" / "bin" / "lumina-mood").read_text(
        encoding="utf-8"
    )
    if (
        "ThreadPoolExecutor" not in mood_source
        or "Future[Mood]" not in mood_source
        or ".result()" not in mood_cli
    ):
        fail(
            "Wallpaper mood detection does not expose a non-blocking background submission path"
        )
    if list((ROOT / "scripts").rglob("*.sh")):
        offenders = [
            p
            for p in (ROOT / "scripts").rglob("*.sh")
            if "notify-send" in p.read_text(encoding="utf-8")
        ]
        if offenders:
            fail(
                f"Direct notification calls remain: {', '.join(str(p.relative_to(ROOT)) for p in offenders)}"
            )
    validate_glass_ownership()
    validate_startup_theme_wallpaper_wiring()
    validate_mission_control_contract()
    validate_wallpaper_step4_wiring()
    validate_release_regressions()


def validate_release_regressions() -> None:
    update = (ROOT / "update.sh").read_text(encoding="utf-8")
    if "notify-send" in update:
        fail("Root update.sh calls notify-send directly")
    if (
        'git -C "${DOTFILES_DIR}" stash push' not in update
        or 'git -C "${DOTFILES_DIR}" stash pop' not in update
    ):
        fail("Root update.sh does not stash/pop local changes around pull")

    keybind_overlay = (
        APPS / "keybind-overlay" / "lumina-keybind-overlay.py"
    ).read_text(encoding="utf-8")
    if 'run_command(["sh", "-lc", command]' in keybind_overlay:
        fail("Keybind Overlay still executes user-controlled shell strings")
    if (
        "registered_exec_commands" not in keybind_overlay
        or "shlex.split(command)" not in keybind_overlay
    ):
        fail("Keybind Overlay does not restrict execution to registered commands")

    subprocesses = (CORE / "subprocesses.py").read_text(encoding="utf-8")
    if (
        "except PermissionError" not in subprocesses
        or "except OSError" not in subprocesses
    ):
        fail("subprocesses.py does not convert OS execution errors into CommandResult")

    control = (APPS / "control-center" / "lumina-control-center.py").read_text(
        encoding="utf-8"
    )
    if '["sh", "-lc"' in control:
        fail("Control Center still uses shell wrappers for quick actions")
    if "datetime.datetime.now().strftime" not in control:
        fail("Control Center screenshot path is not generated in Python")

    shell = (APPS / "shell" / "lumina-shell.py").read_text(encoding="utf-8")
    if "_events = event_stream()" in shell:
        fail("Lumina Shell still has dead event_stream assignment")

    recover = (ROOT / "scripts" / "recover-hypr.sh").read_text(encoding="utf-8")
    if (
        "WAYLAND_DISPLAY" not in recover
        or "Refusing to launch fallback Hyprland" not in recover
    ):
        fail("recover-hypr.sh lacks active Wayland session guard")

    for service in (
        "loq-swww.service",
        "loq-hyprpanel.service",
        "loq-hypridle.service",
    ):
        text = (ROOT / "systemd" / ".config" / "systemd" / "user" / service).read_text(
            encoding="utf-8"
        )
        if "ConditionEnvironment=WAYLAND_DISPLAY" not in text:
            fail(f"{service} lacks WAYLAND_DISPLAY condition")

    packages = (ROOT / "scripts" / "install" / "02-packages.sh").read_text(
        encoding="utf-8"
    )
    if (
        'ZSH_PATH="$(command -v zsh)"' in packages
        or "command -v zsh || true" not in packages
    ):
        fail("02-packages.sh can still abort when zsh is absent")

    screenshots = (ROOT / "scripts" / "system" / "capture-screenshots.sh").read_text(
        encoding="utf-8"
    )
    if "command -v grimblast" not in screenshots:
        fail("capture-screenshots.sh lacks grimblast dependency guard")

    wallpaper_apply = (
        ROOT / "local-bin" / ".local" / "bin" / "wallpaper-apply"
    ).read_text(encoding="utf-8")
    if (
        "scripts/wallpaper-apply.sh" in wallpaper_apply
        or "scripts/theme/switch-wallpaper.sh" not in wallpaper_apply
    ):
        fail("wallpaper-apply compatibility wrapper still has an avoidable extra hop")

    ocr = (ROOT / "lumina" / ".config" / "lumina" / "ocr-pipeline.sh").read_text(
        encoding="utf-8"
    )
    if ocr.count("#!/usr/bin/env bash") != 1:
        fail("OCR pipeline still contains duplicate script bodies")


def validate_wallpaper_step4_wiring() -> None:
    script = ROOT / "scripts" / "theme" / "switch-wallpaper.sh"
    settings = APPS / "settings-studio" / "lumina-settings-studio.py"
    script_text = script.read_text(encoding="utf-8")
    settings_text = settings.read_text(encoding="utf-8")
    required_script_needles = (
        "from lumina_core.wallpaper import effective_transition, swww_transition",
        "lumina theme apply",
        "lumina-mood detect --wallpaper",
        'sleep "${TRANSITION_DURATION}"',
        "generate_thumbnail",
        'lumina-toast "Wallpaper applied" "$(basename',
    )
    for needle in required_script_needles:
        if needle not in script_text:
            fail(f"Wallpaper cascade script missing required wiring: {needle}")
    if "scripts/theme/apply-theme.sh" in script_text or "matugen image" in script_text:
        fail("Wallpaper cascade contains a duplicate/ad-hoc theme pipeline")
    order = [
        script_text.index(needle)
        for needle in (
            "swww img",
            'sleep "${TRANSITION_DURATION}"',
            "lumina theme apply",
            "lumina-mood detect --wallpaper",
            'lumina-toast "Wallpaper applied" "$(basename',
        )
    ]
    if order != sorted(order):
        fail("Wallpaper cascade ordering does not match the implementation reference")
    for needle in (
        "Transition duration",
        "transition_duration",
        "generate_directory_thumbnails",
        "Wallpaper picker",
        "lumina-wallpaper",
    ):
        if needle not in settings_text:
            fail(
                f"Settings Studio Wallpaper page missing required control/wiring: {needle}"
            )


def validate_glass_ownership() -> None:
    renderer = (ROOT / "scripts" / "theme" / "render-visual-tokens.sh").read_text(
        encoding="utf-8"
    )
    for forbidden in (
        "read_token '.blur.",
        "$blur_size",
        "$blur_passes",
        "backdrop-filter: blur",
        "background-blur-radius",
    ):
        if forbidden in renderer:
            fail(f"Theme renderer bypasses Glass Engine ownership: {forbidden}")
    matugen_template = json.loads(
        (
            ROOT
            / "matugen"
            / ".config"
            / "matugen"
            / "templates"
            / "visual-tokens.json"
        ).read_text(encoding="utf-8")
    )
    if "blur" in matugen_template:
        fail("Matugen visual token template still defines Glass Engine blur tokens")
    theme_source = (CORE / "theme.py").read_text(encoding="utf-8")
    if '"glass":' in theme_source or '"blur":' in theme_source:
        fail("Theme Engine fallback tokens still define Glass Engine tokens")
    for path in (
        ROOT / "hypr" / ".config" / "hypr" / "decorations.conf",
        ROOT / "hypr" / ".config" / "hypr" / "rules.conf",
    ):
        text = path.read_text(encoding="utf-8")
        for forbidden in ("blur {", "layerrule = blur", " opacity "):
            if forbidden in text:
                fail(
                    f"Hypr config bypasses Glass Engine ownership in {path.name}: {forbidden}"
                )
    hyprland = (ROOT / "hypr" / ".config" / "hypr" / "hyprland.conf").read_text(
        encoding="utf-8"
    )
    for required in ("conf.d/glass-rules.conf", "conf.d/tokens-colors.conf"):
        if required not in hyprland:
            fail(f"Hyprland does not source generated ownership file: {required}")
        if not (ROOT / "hypr" / ".config" / "hypr" / required).is_file():
            fail(f"Generated ownership seed file is missing: {required}")


def validate_startup_theme_wallpaper_wiring() -> None:
    install_theme = (ROOT / "scripts" / "install" / "04-theme.sh").read_text(
        encoding="utf-8"
    )
    root_wrapper = (ROOT / "scripts" / "apply-theme.sh").read_text(encoding="utf-8")
    theme_wrapper = (ROOT / "scripts" / "theme" / "apply-theme.sh").read_text(
        encoding="utf-8"
    )
    if "lumina-theme apply --wallpaper" not in install_theme:
        fail("Startup theme initialization does not call lumina-theme")
    if (
        "scripts/theme/apply-theme.sh" in root_wrapper
        or "matugen image" in root_wrapper
    ):
        fail("Root apply-theme compatibility wrapper bypasses lumina-theme")
    if "lumina-theme apply --wallpaper" not in root_wrapper:
        fail("Root apply-theme compatibility wrapper does not delegate to lumina-theme")
    if "matugen image" in theme_wrapper or "sync-surfaces.sh" in theme_wrapper:
        fail("Theme compatibility wrapper still carries the ad-hoc Matugen pipeline")
    if "lumina-theme" not in theme_wrapper:
        fail("Theme compatibility wrapper does not delegate to lumina-theme")
    exec_conf = (ROOT / "hypr" / ".config" / "hypr" / "exec.conf").read_text(
        encoding="utf-8"
    )
    if "swww img" in exec_conf:
        fail(
            "Hypr startup restores wallpaper directly instead of using lumina-wallpaper"
        )
    if "lumina-wallpaper" not in exec_conf:
        fail("Hypr startup does not route wallpaper restore through lumina-wallpaper")


def validate_mission_control_contract() -> None:
    mission = (APPS / "mission-control" / "lumina-mission-control.py").read_text(
        encoding="utf-8"
    )
    mission_doc = (ROOT / "docs" / "features" / "mission-control.md").read_text(
        encoding="utf-8"
    )
    keybindings = (ROOT / "docs" / "keybindings.md").read_text(encoding="utf-8")
    for required in (
        'parser.add_argument("--json"',
        'window.add_css_class("glass-surface")',
        "overview_payload",
        "Workspace {workspace.get('name')}",
    ):
        if required not in mission:
            fail(f"Mission Control source contract missing: {required}")
    if (
        "does not require `hyprexpo`, `hyprland-overview`, `hyprpm`, or any Hyprland overview plugin"
        not in mission_doc
    ):
        fail(
            "Mission Control feature doc does not state the implemented non-plugin contract"
        )
    if (
        "| `Super + Tab` | Navigation | `uwsm app -- lumina-mission-control` |"
        not in keybindings
    ):
        fail("Mission Control keybind is missing or miscategorized")


def main() -> int:
    assert_exists(CORE / "__init__.py")
    assert_exists(APPS / "shell" / "lumina-shell.py")
    compile_python()
    validate_import_policy()
    validate_no_core_bypass()
    validate_token_loader()
    validate_platform_foundation()
    print("Lumina Core validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
