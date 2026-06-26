# Problems in the old setup

The old bundle was a meaningful step forward, but it still had the shape of a stitched setup rather than a finished system.

## What was missing

- The theming model stopped halfway.
  `hyprlock.conf` was still hardcoded, while Hyprland, Ghostty, and Btop were partly dynamic.
- Several core UX components were placeholders.
  `hyprpanel`, `walker`, and `wlogout` existed as directories without finished runtime configs.
- The installer did too much in one pile.
  Storage logic, service logic, session logic, and dotfile linking were all present, but not separated into clear lifecycle steps.
- Recovery existed mostly as notes.
  There were snapshots and a minimal Hyprland file, but not a complete story covering boot, rollback, fallback launch, and doctor checks.
- LOQ-specific GPU strategy was reactive.
  The "use integrated mode" guidance was present, but it felt like a workaround after the fact rather than the intended stable baseline.
- Documentation was good for a config repo, not yet good for a product.
  You had guides, but no interactive docs surface and no single source of truth tying comparison, install, maintenance, and migration together.

## Concrete pain points from the audit

- The old `README.md` had two separate "After First Boot" sections with conflicting emphasis.
- `hyprlock.conf` explicitly documented that it was not updated by Matugen.
- `hyprpanel/.config/hyprpanel/.gitkeep` and `walker/.config/walker/.gitkeep` showed the product surface was not actually complete.
- The setup flow leaned on retry/skip prompts to survive failure, which is useful, but still meant too many failure modes were being discovered late.
- UWSM was present, but session orchestration still relied heavily on compositor-side process spawning.

## What is achievable to improve

- Move theme generation into a clean source-and-generated split.
- Make HyprPanel a real configured product layer instead of a placeholder directory.
- Use systemd user units for session daemons that benefit from ordering and restart policy.
- Promote LOQ hardware policy to first-class documentation and install behavior.
- Replace "a lot of markdown" with "a coherent docs system plus a website."

