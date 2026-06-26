#!/usr/bin/env python3
"""Architecture validation for Lumina-owned platform surfaces."""

from __future__ import annotations

import ast
import re
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APPS = ROOT / "apps"
CORE = APPS / "lib" / "lumina_core"
SYSTEMD_USER = ROOT / "systemd" / ".config" / "systemd" / "user"


def fail(message: str) -> None:
    print(message)
    raise SystemExit(1)


def module_name(path: Path) -> str:
    rel = path.relative_to(APPS)
    if rel.parts[0] == "lib":
        rel = Path(*rel.parts[1:])
    elif len(rel.parts) > 2 and rel.parts[0] == "shell" and rel.parts[1] in {"components", "adapters"}:
        rel = Path(*rel.parts[1:])
    name = ".".join(rel.with_suffix("").parts)
    return name.removesuffix(".__init__")


def import_graph() -> dict[str, set[str]]:
    modules = {module_name(path): path for path in APPS.rglob("*.py")}
    graph: dict[str, set[str]] = {name: set() for name in modules}
    for name, path in modules.items():
        tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
        for node in ast.walk(tree):
            imported: str | None = None
            if isinstance(node, ast.Import):
                for alias in node.names:
                    imported = alias.name
                    if imported in graph:
                        graph[name].add(imported)
            elif isinstance(node, ast.ImportFrom) and node.module:
                if node.level:
                    parts = name.split(".")
                    base = parts[: max(0, len(parts) - node.level)]
                    imported = ".".join([*base, node.module])
                else:
                    imported = node.module
                if imported in graph:
                    graph[name].add(imported)
    return graph


def validate_no_cycles() -> None:
    graph = import_graph()
    visiting: set[str] = set()
    visited: set[str] = set()
    stack: list[str] = []

    def visit(node: str) -> None:
        if node in visited:
            return
        if node in visiting:
            cycle = stack[stack.index(node) :] + [node]
            fail(f"Circular Python import detected: {' -> '.join(cycle)}")
        visiting.add(node)
        stack.append(node)
        for child in graph[node]:
            visit(child)
        stack.pop()
        visiting.remove(node)
        visited.add(node)

    for node in graph:
        visit(node)


def validate_packages() -> None:
    seen_global: dict[str, Path] = {}
    for manifest in sorted((ROOT / "packages").glob("*.txt")):
        seen_local: set[str] = set()
        for line in manifest.read_text(encoding="utf-8").splitlines():
            pkg = line.strip()
            if not pkg or pkg.startswith("#"):
                continue
            if pkg in seen_local:
                fail(f"Duplicate package in {manifest.relative_to(ROOT)}: {pkg}")
            seen_local.add(pkg)
            previous = seen_global.get(pkg)
            if previous and previous.name.startswith("pacman") and manifest.name.startswith("pacman"):
                fail(f"Package declared in multiple pacman manifests: {pkg} ({previous.name}, {manifest.name})")
            seen_global[pkg] = manifest


def validate_services() -> None:
    names: dict[str, Path] = {}
    for unit in SYSTEMD_USER.glob("*"):
        if not unit.is_file():
            continue
        if unit.name in names:
            fail(f"Duplicate systemd user unit: {unit.name}")
        names[unit.name] = unit
    lumina_shell = SYSTEMD_USER / "lumina-shell.service"
    if not lumina_shell.exists():
        fail("Missing lumina-shell.service")
    text = lumina_shell.read_text(encoding="utf-8")
    for required in ["PartOf=loq-session.target", "WantedBy=loq-session.target"]:
        if required not in text:
            fail(f"lumina-shell.service missing {required}")
    welcome = SYSTEMD_USER / "lumina-welcome.service"
    if not welcome.exists():
        fail("Missing lumina-welcome.service")
    welcome_text = welcome.read_text(encoding="utf-8")
    if "WantedBy=loq-session.target" not in welcome_text:
        fail("lumina-welcome.service is not tied to loq-session.target")


def validate_links() -> None:
    link = ROOT / "lib" / "link.sh"
    text = link.read_text(encoding="utf-8")
    entries = re.findall(r"^([^|\n]+)\|\$\{HOME\}/([^\n]+)$", text, flags=re.MULTILINE)
    for src, _target in entries:
        if "$" in src:
            continue
        if not (ROOT / src).exists():
            fail(f"Link source does not exist: {src}")
    if "apps/lib|${HOME}/.local/share/lumina/lib" not in text:
        fail("apps/lib tree is not linked into Lumina share path")
    if "apps/shell/lumina-shell.py|${HOME}/.local/bin/lumina-shell" not in text:
        fail("lumina-shell executable direct link is missing")


def validate_architecture_claims() -> None:
    forbidden = {
        "SDDM": "Lumina uses TTY login with UWSM, not SDDM",
        "sddm.service": "Lumina uses TTY login with UWSM, not SDDM",
        "Super+L is lock": "Super+Escape is the lock bind",
        "Crazy Mode": "Custom Mode replaces Crazy Mode",
    }
    paths = [ROOT / "README.md", ROOT / "website" / "index.html", *list((ROOT / "docs").rglob("*.md"))]
    for path in paths:
        if not path.exists():
            continue
        text = path.read_text(encoding="utf-8")
        for needle, reason in forbidden.items():
            if needle.lower() in text.lower():
                fail(f"{path.relative_to(ROOT)} contains stale claim {needle!r}: {reason}")
    shell_root = ROOT / "shell"
    if (shell_root / ".config" / "zsh").exists() is False:
        fail("Root shell/ no longer looks like terminal shell config")
    if not (APPS / "shell" / "lumina-shell.py").exists():
        fail("Desktop shell is not under apps/shell")


def validate_app_core_usage() -> None:
    for path in sorted(APPS.rglob("*.py")):
        if CORE in path.parents:
            continue
        if path.name == "__init__.py":
            continue
        text = path.read_text(encoding="utf-8")
        if "lumina_core" not in text:
            fail(f"Lumina app bypasses lumina_core: {path.relative_to(ROOT)}")


def validate_no_unused_app_modules() -> None:
    graph = import_graph()
    imported = {child for children in graph.values() for child in children}
    entrypoints = {
        module_name(path)
        for path in APPS.rglob("lumina-*.py")
    }
    ignored = {
        "lumina_core",
        "components",
        "adapters",
        "shell.adapters",
        "shell.components",
    }
    for name in sorted(graph):
        if name in ignored or name in entrypoints:
            continue
        if name not in imported:
            fail(f"Unused Lumina Python module: {name}")


def main() -> int:
    validate_no_cycles()
    validate_packages()
    validate_services()
    validate_links()
    validate_architecture_claims()
    validate_app_core_usage()
    validate_no_unused_app_modules()
    print("Lumina architecture validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
