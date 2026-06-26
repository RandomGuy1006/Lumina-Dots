#!/usr/bin/env bash
# scripts/install/04-theme.sh — Initial theme setup
# Applies fallback theme and prepares Matugen pipeline
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "${DOTFILES_DIR}/lib/log.sh"

log::header "Step 4: Theme Initialization"

# ─── GTK theme ────────────────────────────────────────────────────────────────
log::section "Applying GTK theme (adw-gtk-theme)"
mkdir -p "${HOME}/.config/gtk-3.0" "${HOME}/.config/gtk-4.0"

ensure_local_file() {
  local file="$1"
  if [[ -L "${file}" ]]; then
    rm -f "${file}"
  fi
}

# Back up existing GTK settings before overwriting
for gtk_dir in gtk-3.0 gtk-4.0; do
  if [[ -f "${HOME}/.config/${gtk_dir}/settings.ini" ]] && [[ ! -L "${HOME}/.config/${gtk_dir}/settings.ini" ]]; then
    cp "${HOME}/.config/${gtk_dir}/settings.ini" "${HOME}/.config/${gtk_dir}/settings.ini.lumina-bak-$(date +%Y%m%d%H%M%S)"
    log::dim "Backed up existing ${gtk_dir}/settings.ini"
  fi
  ensure_local_file "${HOME}/.config/${gtk_dir}/settings.ini"
done

# gtk-3.0 settings
cat >"${HOME}/.config/gtk-3.0/settings.ini" <<'GTK3_EOF'
[Settings]
gtk-theme-name=adw-gtk3-dark
gtk-icon-theme-name=Papirus-Dark
gtk-cursor-theme-name=Bibata-Modern-Ice
gtk-cursor-theme-size=24
gtk-font-name=Inter 11
gtk-application-prefer-dark-theme=1
gtk-button-images=0
gtk-menu-images=0
gtk-toolbar-style=GTK_TOOLBAR_BOTH_HORIZ
GTK3_EOF
log::success "GTK3 settings applied"

# gtk-4.0 settings
cat >"${HOME}/.config/gtk-4.0/settings.ini" <<'GTK4_EOF'
[Settings]
gtk-theme-name=adw-gtk3-dark
gtk-icon-theme-name=Papirus-Dark
gtk-cursor-theme-name=Bibata-Modern-Ice
gtk-cursor-theme-size=24
gtk-font-name=Inter 11
gtk-application-prefer-dark-theme=1
GTK4_EOF
log::success "GTK4 settings applied"

# ─── Cursor theme ─────────────────────────────────────────────────────────────
log::section "Setting cursor theme"
mkdir -p "${HOME}/.icons/default"
cat >"${HOME}/.icons/default/index.theme" <<'CURSOR_EOF'
[Icon Theme]
Inherits=Bibata-Modern-Ice
CURSOR_EOF
log::success "Cursor theme set to Bibata-Modern-Ice"

# Set via gsettings if dbus is available
if command -v gsettings &>/dev/null; then
  gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Ice' 2>/dev/null || true
  gsettings set org.gnome.desktop.interface cursor-size 24 2>/dev/null || true
  gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark' 2>/dev/null || true
  gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark' 2>/dev/null || true
  gsettings set org.gnome.desktop.interface font-name 'Inter 11' 2>/dev/null || true
  gsettings set org.gnome.desktop.interface monospace-font-name 'JetBrainsMono Nerd Font 11' 2>/dev/null || true
  log::success "gsettings applied"
fi

# ─── Fontconfig ───────────────────────────────────────────────────────────────
log::section "Fontconfig setup"
mkdir -p "${HOME}/.config/fontconfig"
if [[ -f "${HOME}/.config/fontconfig/fonts.conf" ]] && [[ ! -L "${HOME}/.config/fontconfig/fonts.conf" ]]; then
  cp "${HOME}/.config/fontconfig/fonts.conf" "${HOME}/.config/fontconfig/fonts.conf.lumina-bak-$(date +%Y%m%d%H%M%S)"
  log::dim "Backed up existing fontconfig/fonts.conf"
fi
cat >"${HOME}/.config/fontconfig/fonts.conf" <<'FONTS_EOF'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <!-- Prefer Inter for UI text -->
  <alias>
    <family>sans-serif</family>
    <prefer>
      <family>Inter</family>
      <family>Noto Sans</family>
    </prefer>
  </alias>

  <!-- Prefer JetBrains Mono for monospace -->
  <alias>
    <family>monospace</family>
    <prefer>
      <family>JetBrainsMono Nerd Font</family>
      <family>Noto Sans Mono</family>
    </prefer>
  </alias>

  <!-- Emoji -->
  <alias>
    <family>emoji</family>
    <prefer>
      <family>Noto Color Emoji</family>
    </prefer>
  </alias>

  <!-- Enable antialiasing and hinting -->
  <match target="font">
    <edit name="antialias" mode="assign"><bool>true</bool></edit>
    <edit name="hinting" mode="assign"><bool>true</bool></edit>
    <edit name="hintstyle" mode="assign"><const>hintslight</const></edit>
    <edit name="rgba" mode="assign"><const>rgb</const></edit>
    <edit name="lcdfilter" mode="assign"><const>lcddefault</const></edit>
  </match>
</fontconfig>
FONTS_EOF
fc-cache -fv &>/dev/null
log::success "Fontconfig configured"

# ─── Apply initial Matugen theme from fallback wallpaper ─────────────────────
log::section "Applying initial color theme"
FALLBACK_WALLPAPER="${DOTFILES_DIR}/themes/defaults/wallpaper.jpg"

if [[ -f "${FALLBACK_WALLPAPER}" ]]; then
  mkdir -p "${HOME}/.cache/matugen"
  cp "${FALLBACK_WALLPAPER}" "${HOME}/.cache/matugen/wallpaper-cache" 2>/dev/null || true
  log::success "Seeded Hyprlock wallpaper cache"
fi

if [[ -f "${FALLBACK_WALLPAPER}" ]]; then
  PYTHONPATH="${DOTFILES_DIR}/apps/lib${PYTHONPATH:+:${PYTHONPATH}}"
  export PYTHONPATH
  if command -v lumina-theme >/dev/null 2>&1; then
    lumina-theme apply --wallpaper="${FALLBACK_WALLPAPER}" &&
      log::success "Initial Lumina theme applied" ||
      log::warn "Lumina theme failed — fallback colors will be used"
  else
    "${DOTFILES_DIR}/local-bin/.local/bin/lumina-theme" apply --wallpaper="${FALLBACK_WALLPAPER}" &&
      log::success "Initial Lumina theme applied" ||
      log::warn "Lumina theme failed — fallback colors will be used"
  fi
else
  log::warn "No fallback wallpaper available — skipping initial theme"
  log::info "Apply theme later with: dotfiles theme <wallpaper.jpg>"
fi

# ─── Create wallpapers directory ──────────────────────────────────────────────
mkdir -p "${HOME}/Pictures/Wallpapers"
if [[ -f "${FALLBACK_WALLPAPER}" ]]; then
  cp "${FALLBACK_WALLPAPER}" "${HOME}/Pictures/Wallpapers/lumina-default.jpg" 2>/dev/null || true
fi

log::success "Theme initialization complete"
