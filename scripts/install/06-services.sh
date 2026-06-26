#!/usr/bin/env bash
# scripts/install/06-services.sh — Systemd user service setup
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "${DOTFILES_DIR}/lib/log.sh"
source "${DOTFILES_DIR}/lib/common.sh"

log::header "Step 6: Systemd Services"

user_bus_available() {
  [[ -n "${XDG_RUNTIME_DIR:-}" && -S "${XDG_RUNTIME_DIR}/bus" ]] && systemctl --user show-environment >/dev/null 2>&1
}

# ─── Reload systemd user daemon ───────────────────────────────────────────────
log::section "Reloading systemd user daemon"
if user_bus_available; then
  systemctl --user daemon-reload
  log::success "User daemon reloaded"
else
  log::warn "No user systemd bus yet; user units will load when UWSM starts Hyprland"
fi

# ─── Enable Pipewire audio services ──────────────────────────────────────────
log::section "Pipewire audio"
if user_bus_available; then
  systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service &&
    log::success "Pipewire + WirePlumber enabled" ||
    log::warn "Pipewire services failed — may already be running"
else
  log::warn "Skipping Pipewire user enable until first graphical login"
fi

# ─── Disable conflicting notification daemons ─────────────────────────────────
log::section "Disabling conflicting daemons"
for daemon in dunst mako xfce4-notifyd notification-daemon; do
  if user_bus_available && systemctl --user is-enabled "${daemon}" &>/dev/null; then
    systemctl --user disable --now "${daemon}" 2>/dev/null || true
    log::warn "Disabled conflicting daemon: ${daemon}"
  fi
done
log::success "No conflicting notification daemons running"

log::section "Lumina user units"
maybe_enable_user_unit lumina-shell.service
maybe_enable_user_unit lumina-welcome.service
maybe_enable_user_unit lumina-core.service
maybe_enable_user_unit lumina-control-center.service
maybe_enable_user_unit lumina-keybind-overlay.service

# ─── XDG portals ──────────────────────────────────────────────────────────────
log::section "XDG Desktop Portals"
# Ensure correct portal environment for Hyprland
# Portal selection is handled by HYPRLAND_INSTANCE_SIGNATURE env var

# Create xdg-portal configuration directory
mkdir -p "${HOME}/.config/xdg-desktop-portal"
portal_config="${HOME}/.config/xdg-desktop-portal/hyprland-portals.conf"
if [[ -f "${portal_config}" && "${LUMINA_PORTAL_OVERWRITE:-1}" == "0" ]]; then
  log::warn "Keeping existing XDG portal config because LUMINA_PORTAL_OVERWRITE=0"
elif [[ -f "${portal_config}" && "${LUMINA_PORTAL_BACKUP:-0}" == "1" ]]; then
  cp "${portal_config}" "${portal_config}.lumina-bak-$(date +%Y%m%d%H%M%S)"
  log::warn "Backed up existing XDG portal config before overwrite"
fi

if [[ ! -f "${portal_config}" || "${LUMINA_PORTAL_OVERWRITE:-1}" != "0" ]]; then
  cat >"${portal_config}" <<'PORTAL_EOF'
[preferred]
default=hyprland;gtk
org.freedesktop.impl.portal.FileChooser=gtk
org.freedesktop.impl.portal.AppChooser=gtk
org.freedesktop.impl.portal.Print=gtk
org.freedesktop.impl.portal.Notification=gtk
org.freedesktop.impl.portal.Inhibit=gtk
org.freedesktop.impl.portal.ScreenCast=hyprland
org.freedesktop.impl.portal.Screenshot=hyprland
org.freedesktop.impl.portal.RemoteDesktop=hyprland
PORTAL_EOF
  log::success "XDG portal config written"
fi

# ─── Auto-login on TTY1 ───────────────────────────────────────────────────────
log::section "TTY1 autologin setup"
bash "${DOTFILES_DIR}/scripts/configure-autologin.sh"

# ─── Snap-pac hooks (automatic Btrfs snapshots on pacman) ─────────────────────
log::section "snap-pac pacman hooks"
if pacman -Qi snap-pac &>/dev/null; then
  log::success "snap-pac installed — automatic pre/post snapshots active"
else
  log::warn "snap-pac not installed — install it for automatic Btrfs snapshots"
fi

log::section "Gaming mode sudoers"
if getent group wheel >/dev/null 2>&1; then
  sudo tee /etc/sudoers.d/lumina-gaming >/dev/null <<'SUDOERS_EOF'
%wheel ALL=(ALL) NOPASSWD: /usr/bin/tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
SUDOERS_EOF
  sudo chmod 0440 /etc/sudoers.d/lumina-gaming
  sudo visudo -cf /etc/sudoers.d/lumina-gaming >/dev/null
  log::success "Gaming mode sudoers rule installed"
fi

log::section "Notification sounds"
if pacman -Qi sound-theme-freedesktop &>/dev/null; then
  log::success "Sound theme installed"
else
  sudo pacman -S --needed --noconfirm sound-theme-freedesktop &&
    log::success "Sound theme installed" ||
    log::warn "Sound theme installation failed"
fi

log::success "Services configuration complete"
