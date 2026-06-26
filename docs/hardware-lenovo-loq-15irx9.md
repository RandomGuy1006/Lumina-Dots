# Lenovo LOQ 15IRX9 hardware guide

## Assumption

This repo assumes the common Intel + NVIDIA LOQ 15IRX9 variant and intentionally defaults to the Intel-first path for Wayland stability.

## Why Intel-first is the default

- fewer Wayland regressions
- better sleep reliability
- lower thermal noise
- lower idle power draw
- less maintenance pressure after kernel and driver updates

## Important BIOS guidance

- Keep BIOS current.
- Prefer Hybrid or Integrated graphics mode if available.
- Disable Secure Boot unless you intend to manage signed third-party modules.
- Use the factory panel refresh options, but let Hyprland set `highrr` rather than hardcoding refresh unless your panel is misdetected.

## Kernel and sleep policy

This repo applies:

- `mem_sleep_default=deep`
- `i915.enable_psr=0`
- `ibt=off`
- `nvme_core.default_ps_max_latency_us=0`

It also sets:

- `HandleLidSwitch=suspend`
- `HibernateDelaySec=45min`

That is a deliberate balance:

- fast enough for normal sleep
- safer for lid-close reliability on this hardware
- still allows suspend-then-hibernate when the resume path is configured correctly

## Thermals and battery

- `auto-cpufreq` handles daily governor tuning
- `thermald` adds Intel thermal sanity
- `fstrim.timer` and scrub timers keep storage healthier over time
