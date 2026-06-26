#!/usr/bin/env python3
"""Optional Lumina AI Assistant."""

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
from lumina_core.config import ensure_config, load_config
from lumina_core.errors import DependencyUnavailable
from lumina_core.subprocesses import run_command
from lumina_core.widgets import command_button, section_heading
from components.popups import dispatch_event

DEFAULT_CONFIG = {
    "ai": {
        "backend": "pattern",
        "allow_cloud": False,
        "ollama_model": "gemma3:4b",
        "timeout_seconds": 25,
    }
}

def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def safe_actions() -> dict[str, tuple[str, ...]]:
    return {
        "doctor": ("lumina-doctor-dashboard",),
        "theme-studio": ("lumina-theme-studio",),
        "keybinds": ("lumina-keybind-overlay",),
        "recovery": ("xdg-open", str(repo_root() / "docs" / "recovery.md")),
        "hub": ("lumina-hub",),
    }


@dataclass(frozen=True)
class AIResponse:
    backend: str
    prompt: str
    response: str
    action: str | None = None
    warning: str = ""


def config() -> dict:
    ensure_config("ai", DEFAULT_CONFIG)
    return load_config("ai", DEFAULT_CONFIG)


def pattern_response(prompt: str) -> AIResponse:
    text = prompt.strip()
    lower = text.lower()
    if not text:
        return AIResponse("pattern", text, "Ask about keybinds, Doctor, themes, recovery, snapshots, Hub, or Mission Control.")
    if "keybind" in lower or "shortcut" in lower:
        return AIResponse("pattern", text, "Open the searchable keybind overlay with Super + /, or run `lumina-keybind-overlay --json`.", "keybinds")
    if "doctor" in lower or "health" in lower or "diagnostic" in lower:
        return AIResponse("pattern", text, "Run `dotfiles doctor --full` for runtime health, or open Doctor Dashboard with Super + D.", "doctor")
    if "theme" in lower or "wallpaper" in lower or "palette" in lower:
        return AIResponse("pattern", text, "Use Theme Studio or run `dotfiles theme <wallpaper>`. Theme Studio applies through the existing pipeline.", "theme-studio")
    if "rollback" in lower or "recover" in lower or "snapshot" in lower:
        return AIResponse("pattern", text, "Use Snapshot Manager for snapshots and read `docs/recovery.md` before any rollback. Online root rollback is intentionally not exposed.", "recovery")
    if "hub" in lower:
        return AIResponse("pattern", text, "Lumina Hub opens with Super + L and aggregates mode state, app launchers, and recent activity.", "hub")
    if "mission" in lower or "workspace" in lower or "window" in lower:
        return AIResponse("pattern", text, "Mission Control opens with Super + Tab. Workspace cycling moved to Super + ] and Super + [.")
    if "validate" in lower or "release" in lower:
        return AIResponse("pattern", text, "Run `dotfiles validate`, then targeted checks like `dotfiles validate services` or `dotfiles validate themes`.")
    return AIResponse("pattern", text, "I can help with Lumina keybinds, Doctor, themes, recovery, Hub, Mission Control, and release validation.")


def ollama_response(prompt: str, settings: dict) -> AIResponse:
    ai = settings.get("ai", {}) if isinstance(settings.get("ai"), dict) else {}
    model = str(ai.get("ollama_model", DEFAULT_CONFIG["ai"]["ollama_model"]))
    timeout = int(ai.get("timeout_seconds", DEFAULT_CONFIG["ai"]["timeout_seconds"]))
    result = run_command(["ollama", "run", model, prompt], timeout=timeout)
    if not result.ok:
        fallback = pattern_response(prompt)
        return AIResponse("pattern", prompt, fallback.response, fallback.action, "Ollama unavailable; used pattern mode.")
    return AIResponse("ollama", prompt, result.stdout.strip() or pattern_response(prompt).response)


def answer(prompt: str) -> AIResponse:
    settings = config()
    ai = settings.get("ai", {}) if isinstance(settings.get("ai"), dict) else {}
    backend = str(ai.get("backend", "pattern")).lower()
    if backend in {"ollama", "gemma-ollama"}:
        return ollama_response(prompt, settings)
    if backend in {"gemma-api", "openai"} and not bool(ai.get("allow_cloud", False)):
        fallback = pattern_response(prompt)
        return AIResponse("pattern", prompt, fallback.response, fallback.action, "Cloud backend disabled; used pattern mode.")
    return pattern_response(prompt)


def launch_action(action: str) -> bool:
    command = safe_actions().get(action)
    if command is None:
        raise ValueError(f"Unsupported AI action: {action}")
    result = run_command(["uwsm", "app", "--", *command], timeout=5)
    if result.missing:
        result = run_command(command, timeout=5)
    dispatch_event("ai", body=action if result.ok else result.stderr.strip(), urgency="normal" if result.ok else "critical")
    return result.ok


class LuminaAIApp(LuminaApplication):
    def __init__(self, prompt: str = ""):
        self.prompt = prompt
        super().__init__("lumina-ai", "Lumina AI")

    def build(self, window):
        Gtk = self.Gtk
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        box.set_margin_top(16)
        box.set_margin_bottom(16)
        box.set_margin_start(16)
        box.set_margin_end(16)
        response = answer(self.prompt)
        box.append(section_heading("Lumina AI"))
        label = Gtk.Label(label=response.response)
        label.set_wrap(True)
        label.set_xalign(0)
        box.append(label)
        if response.warning:
            warning = Gtk.Label(label=response.warning)
            warning.set_wrap(True)
            warning.set_xalign(0)
            box.append(warning)
        for key in safe_actions():
            box.append(command_button(key.replace("-", " ").title(), lambda _button, action=key: launch_action(action)))
        window.set_content(box)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="lumina-ai")
    parser.add_argument("prompt", nargs="*", help="question for the assistant")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--action", choices=sorted(safe_actions()))
    parser.add_argument("--config-path", action="store_true")
    args = parser.parse_args(argv)
    prompt = " ".join(args.prompt)
    if args.config_path:
        print(ensure_config("ai", DEFAULT_CONFIG))
        return 0
    if args.action:
        return 0 if launch_action(args.action) else 1
    if args.json:
        print(json.dumps(asdict(answer(prompt)), indent=2, sort_keys=True))
        return 0
    if prompt:
        response = answer(prompt)
        print(response.response)
        if response.warning:
            print(response.warning)
        return 0
    try:
        return LuminaAIApp(prompt).run(sys.argv)
    except DependencyUnavailable:
        print(answer(prompt).response)
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
