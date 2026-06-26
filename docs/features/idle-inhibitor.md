# Idle Inhibitor

Idle Inhibitor is toggled with `Super + I` and uses `scripts/system/idle-inhibit.sh`.

It uses `systemd-inhibit` when available and stores the inhibitor PID under `${XDG_RUNTIME_DIR:-/tmp}`. Pin moved to `Super + Alt + I`.
