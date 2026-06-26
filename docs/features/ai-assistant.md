# Lumina AI Assistant

Lumina AI is the Phase 5 optional assistant.

- App: `apps/lumina-ai/lumina-ai.py`
- CLI: `lumina-ai`
- Dotfiles command: `dotfiles ai`
- Keybind: `Super + A`
- Config: `~/.config/lumina/ai.toml`

The default backend is `pattern`, which is deterministic and works with no model, network, API key, or cloud dependency. Pattern mode can explain keybinds, Doctor, themes, recovery, Hub, Mission Control, and release validation commands.

Optional Ollama backends may be enabled by config, but failures fall back to pattern mode. Cloud backends are disabled unless `allow_cloud = true`, and no cloud provider is required for Lumina operation.

Safe actions launch existing Lumina tools only: Doctor Dashboard, Theme Studio, Keybind Overlay, recovery docs, and Hub.
