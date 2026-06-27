# Future roadmap

## Completed in V6

- ✅ Custom symlink engine (replaced the old external symlink dependency)
- ✅ Generic host profile for non-LOQ machines
- ✅ GTK/fontconfig config backup before overwrites
- ✅ Unified theme pipeline (single Matugen `-c` config flag across all callers)
- ✅ Correct systemd service names across install/uninstall
- ✅ Legacy script consolidation (legacy wrappers delegate to new pipeline)
- ✅ Lumina Core, Lumina Shell MVP, core utilities, product apps, optional AI, and Phase 6 supplementary modes
- ✅ Presentation Mode, Focus Mode, Idle Inhibitor, Media Overlay, Workspace Templates, Random Wallpaper, Scratch Notes, Scratchpad Terminal, Color Picker, Pomodoro, and Cleanup Manager
- ✅ Website and docs synchronized to implemented behavior

## Planned

- Optional NVIDIA offload profile with tested suspend and external-display guidance
- Theme presets layered on top of Matugen for lighter and darker visual personalities
- Optional `chezmoi` export path for multi-machine portability
- Deeper storage telemetry beyond the existing firmware, SMART, and battery-health doctor checks
- Lightweight benchmark script for boot, launcher, and panel startup timing
- Multi-host support: auto-detect hardware and select the right profile without `--host`
- Wallpaper gallery integration with Waypaper for faster visual selection
