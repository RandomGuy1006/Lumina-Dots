if [[ -o login ]] &&
    command -v uwsm >/dev/null 2>&1 &&
    [[ -z "${DISPLAY:-}" ]] &&
    [[ -z "${WAYLAND_DISPLAY:-}" ]] &&
    [[ "$(tty)" == "/dev/tty1" ]]; then
    exec uwsm start hyprland.desktop
fi
