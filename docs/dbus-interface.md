# Lumina D-Bus Interface

The session service owns `dev.lumina.core` at `/dev/lumina/core`. Its source-of-truth introspection document is `apps/lib/lumina_core/dev.lumina.core.xml`.

Interfaces expose settings, mood, glass, toast, wallpaper, and application/settings search methods and signals. `CurrentMood`, `CurrentGlass`, and `CurrentWallpaper` reflect persisted Lumina state; battery properties read the kernel power-supply interface. Consumers must subscribe to these interfaces and must not infer state by polling another component's configuration. Search requests use `dev.lumina.search.Query` and are resolved by `lumina_core.search`.

The service is D-Bus activatable and starts with `loq-session.target` through `lumina-core.service`. The canonical toast broadcast is `dev.lumina.toast.Toast(message, category)`; toast requests use `dev.lumina.toast.Send(message, subtitle, category)`.
