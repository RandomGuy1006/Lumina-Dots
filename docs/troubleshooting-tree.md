# Troubleshooting Decision Tree

## Black Screen

1. Switch to TTY2 with `Ctrl + Alt + F2`.
2. Run `lumina-doctor`.
3. If Hyprland config is suspected, run `hypr-recover`.
4. If the issue started after package updates, run `sudo timeshift --list` and follow `docs/recovery.md`.

## No Bar

1. Run `systemctl --user status loq-hyprpanel.service`.
2. Run `bash "${DOTFILES_DIR}/scripts/install/03-dotfiles.sh"`.
3. Run `lumina-apply-theme ~/Pictures/Wallpapers/lumina-default.jpg`.
4. Restart with `systemctl --user restart loq-hyprpanel.service`.

## No Wallpaper

1. Check `command -v swww`.
2. Run `systemctl --user restart loq-swww.service`.
3. Run `lumina-apply-theme <wallpaper>`.

## Welcome service failed on first boot

1. Check `systemctl --user status lumina-welcome.service`.
2. If the service shows "failed", run:

   ```bash
   systemctl --user reset-failed lumina-welcome.service
   systemctl --user start lumina-welcome.service
   ```

3. If it still fails, inspect recent logs:

   ```bash
   journalctl --user -u lumina-welcome.service --since "5 minutes ago"
   ```


## Screen Share or File Pickers Broken

1. Run `lumina-doctor`.
2. Check `systemctl --user status xdg-desktop-portal-hyprland.service`.
3. Re-run `bash setup install --host=<host>`.

## Suspend or NVIDIA Issues

1. Confirm the host with `lumina-doctor`.
2. For LOQ hardware, run `bash setup hardware --host=loq-15irx9`.
3. Reboot after kernel parameter or GPU mode changes.
4. Keep `linux-lts` installed as the fallback boot option.
