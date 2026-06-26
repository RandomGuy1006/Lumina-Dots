"""Source-owned Lumina Search index used by the public D-Bus contract."""

from __future__ import annotations

import configparser
import os
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class SearchResult:
    id: str
    title: str
    description: str
    kind: str
    command: str

    def as_dbus_row(self) -> tuple[str, str, str, str, str]:
        return (self.id, self.title, self.description, self.kind, self.command)


SETTINGS_RESULTS = (
    SearchResult("settings:glass", "Glass Mode", "Adjust blur and opacity", "settings", "lumina-settings-studio --page=appearance --section=glass-mode"),
    SearchResult("settings:theme", "Theme", "Apply palette and color tokens", "settings", "lumina-settings-studio --page=appearance"),
    SearchResult("settings:wallpaper", "Wallpaper", "Choose wallpaper and transitions", "settings", "lumina-settings-studio --page=wallpaper"),
    SearchResult("settings:mood", "Mood", "Apply coordinated mood profiles", "settings", "lumina-settings-studio --page=mood"),
)


def _desktop_dirs() -> list[Path]:
    dirs = [Path.home() / ".local/share/applications"]
    data_dirs = os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share")
    dirs.extend(Path(item) / "applications" for item in data_dirs.split(":") if item)
    repo_apps = Path(__file__).resolve().parents[3] / "applications"
    if repo_apps.exists():
        dirs.insert(0, repo_apps)
    return dirs


def _desktop_results() -> list[SearchResult]:
    results: list[SearchResult] = []
    seen: set[str] = set()
    for directory in _desktop_dirs():
        for entry in sorted(directory.glob("*.desktop")):
            if entry.name in seen:
                continue
            parser = configparser.ConfigParser(interpolation=None)
            parser.optionxform = str
            try:
                parser.read(entry, encoding="utf-8")
                desktop = parser["Desktop Entry"]
            except (OSError, KeyError, configparser.Error):
                continue
            if desktop.get("NoDisplay", "").lower() == "true":
                continue
            title = desktop.get("Name", "").strip()
            command = desktop.get("Exec", "").strip()
            if not title or not command:
                continue
            seen.add(entry.name)
            description = desktop.get("Comment", desktop.get("GenericName", "")).strip()
            results.append(SearchResult(f"desktop:{entry.stem}", title, description, "application", command))
    return results


def _score(result: SearchResult, query: str) -> int:
    haystack = " ".join((result.title, result.description, result.kind, result.command)).lower()
    needle = query.lower().strip()
    if not needle:
        return 0
    if result.title.lower() == needle:
        return 100
    if result.title.lower().startswith(needle):
        return 80
    if needle in result.title.lower():
        return 60
    if needle in haystack:
        return 30
    return 0


def query_search(query: str, limit: int = 8) -> list[SearchResult]:
    if not query.strip():
        return []
    candidates = [*SETTINGS_RESULTS, *_desktop_results()]
    ranked = [(score, index, result) for index, result in enumerate(candidates) if (score := _score(result, query)) > 0]
    ranked.sort(key=lambda item: (-item[0], item[1]))
    return [result for _score_value, _index, result in ranked[:limit]]


def search_results(query: str, limit: int = 8) -> list[tuple[str, str, str, str, str]]:
    return [result.as_dbus_row() for result in query_search(query, limit)]
