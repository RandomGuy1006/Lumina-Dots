# Migration guide from the old setup

## Goal

Move from the previous bundle to this repo without carrying forward the accidental complexity.

## Keep

- your wallpapers
- your package expectations
- your Intel-first LOQ strategy
- your preference for Hyprland-native tools

## Replace

- placeholder HyprPanel, Walker, and Wlogout state
- mixed tracked/generated theme files
- ad-hoc session startup patterns
- hand-applied recovery notes

## Recommended migration steps

1. Back up the old repo and export a package list.
2. Copy wallpapers into `~/Pictures/Wallpapers`.
3. Clone this repo into `~/lumina-dots`.
4. Run:

```bash
bash install.sh backup pre-migration
bash install.sh install --host=loq-15irx9
```

5. On first boot into the new session, validate with:

```bash
bash install.sh doctor --host=loq-15irx9
```

## Manual settings to review

- Browser defaults
- Walker web search engine choice
- HyprPanel weather location if you use it
- Any language-specific LazyVim plugins you want beyond the provided bootstrap
