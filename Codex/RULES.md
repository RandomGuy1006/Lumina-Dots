# LUMINA PLATFORM CONSTITUTION — RULES.md
## Permanent Invariants — Never Negotiated, Never Overridden

**Document Class:** Platform Constitution
**Scope:** All platform layers, all tiers, all time
**Pair Documents:** `ARCHITECTURE.md` (vision), `IMPLEMENTATION_REFERENCE.md` (technical specs)
**Audience:** Every engineer, every contributor, every AI agent working on Lumina

> These rules are not guidelines. They are load-bearing invariants. A feature that violates any rule
> here is not a feature — it is a bug. If a rule conflicts with a desired feature, the rule wins.
> To change a rule, the architecture must be revised with explicit rationale — not circumvented.

---

## SECTION 1 — OWNERSHIP RULES
### Single-Ownership Principle

**RULE-001** — The **Glass Engine** is the sole authority on blur, opacity, noise, saturation, and brightness for every surface. No component may set its own blur value. No component may manage its own opacity independently. All glass-related behavior is delegated to `lumina-glass`.

**RULE-002** — The **Theme Engine** is the sole authority on the color token set. No component may hardcode a color. No component may write to `visual-tokens.json` except the Theme Engine pipeline (`lumina-theme apply`).

**RULE-003** — The **Design System** is the sole authority on every visual attribute (color, radius, spacing, motion, typography). No surface may use a raw value in any of these dimensions — only the named token from `visual-tokens.json`.

**RULE-004** — **Settings Studio** is the sole user-facing settings surface. No feature may expose a preference through a separate UI, a shell script invocation, or a config file that Settings Studio does not also expose. If a setting cannot be set from Settings Studio, it does not exist as a user-facing feature.

**RULE-005** — **Lumina Search** is the sole universal discovery surface. Every user-facing feature, setting, command, and action must be findable through Lumina Search. If a feature is not indexed, it is not discoverable and must be added to the search index.

**RULE-006** — **Action Feedback Toasts** are the sole user-visible feedback mechanism for system events. No feature may produce silent success. No feature may print errors only to a terminal. Every state change visible to the user must emit a toast.

---

## SECTION 2 — CONFIGURATION RULES
### No Configuration Sprawl

**RULE-007** — All configuration files must be JSON. Not TOML, not INI, not custom format.

**RULE-008** — All configuration files must live under `~/.config/lumina/`. No feature may introduce a config file outside this directory.

**RULE-009** — Every configuration file must have a corresponding JSON schema in `apps/settings-studio/schemas/`. A write that fails schema validation must be rejected with an in-app error toast — never silently written.

**RULE-010** — All configuration files must be written atomically: write to `.tmp`, then `os.rename()` to the final path. No feature may write a config file in-place (partial read risk).

**RULE-011** — Every successful configuration write must emit `dev.lumina.settings.Changed` on D-Bus immediately after the atomic rename completes.

**RULE-012** — Every service or module that reads a config file must fall back to hardcoded defaults if the file is missing. No service may crash on a missing config file.

**RULE-013** — No feature may require a user to edit a config file manually to accomplish something that Settings Studio exposes. If the manual edit is the only path, the setting must be added to Settings Studio.

---

## SECTION 3 — IPC RULES
### Communication Discipline

**RULE-014** — No service may directly write another service's config file. It must signal through the appropriate D-Bus channel and let the owning service write its own config.

**RULE-015** — All platform-wide state broadcasts must use D-Bus signals on the `dev.lumina.*` namespace. No polling, no file watching between services (file watching is allowed within a single service for its own config).

**RULE-016** — All search queries must use the `dev.lumina.search.Query` D-Bus method. Only `lumina_core.search` may read or build the search index directly.

**RULE-017** — All toast emissions from any process (including shell scripts) must use either `dev.lumina.toast.Send` D-Bus method or the `lumina-toast` CLI wrapper. No feature may call `notify-send` directly without going through the platform toast layer.

---

## SECTION 4 — INTEGRATION RULES
### Platform Cohesion

**RULE-018** — Every user-facing feature must be discoverable through at least **three** of the following four paths:
  1. Lumina Search (typing the feature name or a synonym returns it in top results)
  2. Settings Studio (at least one configurable option exists)
  3. Control Center (a quick toggle or status display exists)
  4. Keybind Overlay (the feature's keybind is documented in the correct category)

**RULE-019** — Every user-facing feature must have at least one setting in Settings Studio, even if the setting is only an on/off toggle. Features with zero Settings Studio presence violate RULE-004.

**RULE-020** — Every feature that modifies the visual environment must respect the **Glass Engine mode**. In `minimal` mode, no feature may apply blur, reduce opacity below 1.0, or render transparency effects. In `battery_mode`, all non-essential visual effects must be suppressed.

**RULE-021** — Every feature that uses animation or motion must respect `prefers-reduced-motion`. When this flag is set, non-essential animations must be disabled. Color and glass changes may still apply without animation.

**RULE-022** — Every new keybind must be documented in `docs/keybindings.md` and must appear in the Keybind Overlay under the correct category. Undocumented keybinds are not platform keybinds.

---

## SECTION 5 — ACCESSIBILITY RULES
### Minimum Baseline (Non-Negotiable)

**RULE-023** — Every GTK4 application must be fully operable without a mouse. Tab must navigate between interactive elements. Enter must activate. Escape must dismiss overlays.

**RULE-024** — Every interactive element must have an `accessible-name` and, where appropriate, an `accessible-description`. Unlabeled interactive elements are accessibility violations.

**RULE-025** — All text-on-surface color combinations must pass WCAG AA contrast (4.5:1 for text, 3:1 for UI components) at every glass mode (Crystal through Minimal). Glass mode changes must not cause contrast failures.

**RULE-026** — Every state change announced visually (toast, mode change, toggle) must also be announced to the AT-SPI accessibility bus so screen readers receive the update.

---

## SECTION 6 — PERFORMANCE RULES
### Minimum Acceptable Performance

**RULE-027** — Any keybind-to-visible-window time must be ≤ 80 ms. This requires overlay windows (Control Center, Lumina Search, Keybind Overlay) to be pre-rendered and hidden — not spawned on demand.

**RULE-028** — Settings writes must produce a confirmation toast within ≤ 200 ms of the user action.

**RULE-029** — The Theme Engine (full Matugen run + token write) must complete within ≤ 2,000 ms.

**RULE-030** — Glass mode change (all surfaces updated) must complete within ≤ 500 ms.

**RULE-031** — Mood apply (all subsystems coordinated) must complete within ≤ 500 ms.

**RULE-032** — Lumina Search must return first results within ≤ 50 ms of first keypress.

**RULE-033** — Every Lumina GTK4 application must launch within ≤ 400 ms.

**RULE-034** — Every feature must define its behavior when the Glass Engine is in `minimal` mode and when battery capacity drops below the configured low-battery threshold. "Undefined behavior on low battery" is not acceptable.

---

## SECTION 7 — QUALITY RULES
### Definition of Done

**RULE-035** — A feature is not complete until `bash tests/validate-repo.sh` exits 0.

**RULE-036** — A feature is not complete until `python3 tests/validate-lumina-core.py` exits 0.

**RULE-037** — A feature is not complete until `bash install.sh --dry-run --host=generic` exits 0 or 20.

**RULE-038** — A feature is not complete until `bash install.sh --dry-run --host=loq-15irx9` exits 0 or 20.

**RULE-039** — A feature is not complete until all new settings pages are validated against their JSON schema.

**RULE-040** — A feature is not complete until Lumina Search returns the feature within the top 3 results for its primary keyword.

**RULE-041** — A feature is not complete until all toasts have been visually tested at each glass mode for contrast compliance.

---

## SECTION 8 — ANTI-PATTERNS (EXPLICITLY PROHIBITED)

These patterns are permanently prohibited. Seeing one of these in a pull request or implementation is a rollback-level issue:

| Anti-Pattern | Why Prohibited |
|---|---|
| Hardcoded color (e.g. `#1a1a2e`) anywhere except `FALLBACK_TOKENS` | Violates Design System ownership (RULE-003) |
| Hardcoded blur value (e.g. `blur_size = 20`) outside Glass Engine | Violates Glass Engine ownership (RULE-001) |
| Direct `notify-send` without `lumina-toast` wrapper | Bypasses toast standardization (RULE-017) |
| Config file outside `~/.config/lumina/` | Violates config location rule (RULE-008) |
| Non-JSON config format | Violates config format rule (RULE-007) |
| Config write without schema validation | Violates schema rule (RULE-009) |
| Config write without D-Bus signal | Violates broadcast rule (RULE-011) |
| Feature with no Settings Studio page | Violates single-settings-surface rule (RULE-004) |
| Feature not in Lumina Search index | Violates universal discovery rule (RULE-005) |
| Service that crashes on missing config | Violates graceful fallback rule (RULE-012) |
| Animation that ignores `prefers-reduced-motion` | Violates accessibility rule (RULE-021) |
| Overlay window spawned on demand (not pre-rendered) | Violates 80ms performance rule (RULE-027) |
| Silent action (no toast on success or failure) | Violates feedback mandate (RULE-006) |
| Service writing another service's config file directly | Violates IPC discipline (RULE-014) |
| Keybind not in `docs/keybindings.md` | Violates documentation rule (RULE-022) |

---

## SECTION 9 — ARCHITECTURE REVIEW ADDITIONS
### Invariants Added from Implementability Review (2026-06-22)

**RULE-042** — `apps/lib/lumina_core/` must be created and stabilized **before** any new Lumina GTK4 application is built. Every new app must import from `lumina_core`, never re-implement glass, theme, or toast logic independently.

**RULE-043** — The D-Bus service descriptor for `dev.lumina.core` must be formalized and active before any inter-component D-Bus communication is implemented. Silent breakage from informal D-Bus usage is not acceptable.

**RULE-044** — Walker (`walker/`) is an acceptable temporary stand-in for Lumina Search. Any feature that integrates with Lumina Search must document its integration against the Lumina Search daemon IPC spec (not against Walker's internals) so the migration to the custom daemon is non-breaking.

**RULE-045** — Session Restoration (B-02) must document which applications are known to not support geometry restoration via Wayland. The feature must fail gracefully (restore what it can, skip what it cannot, log skipped apps to a toast) rather than failing silently or crashing.

---

*Lumina Platform Constitution — RULES.md*
*This document has no expiry. Rules are removed only by explicit architecture revision.*
*Pair with: `ARCHITECTURE.md` and `IMPLEMENTATION_REFERENCE.md`*
