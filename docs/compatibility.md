# Compatibility Matrix

| Profile | Status | Notes |
|---|---:|---|
| `loq-15irx9` | Primary | Full kernel, sleep, i915, power, and hybrid GPU policy. |
| `generic` | Supported fallback | Safe monitor defaults, no LOQ-only kernel tuning. |
| Intel iGPU | Preferred | Main daily driver path. |
| NVIDIA hybrid | Optional | Use `packages/optional-nvidia.txt`; hardware step enables NVIDIA services only outside integrated mode. |
| AMD desktop | Best effort | Use `--host=generic`; add a host profile before applying hardware policy. |
| Multi-monitor | Best effort | `monitor-detect.sh` writes local overrides in `~/.config/hypr/custom/monitors.conf`. |
| HiDPI | Manual | Add monitor scale overrides in the local custom config. |
