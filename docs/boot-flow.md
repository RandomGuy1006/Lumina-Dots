# What Runs on Boot

```mermaid
flowchart TD
  A["TTY1 login shell"] --> B["~/.zprofile"]
  B --> C["uwsm start hyprland.desktop"]
  C --> D["Hyprland"]
  D --> E["~/.config/hypr/exec.conf"]
  E --> F["uwsm finalize"]
  F --> G["loq-session.target"]
  G --> H["loq-swww.service"]
  G --> I["loq-hyprpanel.service"]
  G --> J["loq-hypridle.service"]
  G --> K["cliphist watchers"]
  E --> L["hyprlock boot service"]
  E --> M["polkit, battery alert, avatar, monitor detect"]
```

The login shell starts UWSM only on TTY1, only when no Wayland or X11 session is already active. Hyprland then imports the display environment, finalizes the UWSM session, and starts the Lumina user target.

`loq-session.target` is the ordering point for wallpaper, panel, idle, clipboard, and switcher services. Recovery tools intentionally bypass this path when needed.
