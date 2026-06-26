# Why this new stack wins

## Summary

This stack keeps your chosen core components and optimizes around them instead of replacing them with trendier pieces that would increase maintenance cost.

## Final architecture

- Compositor and session: Hyprland + UWSM
- Login path: getty autologin on `tty1` -> `.zprofile` launches `uwsm start hyprland.desktop` -> Hyprlock runs at session start
- Filesystem and rollback: Btrfs subvolumes + Snapper + snap-pac + linux-lts
- Desktop shell layer: Lumina Shell for first-party OSD, modes, and popups, with HyprPanel retained as the stable bar/widget/notification fallback
- Launcher: Walker with a custom glass theme
- Theme engine: Matugen driving generated outputs for Hyprland, Hyprlock, Ghostty, Walker, Btop, HyprPanel, and Wlogout
- Runtime daemons: systemd user units for `hyprpanel`, `hypridle`, `swww`, and `cliphist`
- Hardware profile: Intel-first Lenovo LOQ 15IRX9 baseline with deep sleep and conservative display tuning

## Why this is better than the common alternatives

- Omarchy is excellent at feeling like a product, but it is still more opaque and less host-specific than this repo.
- illogical-impulse earned its reputation with visual ambition, but that style of setup has historically carried more state, more moving parts, and more maintenance pressure.
- ML4W and JaKooLit are strong on breadth and onboarding, but they tend to feel more like curated kit collections than one coherent operating environment.
- end-4 demonstrates how far visual ambition can go, but it also shows why your "no Quickshell unless necessary" rule is a good one for a daily driver.

## Why each fixed component is still the right choice

- Hyprland: best blend of Wayland-native power, motion, and ecosystem depth for your priorities.
- UWSM: the cleanest current answer for session lifecycle and environment hygiene.
- Lumina Shell plus HyprPanel fallback: Lumina-owned feedback surfaces without giving up the proven bar, widget, notification, and fallback path.
- Walker: smoother and cleaner than the usual dmenu-style launchers once themed properly.
- Matugen: the best low-maintenance path to adaptive theming without falling into a custom shell framework.
- Ghostty: polished daily terminal with excellent typography and low config overhead.
- LazyVim: strong default editor platform with less maintenance cost than a hand-rolled Neovim distro.
