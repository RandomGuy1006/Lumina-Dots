# Workspace Templates

Workspace templates launch common layouts through `scripts/system/workspace-template.sh`.

Templates live under `~/.config/lumina/workspace-templates/`. The repo ships `dev.toml` and `media.toml` examples. The launcher reads TOML-style `workspace` and `command` entries and starts commands through UWSM when available.
