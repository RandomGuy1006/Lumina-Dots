# Random Wallpaper

Random Wallpaper is triggered with `Super + Shift + W` and uses `scripts/theme/random-wallpaper.sh`.

It selects an image from `${WALLPAPER_DIR:-$HOME/Pictures/Wallpapers}`, avoids the current wallpaper when possible, and applies it through `dotfiles theme`. Waypaper moved to `Super + Alt + W`.
