#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

missing_pipefail=0
shell_files() {
  find lib scripts tests -type f -name '*.sh'

  while IFS= read -r file; do
    if head -n1 "$file" | grep -Eq '^#!.*\b(sh|bash)\b'; then
      printf '%s\n' "$file"
    fi
  done < <(find local-bin -type f)
}

while IFS= read -r file; do
  if ! grep -q 'set -euo pipefail' "$file"; then
    printf 'Missing strict mode: %s\n' "$file"
    missing_pipefail=1
  fi
done < <(shell_files | sort -u)

home_prefix="/"home/
while IFS= read -r file; do
  if grep -n "$home_prefix" "$file" >/dev/null; then
    printf 'Found hardcoded /home path in %s\n' "$file"
    exit 1
  fi
done < <(shell_files | sort -u)

if [[ -f "$ROOT/hypr/.config/hypr/colors.conf" || -f "$ROOT/hypr/.config/hypr/hyprlock-colors.conf" ]]; then
  printf 'Found generated Hypr theme files inside the managed config tree\n'
  exit 1
fi

if grep -R -n -- 'snapper -c root rollback' README.md docs scripts website >/dev/null 2>&1; then
  printf 'Found unsupported snapper rollback usage for the @ layout\n'
  exit 1
fi

if ! grep -q "printf.*refind" "$ROOT/lib/common.sh"; then
  printf 'Missing rEFInd bootloader detection\n'
  exit 1
fi

if ! grep -q '\-o login' "$ROOT/shell/.zprofile"; then
  printf 'Missing login-shell guard in .zprofile\n'
  exit 1
fi

if grep -q '\-o interactive' "$ROOT/shell/.zprofile"; then
  printf 'Unexpected interactive-shell guard in .zprofile\n'
  exit 1
fi

if grep -q 'uwsm check may-start' "$ROOT/shell/.zprofile"; then
  printf 'Incompatible uwsm check may-start found in .zprofile\n'
  exit 1
fi

if grep -q -- '--format xrgb' "$ROOT/systemd/.config/systemd/user/loq-swww.service"; then
  printf 'Found hardcoded wallpaper daemon pixel format\n'
  exit 1
fi

if grep -R -n -- 'windowrulev2[[:space:]]*=' "$ROOT/hypr/.config/hypr" >/dev/null 2>&1; then
  printf 'Found deprecated Hyprland windowrulev2 syntax\n'
  exit 1
fi

if grep -q '^BindsTo=graphical-session.target' "$ROOT/systemd/.config/systemd/user/loq-session.target"; then
  printf 'loq-session.target must not bind to graphical-session.target\n'
  exit 1
fi

if grep -Eq '^(PartOf|WantedBy)=loq-session.target' "$ROOT/systemd/.config/systemd/user/loq-hyprlock-boot.service"; then
  printf 'loq-hyprlock-boot.service must be started only by exec.conf\n'
  exit 1
fi

if grep -qx 'ttf-inter' "$ROOT/packages/aur.txt"; then
  printf 'AUR package ttf-inter is invalid; use inter-font\n'
  exit 1
fi

for manifest in \
  packages/pacman-base.txt \
  packages/pacman-desktop.txt \
  packages/pacman-media.txt \
  packages/pacman-dev.txt \
  packages/pacman-loq.txt \
  packages/aur.txt \
  packages/optional-nvidia.txt \
  packages/optional-nvidia-aur.txt; do
  [[ -f "$ROOT/$manifest" ]] || {
    printf 'Missing package manifest: %s\n' "$manifest"
    exit 1
  }
done

for required in \
  .github/workflows/ci.yml \
  .github/workflows/docs.yml \
  .shellcheckrc \
  CHANGELOG.md \
  hosts/generic/profile.sh \
  scripts/validate.sh \
  scripts/status.sh \
  scripts/seed.sh \
  scripts/system/gaming-mode.sh \
  scripts/system/keybinds-popup.sh \
  scripts/system/monitor-detect.sh \
  scripts/system/setup-avatar.sh \
  scripts/system/presentation-mode.sh \
  scripts/system/focus-mode.sh \
  scripts/system/idle-inhibit.sh \
  scripts/system/media-overlay.sh \
  scripts/system/session-health.sh \
  scripts/system/workspace-template.sh \
  scripts/system/scratch-notes.sh \
  scripts/system/scratchpad-terminal.sh \
  scripts/system/color-picker.sh \
  scripts/theme/random-wallpaper.sh \
  apps/lib/lumina_core/__init__.py \
  apps/shell/lumina-shell.py \
  apps/welcome/lumina-welcome.py \
  apps/keybind-overlay/lumina-keybind-overlay.py \
  apps/control-center/lumina-control-center.py \
  apps/doctor-dashboard/lumina-doctor-dashboard.py \
  apps/snapshot-manager/lumina-snapshot-manager.py \
  apps/activity-history/lumina-activity-history.py \
  apps/theme-studio/lumina-theme-studio.py \
  apps/lumina-hub/lumina-hub.py \
  apps/mission-control/lumina-mission-control.py \
  apps/lumina-ai/lumina-ai.py \
  apps/pomodoro/lumina-pomodoro.py \
  apps/cleanup-manager/lumina-cleanup-manager.py \
  lumina/.config/lumina/shell.toml \
  lumina/.config/lumina/ai.toml \
  lumina/.config/lumina/workspace-templates/dev.toml \
  lumina/.config/lumina/workspace-templates/media.toml \
  systemd/.config/systemd/user/lumina-shell.service \
  systemd/.config/systemd/user/lumina-welcome.service \
  tests/validate-lumina-core.py \
  tests/validate-lumina-architecture.py \
  tests/test-lumina-phase2.py \
  tests/test-lumina-phase3.py \
  tests/test-lumina-phase4.py \
  tests/test-lumina-phase5.py \
  tests/test-lumina-phase6.py; do
  [[ -f "$ROOT/$required" ]] || {
    printf 'Missing required project surface: %s\n' "$required"
    exit 1
  }
  done

if ! python3 tests/validate-lumina-core.py; then
  printf 'Lumina Core validation failed\n'
  exit 1
fi

if grep -R -n -- 'packages/\(base\|hypr\|theme\|fonts\|apps\|hardware-loq\)\.txt' install.sh scripts lib >/dev/null 2>&1; then
  printf 'Found stale package manifest reference\n'
  exit 1
fi

if grep -R -n -- 'hyprpanel-bin' README.md docs scripts packages >/dev/null 2>&1; then
  printf 'Found stale Hyprpanel package name; use ags-hyprpanel-git\n'
  exit 1
fi

if grep -qx 'stow' "$ROOT/packages/pacman-base.txt"; then
  printf 'GNU Stow dependency returned to pacman-base.txt\n'
  exit 1
fi

if ! grep -qx 'awww' "$ROOT/packages/pacman-media.txt"; then
  printf 'Missing Arch wallpaper provider package awww in pacman-media.txt\n'
  exit 1
fi

if grep -R -n --exclude='install-swww-compat.sh' --exclude='validate-repo.sh' -- 'command -v awww\|awww-daemon\|AWWW_PIXEL_FORMAT' hypr scripts systemd hosts lib tests README.md docs >/dev/null 2>&1; then
  printf 'Found non-canonical awww runtime references\n'
  exit 1
fi

if ! grep -q 'install-swww-compat.sh' "$ROOT/scripts/install/02-packages.sh"; then
  printf 'Missing current-Arch swww compatibility wrapper install\n'
  exit 1
fi

if grep -qx 'adw-gtk3' "$ROOT/packages/aur.txt"; then
  printf 'AUR package adw-gtk3 is stale; use adw-gtk-theme\n'
  exit 1
fi

if grep -qx 'adw-gtk-theme' "$ROOT/packages/aur.txt"; then
  printf 'adw-gtk-theme belongs in pacman manifests, not aur.txt\n'
  exit 1
fi

if grep -qx 'inter-font' "$ROOT/packages/aur.txt"; then
  printf 'inter-font belongs in pacman manifests, not aur.txt\n'
  exit 1
fi

if ! grep -qx 'glow' "$ROOT/packages/pacman-desktop.txt"; then
  printf 'Missing glow package for keybind popup\n'
  exit 1
fi

if [[ -d "$ROOT/hosts/loq15irx9" ]] && find "$ROOT/hosts/loq15irx9" -type f | grep -q .; then
  printf 'Found stale split LOQ host files under hosts/loq15irx9\n'
  exit 1
fi

for generated in \
  ghostty/.config/ghostty/themes/LoqDynamic \
  ghostty/.config/ghostty/lumina-tokens.conf \
  btop/.config/btop/themes/loq.theme \
  hypr/.config/hypr/tokens.conf \
  walker/.config/walker/themes/generated.css \
  hyprpanel/.config/hyprpanel/theme.generated.json \
  wlogout/.config/wlogout/colors.css; do
  if [[ -e "$ROOT/$generated" ]]; then
    printf 'Generated theme output is tracked in config tree: %s\n' "$generated"
    exit 1
  fi
done

if grep -q 'shell/.config/starship.toml|.*\.config/starship.toml' "$ROOT/lib/link.sh"; then
  printf 'starship.toml must remain a local generated runtime file, not a repo symlink\n'
  exit 1
fi

if ! grep -q 'modules/yazi:theme.toml' "$ROOT/lib/link.sh"; then
  printf 'Yazi theme output must be skipped by the symlink tree\n'
  exit 1
fi

if [[ ! -f "$ROOT/matugen/.config/matugen/templates/visual-tokens.json" ]]; then
  printf 'Missing centralized Matugen visual token template\n'
  exit 1
fi

if ! grep -q 'render-visual-tokens.sh' "$ROOT/scripts/theme/sync-surfaces.sh"; then
  printf 'Theme sync must render centralized visual tokens\n'
  exit 1
fi

if grep -R -n -- '--host[ =]loq15irx9' README.md docs website >/dev/null 2>&1; then
  printf 'Found stale uncanonical LOQ host flag in docs or website\n'
  exit 1
fi

if ! grep -q 'doctor)' "$ROOT/install.sh"; then
  printf 'install.sh must dispatch doctor without running the installer\n'
  exit 1
fi

if ! grep -q 'host::canonical' "$ROOT/lib/host.sh"; then
  printf 'Missing host alias normalization\n'
  exit 1
fi

if [[ ! -f "$ROOT/setup" || ! -f "$ROOT/local-bin/.local/bin/wallpaper-change" ]]; then
  printf 'Missing compatibility wrappers for setup or wallpaper-change\n'
  exit 1
fi

if ((missing_pipefail)); then
  exit 1
fi

printf 'Shell validation passed\n'
