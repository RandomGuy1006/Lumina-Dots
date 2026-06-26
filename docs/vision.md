# Master vision

The target is not "nice Hyprland config files." The target is a laptop operating environment that feels premium, stays understandable, and survives updates without turning into a side project.

## Philosophy

- Visual polish is a systems problem, not only a CSS problem.
  Motion, color, spacing, sound, and session behavior need to agree with each other.
- Reliability comes from reducing hidden state.
  Generated theme data is isolated, host-specific tuning is explicit, and startup daemons are managed through systemd user units instead of ad-hoc sleep loops.
- Recovery is part of the design.
  Timeshift on ext4 or Snapper on Btrfs, linux-lts, a doctor command, and a fallback Hyprland config are part of the mainline flow.
- Hardware specificity matters.
  The LOQ 15IRX9 gets deep sleep defaults, Intel-first tuning, thermal guidance, and a lid-close policy designed around actual laptop use.
- Maintainability beats novelty.
  Lumina Shell owns first-party OSD, mode, and popup behavior while HyprPanel remains the stable fallback. Quickshell is not a production dependency; backend-neutral contracts keep a later frontend migration possible without coupling system behavior to a UI toolkit.

## What "better than Omarchy and illogical-impulse" means here

- Better than Omarchy means more host specificity, a cleaner generated-theme model, and less black-box behavior.
- Better than illogical-impulse means richer visuals than a bare utilitarian stack without inheriting AGS-era fragility or a giant config surface.
- Better than both means the repo behaves like a product when you install it, but like a sane codebase when you maintain it.

## Design stance

- Premium, glassy, restrained, dark-first visual language
- Fast workspace and window motion with overshoot, not rubbery chaos
- Discoverable controls through one coherent panel and launcher
- Intel-first LOQ baseline for battery, sleep, and Wayland stability
- Optional NVIDIA offload documented as an add-on, not forced into the default daily driver
