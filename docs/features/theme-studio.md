# Lumina Theme Studio

Theme Studio is the Phase 4 product app for wallpaper and palette workflows.

- App: `apps/theme-studio/lumina-theme-studio.py`
- CLI: `lumina-theme-studio`
- Dotfiles command: `dotfiles theme-studio`
- Apply path: `dotfiles theme <wallpaper>`

Theme Studio lists wallpapers from `~/Pictures/Wallpapers`, previews the active Lumina token palette, and applies wallpapers through the existing theme pipeline. It does not write generated Hyprland, Walker, HyprPanel, GTK, or terminal theme files directly.

If applying a wallpaper fails, the current theme remains active and the captured command result is surfaced through the Universal Popup Framework.
