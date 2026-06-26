# Verification and Release Evidence

## Profiles

- `static`: repository, documentation, architecture, compilation, and lint policy.
- `unit`: Lumina domain and application behavior.
- `integration`: links, services, themes, hardware guards, and regressions.
- `recovery`: filesystem-aware backup manifests and rollback safety contracts.
- `visual`: token schema, spacing grid, focus, popup, and generated-surface coverage.
- `runtime`: checks a real installed Arch + Hyprland session.
- `all`: all host-independent profiles. `release` adds runtime validation.

Use `python3 scripts/quality.py <profile> --json` to produce machine-readable evidence with check IDs, durations, exit codes, output, and remediation. Add `--output ~/.local/state/lumina/release/evidence.json` to persist the bundle with platform and Python metadata.

## Release Matrix

A release candidate requires:

1. `all` passing in CI.
2. Clean install, update, relink, and uninstall in disposable Arch VMs.
3. Btrfs/Snapper and ext4/Timeshift backup drills.
4. Offline Btrfs rollback in a disposable VM.
5. LOQ checks for suspend/resume, battery, brightness, audio, portals, locking, wallpaper, and panel stability.
6. Visual review at 1x, 1.25x, 1.5x, and 2x scaling.
7. A 24-hour daily-driver soak with service restart and sleep-cycle evidence.

Candidate screenshots can be compared with `python3 tests/compare-visuals.py <candidate-directory> --threshold 0.025`. Baseline replacement requires an intentional visual review and an updated baseline manifest.

Hardware-only checks cannot be certified by cross-platform CI and must be attached to the release evidence bundle.
