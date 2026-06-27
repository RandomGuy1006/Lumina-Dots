# Changelog

## Unreleased

### Added
- Restored the static product website with real desktop screenshots, embedded repository documentation, and an interactive session preview.
- Added a deterministic website data builder and static quality gate for version, package, keybinding, documentation, link, and asset consistency.

### Changed
- Updated website recovery, filesystem, GPU, installation, and Quickshell-readiness claims to match the current release contracts.

## V6.2.0 - 2026-06-05

### Added
- Completed Phase 6 supplementary modes and utilities: Presentation Mode, Focus Mode, Idle Inhibitor, Media Overlay, Workspace Templates, Random Wallpaper, Scratch Notes, Scratchpad Terminal, Color Picker, Pomodoro, and Cleanup Manager.
- Added first-class scripts and docs for Scratch Notes, Scratchpad Terminal, Media Overlay, and Color Picker.
- Added Phase 6 validation coverage for scripts, docs, and keybind wiring.

### Fixed
- Replaced inline Phase 6 keybind commands with maintainable script entrypoints.
- Corrected keybinding docs for Scratch Notes, Neovim, Idle Inhibitor, pinning, previous workspace, and scratchpad terminal.
- Updated README, component matrix, and website keybinding claims to match implemented behavior.

## V6.1.0 - 2026-05-27

### Added
- GitHub Actions CI for shell syntax, shellcheck, shfmt, package hygiene, and docs validation.
- Matugen templates for Yazi, Starship, and Neovim palette export.
- Gaming mode toggle, keybind popup, monitor auto-detect, avatar setup, screenshot capture, status, seed, and recovery helpers.
- Expanded doctor checks for battery health, SMART, firmware, shell tools, and portal sanity.
- Canonical LOQ host drop-ins under `hosts/loq-15irx9/`.

### Fixed
- Updated package manifests for current Arch/AUR package names.
- Standardized wallpaper daemon flows on the canonical `swww` runtime API, with current-Arch compatibility wrappers when the provider package ships `awww` binaries.
- Prevented generated theme outputs and GTK settings from being symlinked back into the repo.
- Kept Matugen-generated Starship and Yazi theme outputs local so theme changes cannot overwrite tracked source files.
- Added OCR region capture (`Super + Shift + O`) with optional custom pipeline or Ollama cleanup/summarization before clipboard output.
- Added strict Btrfs/Snapper safety gates before bulk system/package changes and GRUB snapshot boot integration through grub-btrfs when available.
- Unified legacy update and backup entrypoints behind canonical flows.
- Made `dotfiles test` match `install.sh test`.

## V6.0.0 - 2026-05-27

### Added
- Custom `lib/link.sh` symlink engine replacing the old external symlink dependency.
- Generic host fallback for non-LOQ hardware.
- GTK config backup before overwrites.
- Legacy script redirects to canonical pipeline.

### Fixed
- Systemd uninstaller correctly targets `loq-*` services.
- `validate-repo.sh` grep patterns corrected.

### Breaking
- `setup all` still works as an alias; prefer `bash install.sh install`.
