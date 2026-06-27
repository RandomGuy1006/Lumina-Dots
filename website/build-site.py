#!/usr/bin/env python3
"""Regenerate repository-backed data embedded in the Lumina website."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
INDEX = ROOT / "website" / "index.html"
EXCLUDED_PARTS = {
    ".git",
    ".mypy_cache",
    ".ruff_cache",
    ".test-home",
    ".tmp",
    "__pycache__",
    "logs",
    "vendor",
}
ROOT_DOCS = {
    "ARCH_INSTALL_VALIDATION.md",
    "BUG_REPORT_TEMPLATE.md",
    "CHANGELOG.md",
    "README.md",
    "RELEASE_CANDIDATE_TEST_PLAN.md",
    "RUNTIME_RISK_MATRIX.md",
    "TEST_CHECKLIST.md",
}
ACTION_NAMES = {
    "$terminal": "Terminal (Ghostty)",
    "$fileManager": "File manager (Nautilus)",
    "$browser": "Browser (Firefox)",
    "$launcher": "Launcher (Walker)",
    "killactive": "Close active window",
    "togglefloating": "Toggle floating",
    "fullscreen": "Toggle fullscreen",
    "togglesplit": "Toggle split direction",
    "pseudo": "Toggle pseudo tile",
    "pin": "Pin floating window",
}


def included(path: Path) -> bool:
    rel = path.relative_to(ROOT)
    return not any(part in EXCLUDED_PARTS for part in rel.parts) and path.suffix != ".pyc"


def description(path: str, is_dir: bool) -> str:
    if path.startswith("apps/"):
        return "Lumina GTK/Python applications and shared shell contracts."
    if path.startswith("docs/"):
        return "Product, install, recovery, design, and verification documentation."
    if path.startswith("hypr/"):
        return "Hyprland session, input, animation, lock, idle, and script configuration."
    if path.startswith("scripts/theme/") or path.startswith("matugen/"):
        return "Wallpaper-driven Material You theme and visual-token pipeline."
    if path.startswith("schemas/"):
        return "Machine-readable Lumina contract schemas."
    if path.startswith("tests/"):
        return "Static, unit, integration, recovery, visual, and website verification."
    if path.startswith("website/"):
        return "Static product website, repository explorer, and embedded documentation."
    if path.startswith("packages/"):
        return "Versioned pacman and AUR package manifests."
    if path.startswith("systemd/"):
        return "User-session services and targets."
    kind = "Directory" if is_dir else "Repository file"
    return f"{kind}: {Path(path).name}."


def build_manifest() -> list[dict[str, str]]:
    entries: list[dict[str, str]] = []
    paths = sorted((path for path in ROOT.rglob("*") if included(path)), key=lambda p: p.as_posix().lower())
    for path in paths:
        rel = path.relative_to(ROOT).as_posix()
        entries.append(
            {
                "type": "dir" if path.is_dir() else "file",
                "path": rel,
                "name": path.name,
                "description": description(rel, path.is_dir()),
            }
        )
    return entries


def package_names(pattern: str) -> set[str]:
    names: set[str] = set()
    for manifest in sorted((ROOT / "packages").glob(pattern)):
        for raw in manifest.read_text(encoding="utf-8").splitlines():
            line = raw.split("#", 1)[0].strip()
            if line:
                names.add(line.split()[0])
    return names


def title_for(path: Path, content: str) -> str:
    match = re.search(r"^#\s+(.+?)\s*$", content, re.MULTILINE)
    if match:
        return match.group(1).strip().replace("`", "")
    return path.stem.replace("-", " ").title()


def doc_category(rel: str) -> str:
    if rel.startswith("docs/features/"):
        return "Features"
    if rel.startswith("docs/implementation/"):
        return "Implementation"
    if rel.startswith("docs/design/"):
        return "Governance"
    if rel in {"README.md", "CHANGELOG.md"}:
        return "Essentials"
    if rel.startswith("docs/"):
        return "Guides"
    return "Quality"


def build_docs() -> list[dict[str, str]]:
    paths = [ROOT / name for name in ROOT_DOCS if (ROOT / name).is_file()]
    paths.extend(sorted((ROOT / "docs").rglob("*.md")))
    docs = []
    for path in sorted(paths, key=lambda p: p.relative_to(ROOT).as_posix().lower()):
        rel = path.relative_to(ROOT).as_posix()
        content = path.read_text(encoding="utf-8")
        docs.append(
            {
                "id": re.sub(r"[^a-z0-9]+", "-", rel.lower()).strip("-"),
                "title": title_for(path, content),
                "category": doc_category(rel),
                "path": rel,
                "content": content,
            }
        )
    return docs


def pretty_key(value: str) -> str:
    aliases = {"slash": "/", "Return": "Return", "Space": "Space", "Escape": "Escape"}
    return aliases.get(value, value.upper() if len(value) == 1 else value.title())


def action_for(dispatcher: str, command: str) -> str:
    haystack = f"{dispatcher} {command}".lower()
    known = [
        ("keybinds-popup", "Searchable keybind overlay"),
        ("lumina-control-center", "Lumina Control Center"),
        ("lumina-doctor-dashboard", "Doctor Dashboard"),
        ("lumina-snapshot-manager", "Snapshot Manager"),
        ("lumina-hub", "Lumina Hub"),
        ("lumina-ai", "Lumina AI"),
        ("scratch-notes", "Scratch notes"),
        ("focus-mode", "Focus mode"),
        ("ocr-region", "Region OCR"),
        ("grimblast", "Screenshot"),
        ("cliphist", "Clipboard history"),
        ("hyprctl keyword source ~/.config/hypr/colors.conf", "Source desktop shell colors"),
        ("movefocus", "Move focus"),
        ("movewindow", "Move window"),
        ("resizeactive", "Resize active window"),
    ]
    for needle, label in known:
        if needle in haystack:
            return label
    if dispatcher == "workspace" and command:
        return f"Workspace {command.split()[-1]}"
    if command in ACTION_NAMES:
        return ACTION_NAMES[command]
    if dispatcher in ACTION_NAMES:
        return ACTION_NAMES[dispatcher]
    if dispatcher == "exec":
        return command.replace("$terminal -e ", "").replace("uwsm app -- ", "").strip().title()
    return dispatcher.replace("-", " ").title()


def category_for(action: str) -> str:
    lower = action.lower()
    if any(word in lower for word in ("terminal", "browser", "launcher", "manager", "center", "dashboard", "hub", "ai", "notes")):
        return "Apps"
    if any(word in lower for word in ("workspace", "focus", "window", "fullscreen", "float", "resize", "split", "tile", "pin")):
        return "Windows"
    if any(word in lower for word in ("screenshot", "ocr", "clipboard")):
        return "Utilities"
    return "System"


def build_keybindings() -> list[dict[str, object]]:
    bindings = []
    source = ROOT / "hypr" / ".config" / "hypr" / "binds.conf"
    for raw in source.read_text(encoding="utf-8").splitlines():
        match = re.match(r"^bind[a-z]*\s*=\s*(.*)$", raw.strip())
        if not match:
            continue
        parts = [part.strip() for part in match.group(1).split(",", 3)]
        if len(parts) < 3:
            continue
        modifiers, key, dispatcher = parts[:3]
        command = parts[3] if len(parts) == 4 else ""
        mod = modifiers.replace("$mod", "Super").replace("CTRL", "Ctrl").replace("SHIFT", "Shift").replace("ALT", "Alt")
        bind = " + ".join(part for part in (" ".join(mod.split()), pretty_key(key)) if part)
        action = action_for(dispatcher, command)
        bindings.append({"order": len(bindings) + 1, "bind": bind, "action": action, "cat": category_for(action)})
    return bindings


def render(source: str) -> str:
    manifest = build_manifest()
    files = sum(item["type"] == "file" for item in manifest)
    dirs = sum(item["type"] == "dir" for item in manifest)
    data = {
        "site": {
            "version": (ROOT / ".version").read_text(encoding="utf-8").strip(),
            "manifest": manifest,
            "pacmanCount": len(package_names("pacman*.txt")),
            "aurCount": len(package_names("aur*.txt")),
            "keybindings": build_keybindings(),
            "fileCount": files,
            "dirCount": dirs,
        },
        "docs": build_docs(),
    }
    payload = json.dumps(data, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/")
    source = re.sub(
        r'(<script type="application/json" id="lumina-embed-data">)\s*.*?\s*(</script>)',
        lambda match: f"{match.group(1)}\n{payload}\n{match.group(2)}",
        source,
        count=1,
        flags=re.DOTALL,
    )
    source = re.sub(r"↻ v[0-9][^<]*", f"↻ v{data['site']['version']}", source, count=1)
    source = re.sub(r"lumina-dots v[0-9][^·<]*", f"lumina-dots v{data['site']['version']} ", source, count=1)
    return source


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="Fail when index.html is not regenerated")
    args = parser.parse_args()
    current = INDEX.read_text(encoding="utf-8")
    generated = render(current)
    if args.check:
        if generated != current:
            print("website/index.html is stale; run: python website/build-site.py")
            return 1
        print("Website embedded repository data is current")
        return 0
    INDEX.write_text(generated, encoding="utf-8", newline="\n")
    print("Updated website/index.html from repository state")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
