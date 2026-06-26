# Comparison table

## Repository comparison

| Dimension | This repo | Omarchy | illogical-impulse |
|---|---|---|---|
| Visual polish | Premium, restrained, adaptive, coherent across Lumina Shell, HyprPanel fallback, launcher, lockscreen, terminal, and power menu | Highly polished, but more theme-pack oriented than host-specific | Extremely striking, often the strongest visually |
| Everyday usability | High. One coherent shell layer, discoverable controls, fast launch/switch flows | High, but more opinionated about workflow | Medium-high, but can trade clarity for spectacle |
| Hardware specificity | Explicit LOQ 15IRX9 host profile and recovery policy | Broad laptop support, lighter host targeting | Lower. More style-first than machine-first |
| Customizability | High through modular configs, host overlays, generated theme files, and docs | Medium-high but more opinionated | High, though often at the cost of complexity |
| Install reliability | Strong. Clear split between install, host apply, theme build, doctor, and rollback | Strong | Medium. Historically more variable and more dependent on setup assumptions |
| Post-install management | Strong. `install`, `update`, `doctor`, `backup`, `rollback` | Good, but more product-style than admin-style | Weaker as a systems-management story |
| Portability / git model | High. Generated outputs ignored, tracked sources stay clean | Medium | Medium-low |
| Complexity to maintain | Moderate and intentional | Moderate | High |
| Recovery story | Strong. Snapper, snap-pac, fallback Hyprland, doctor, linux-lts, docs | Good | Usually secondary to the visual layer |
| Default stability bias | Intel-first, Wayland-first, conservative where it counts | Good | Lower |

## Other respected Hyprland repos considered

| Repo style | What it does well | Why this repo does not copy it directly |
|---|---|---|
| ML4W | Breadth, onboarding, polished packaged feel | Broader than needed; less tightly focused on your exact stack and laptop |
| JaKooLit | Fast setup, many knobs, popular defaults | More kit-like than product-like |
| end-4 | Exceptional visual ambition and shell-level polish | Too much complexity for your maintenance budget and explicit Quickshell avoidance |
