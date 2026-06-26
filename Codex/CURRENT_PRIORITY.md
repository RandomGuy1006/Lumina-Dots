# CURRENT_PRIORITY.md
## Lumina Platform — Active Work Queue and Scope Lock

**Document Class:** Operational Priority Register
**Derived From:** `ARCHITECTURE.md`, `RULES.MD`, `IMPLEMENTATION_REFERENCE.md`
**Repository Snapshot:** 2026-06-22
**Last Updated:** 2026-06-23
**Next Review:** Runtime Verification complete → Release Certification

> This document defines exactly what work is permitted until the next architecture review.
> No work outside the ACTIVE NOW tier is allowed. No exceptions. No scope creep.
> When in doubt, read `RULES.md` before writing a single line of code.

---

# Current Release Target

## Lumina v1.0 — Platform Foundation

This release establishes the **load-bearing infrastructure** that every future feature
depends on. It does not ship a complete product. It ships an unbreakable core.

**Definition of "Platform Foundation":**
- `apps/lib/lumina_core/` is stable and complete
- The Glass Engine has a formalized Python API and generates `glass-rules.conf`
- The Theme Engine has a formalized CLI (`lumina-theme`) and emits D-Bus signals
- The Mood Engine has a formalized Python module and `mood.json` contract
- Settings Studio exists as a launchable GTK4 application with Appearance + Wallpaper + Mood pages
- The D-Bus interface (`dev.lumina.core`) is active and enforced
- All existing apps (Control Center, Keybind Overlay, Mission Control) are wired to D-Bus
- `tests/validate-lumina-core.py` exits 0
- `tests/validate-repo.sh` exits 0

**What v1.0 Platform Foundation does NOT include:**
- Music Center, Clipboard Center, Widget Engine, Battery Analytics
- Session Restoration, Screenshot Studio, App Center
- Any D-Tier enhancements
- The custom Lumina Search daemon (Walker remains the placeholder)

---

# Repository Reality — Confirmed Status

Derived from direct inspection of the repository on 2026-06-22.

## ✅ EXISTS — Working

| System | Location | Notes |
|--------|----------|-------|
| `lumina_core` base library | `apps/lib/lumina_core/` | Has: `app.py`, `theme.py`, `config.py`, `contracts.py`, `hyprland.py`, `layer_shell.py`, `state.py`, etc. |
| Control Center | `apps/control-center/lumina-control-center.py` | Exists (9611 bytes); not yet wired to formalized D-Bus |
| Keybind Overlay | `apps/keybind-overlay/lumina-keybind-overlay.py` | Exists (5812 bytes); `# category:` / `# desc:` convention not yet applied to `binds.conf` |
| Mission Control | `apps/mission-control/lumina-mission-control.py` | Exists (3826 bytes); verify `hyprland-overview` plugin installed |
| Theme Studio | `apps/theme-studio/` | Exists; verify token-level editing is functional |
| Activity History | `apps/activity-history/` | Exists; maps to B-03 Activity Timeline; verify JSONL format alignment |
| Pomodoro / Focus | `apps/pomodoro/` | Exists; maps to B-05 Focus Mode; not yet wired to glass + ambient |
| Snapshot Manager | `apps/snapshot-manager/` | Exists |
| Welcome / Onboarding | `apps/welcome/` | Exists; maps to S-01 Onboarding Wizard (§S-01-OB) |
| Lumina Hub | `apps/lumina-hub/` | Exists |
| Walker (Search placeholder) | `walker/` | Acceptable stand-in per RULE-044 |
| Wallpaper apply script | `scripts/wallpaper-apply.sh` | Exists; cascade to theme + mood not formalized |
| Theme apply script | `scripts/apply-theme.sh` | Exists; ad-hoc, not yet replaced by `lumina-theme` CLI |
| Focus Mode script | `scripts/system/focus-mode.sh` | Exists; not wired to Glass Engine or Mood Engine |
| Battery alert script | `scripts/system/battery-alert.sh` | Exists |
| Matugen pipeline | `matugen/` | Exists |
| JSON Schemas | `schemas/` | Exists; not yet in `apps/settings-studio/schemas/` (location required by RULE-009) |
| `theme.py` in lumina_core | `apps/lib/lumina_core/theme.py` | Partial — has token loading, fallback tokens, CSS helpers; missing `regenerate_tokens()`, `apply_hypr_colors()`, `apply_gtk_theme()` |

## ⚠️ PARTIAL — Needs Completion

| System | Gap |
|--------|-----|
| `lumina_core/theme.py` | Missing: `regenerate_tokens()`, `apply_hypr_colors()`, `apply_gtk_theme()`, `lumina-theme` CLI |
| `lumina_core/app.py` | Exists; verify `load_css()` subscribes to `dev.lumina.settings.Changed` |
| Wallpaper Experience (S-07) | Script exists; missing: formalized cascade (wallpaper → theme → mood), Settings Studio page |
| Control Center (S-06) | Exists; missing: D-Bus subscription to `dev.lumina.*`, pre-rendering for 80ms constraint |
| Keybind Overlay (S-09) | Exists; missing: `# category:` / `# desc:` comments in `binds.conf` |
| Gesture Engine (A-05) | `scripts/system/` has partial gesture logic; missing: `gestures.json` abstraction, generator script |
| Lock Screen Studio (A-04) | `hyprlock` is installed; missing: config generation script, mood → clock style mapping |

## ❌ DOES NOT EXIST — Must Be Built

| System | Notes |
|--------|-------|
| `apps/settings-studio/` | **Highest priority gap in the entire platform** |
| `apps/lib/lumina_core/glass.py` | Glass Engine Python API (GlassMode enum, GlassConfig, presets, apply_glass_layerrules) |
| `apps/lib/lumina_core/mood.py` | Mood Engine Python API (Mood enum, MoodProfile, apply_mood, detect_mood_from_wallpaper) |
| `apps/lib/lumina_core/toasts.py` | Toast API (toast(), LuminaToastOverlay) |
| D-Bus service (`dev.lumina.core`) | Interface descriptor not yet active |
| `lumina-glass` CLI | Command-line accessor for Glass Engine |
| `lumina-mood` CLI | Command-line accessor for Mood Engine |
| `lumina-theme` CLI subcommands | `apply/reset/preview/export` |
| `glass.json` config contract | Config file + JSON schema |
| `mood.json` config contract | Config file + JSON schema |
| Music Center (A-01) | MPRIS UI not built |
| Clipboard Center (A-02) | `cliphist` backend may exist; GTK4 UI not built |
| Widget Engine (A-03) | Not built |
| Battery Analytics (A-08) | Not built |
| Context Menu System (A-06) | Not built |
| Screenshot Studio (B-01) | `grim`+`slurp` exist; annotation overlay not built |
| Session Restoration (B-02) | Not built (Wayland geometry caveat documented in RULE-045) |
| App Center (C-02) | Not built |
| Ultra Minimal Mode (D-03) | Not built |
| Ambient Sounds service (D-02) | `mpv` exists; service + Settings Studio integration not built |

---

# Priority Tiers

---

## ACTIVE NOW
### ✅ COMPLETE — FROZEN

**Completion Date:** 2026-06-23

**Completion Scope:**
- Step 1 complete — `lumina_core` library (`glass.py`, `mood.py`, `toasts.py`, `theme.py` pipeline, D-Bus interface)
- Step 2 complete — Settings Studio (Appearance + Wallpaper + Mood pages)
- Step 3 complete — Existing apps wired to D-Bus (Control Center, Keybind Overlay, Mission Control)
- Step 4 complete — Wallpaper cascade formalized (`wallpaper-apply.sh` → `lumina-theme` → `lumina-mood`)

**Remaining:**
- Runtime verification (see `RUNTIME_VERIFICATION.md`)
- Release certification (all exit criteria confirmed on target hardware)

> **No further coding is allowed in ACTIVE NOW.**
> Only bug fixes discovered during runtime verification may touch ACTIVE NOW systems.
> All bug fixes must be logged in `RUNTIME_VERIFICATION.md` under the relevant section.

---

> ~~Work currently permitted. Nothing outside this list may be started.~~
> ~~Complete every item in this tier — and pass all exit criteria — before moving to NEXT.~~

### Step 1 — lumina_core Library Completion (BLOCKER FOR EVERYTHING)

**Why first:** RULE-042 prohibits building any new Lumina GTK4 app before `lumina_core` is complete.
All apps import from here. Building anything else before this is completed will produce apps that
must be rewritten.

---

#### lumina_core/glass.py — Glass Engine Python API

**Status:** ❌ Does not exist

**Remaining Work:**
- [ ] Create `apps/lib/lumina_core/glass.py`
- [ ] Define `GlassMode(str, Enum)` with 5 values: `crystal`, `frosted`, `mica`, `material`, `minimal`
- [ ] Define `GlassConfig` frozen dataclass with all fields from `IMPLEMENTATION_REFERENCE.md §Part I`
- [ ] Encode `GLASS_PRESETS` dict with the exact preset table from the spec (blur/passes/opacity/sat/noise/bright)
- [ ] Implement `load_glass_config() → GlassConfig` — reads `~/.config/lumina/glass.json`, falls back to `frosted` preset (RULE-012)
- [ ] Implement `save_glass_config(cfg)` — writes atomically to `glass.json`, emits `dev.lumina.settings.Changed` (RULE-010, RULE-011)
- [ ] Implement `glass_css(cfg) → str` — pure function, no I/O, returns CSS custom properties block
- [ ] Implement `apply_glass_layerrules(cfg, classes)` — writes `~/.config/hypr/conf.d/glass-rules.conf`, calls `hyprctl --batch`
- [ ] Implement `glass_classes() → list[str]` — returns list of Hyprland window classes to apply rules to
- [ ] Apply `performance_mode` halving logic (blur/passes ÷ 2)
- [ ] Apply `battery_mode` override (force `minimal` without writing to `glass.json`)
- [ ] Create `~/.config/lumina/glass.json` JSON schema → `apps/settings-studio/schemas/glass.schema.json` (RULE-009)
- [ ] Create `lumina-glass` CLI wrapper in `local-bin/` (`set <mode>`, `status`, `reload`)

**Exit Criteria:**
- [ ] `python3 -c "from lumina_core.glass import GlassMode, GlassConfig, GLASS_PRESETS, glass_css; print('OK')"` exits 0
- [ ] `glass_css()` produces a CSS block with all 6 `--glass-*` tokens
- [ ] `load_glass_config()` returns `frosted` preset when `glass.json` is absent (no crash)
- [ ] `apply_glass_layerrules()` produces a non-empty `glass-rules.conf` in ≤ 50 ms
- [ ] `lumina-glass set frosted` changes glass mode, writes config, emits D-Bus signal, shows toast
- [ ] `lumina-glass set minimal` on battery: does not overwrite stored `glass.json`

---

#### lumina_core/mood.py — Mood Engine Python API

**Status:** ❌ Does not exist

**Remaining Work:**
- [ ] Create `apps/lib/lumina_core/mood.py`
- [ ] Define `Mood(str, Enum)` with 8 values from the spec
- [ ] Define `MoodProfile` frozen dataclass (emoji, display_name, glass_mode, sound_pack, color_temperature, clock_style, motion_speed, wallpaper_hint)
- [ ] Encode `MOOD_PROFILES` dict with the full 8-mood table from `IMPLEMENTATION_REFERENCE.md §S-05`
- [ ] Implement `apply_mood(mood, auto_sound, auto_glass, auto_clock)` — coordinates Glass Engine, Theme Engine (temperature), lock screen style, motion tokens; uses `asyncio.gather` for parallelism; must complete in ≤ 500 ms (RULE-031)
- [ ] Implement `detect_mood_from_wallpaper(path) → Mood` — dominant color analysis via `colorthief` or Matugen output; runs in background thread; never blocks UI
- [ ] Implement `current_mood() → Mood` — reads `~/.config/lumina/mood.json`; falls back to `frosted`/`nature` if absent (RULE-012)
- [ ] Write `~/.config/lumina/mood.json` atomically on `apply_mood()`; emit `dev.lumina.settings.Changed` (RULE-010, RULE-011)
- [ ] Create `mood.json` JSON schema → `apps/settings-studio/schemas/mood.schema.json` (RULE-009)
- [ ] Create `lumina-mood` CLI in `local-bin/` (`set <mood>`, `detect --wallpaper=<path>`, `status`)
- [ ] Wire `apply_mood()` to call `lumina-glass set <mode>` via subprocess or D-Bus
- [ ] Wire `apply_mood()` to call `lumina-theme apply --temperature=<K>` for color temperature
- [ ] Every mood change emits a toast: "Mood: {mood} {emoji} active" (RULE-006)

**Exit Criteria:**
- [ ] `python3 -c "from lumina_core.mood import Mood, MOOD_PROFILES, apply_mood; print('OK')"` exits 0
- [ ] `current_mood()` returns a valid `Mood` value even when `mood.json` is absent
- [ ] `apply_mood(Mood.NATURE)` completes in ≤ 500 ms and produces a toast
- [ ] `detect_mood_from_wallpaper()` returns a `Mood` value without blocking the calling thread
- [ ] `lumina-mood set ocean` sets mood, writes config, shows toast "Mood: ocean 🌊 active"
- [ ] `mood.json` validates against `mood.schema.json`

---

#### lumina_core/toasts.py — Toast API

**Status:** ❌ Does not exist
**Blocker:** RULE-017 prohibits direct `notify-send` calls. Every existing script that uses `notify-send` is currently violating this rule. This must be fixed as part of this task.

**Remaining Work:**
- [ ] Create `apps/lib/lumina_core/toasts.py`
- [ ] Implement `toast(message, subtitle, category)` — emits via `dev.lumina.toast.Send` D-Bus method (falls back to `notify-send` wrapper if D-Bus not yet active)
- [ ] Implement `LuminaToastOverlay` class wrapping `Adw.ToastOverlay` for in-app use
- [ ] Apply correct default durations: info=2s, success=2s, warning=4s, error=6s (persistent until dismissed)
- [ ] Implement `ICON_MAP` with all four categories
- [ ] Create `lumina-toast` CLI in `local-bin/` — calls `toast()` so all shell scripts can use it
- [ ] **Migrate all existing scripts** that call `notify-send` directly to call `lumina-toast` instead (RULE-017):
  - [ ] `scripts/wallpaper-apply.sh`
  - [ ] `scripts/system/focus-mode.sh`
  - [ ] `scripts/system/battery-alert.sh`
  - [ ] Any other scripts found via: `grep -r "notify-send" scripts/`

**Exit Criteria:**
- [ ] `python3 -c "from lumina_core.toasts import toast, LuminaToastOverlay; print('OK')"` exits 0
- [ ] `lumina-toast "Test message" "" success` produces a visible notification
- [ ] Zero direct `notify-send` calls remain in `scripts/` (grep confirms)
- [ ] `LuminaToastOverlay.toast()` produces an `Adw.Toast` in a test GTK4 app

---

#### lumina_core/theme.py — Complete Missing Functions

**Status:** ⚠️ Partial — token loading and CSS helpers exist; pipeline functions missing

**Remaining Work:**
- [ ] Add `regenerate_tokens(wallpaper_path, overrides, color_temperature) → dict` — runs Matugen, applies overrides from `palette-overrides.json`, writes `visual-tokens.json` atomically, emits `dev.lumina.settings.Changed`; must complete in ≤ 2,000 ms (RULE-029)
- [ ] Add `apply_hypr_colors(tokens)` — writes `~/.config/hypr/conf.d/tokens-colors.conf`, calls `hyprctl reload`
- [ ] Add `apply_gtk_theme(tokens)` — updates GTK CSS provider in all running `LuminaApplication` instances via D-Bus
- [ ] Validate that `FALLBACK_TOKENS` matches the Design System token taxonomy in `IMPLEMENTATION_REFERENCE.md §S-02`
- [ ] Create `lumina-theme` CLI in `local-bin/` with subcommands: `apply [--wallpaper=] [--temperature=]`, `reset`, `preview <path>`, `export`

**Exit Criteria:**
- [ ] `lumina-theme apply --wallpaper=/path/to/image.jpg` runs Matugen, writes `visual-tokens.json`, emits D-Bus signal, and returns in ≤ 2,000 ms
- [ ] `lumina-theme reset` removes palette overrides and re-derives from current wallpaper
- [ ] `lumina-theme export` prints the current token set as valid JSON
- [ ] `apply_gtk_theme()` does not cause a perceptible flash in any running app

---

#### D-Bus Interface Formalization

**Status:** ❌ Interface defined in architecture, not active in codebase
**Blocker:** RULE-043 prohibits inter-component D-Bus communication before the descriptor is active. Every current inter-app communication that uses D-Bus is informal until this is done.

**Remaining Work:**
- [ ] Create D-Bus service descriptor for `dev.lumina.core` at the correct system/session path
- [ ] Define all signals: `settings.Changed`, `mood.Changed`, `glass.Changed`, `toast`, `wallpaper.Changed`
- [ ] Define all methods: `mood.Apply`, `glass.Set`, `search.Query`, `toast.Send`
- [ ] Define all properties: `CurrentMood`, `CurrentGlass`, `CurrentWallpaper`, `BatteryPercent`, `OnBattery`
- [ ] Activate the service on session startup (add to systemd user service or Hyprland `exec-once`)
- [ ] Document the interface in `docs/` per RULE-022

**Exit Criteria:**
- [ ] `gdbus introspect --session --dest dev.lumina.core --object-path /dev/lumina/core` returns the full interface without error
- [ ] `gdbus call --session --dest dev.lumina.core --object-path /dev/lumina/core --method dev.lumina.toast.Send "Test" "" "info"` produces a toast
- [ ] D-Bus is active within 5 seconds of Hyprland startup

---

### Step 2 — Settings Studio (v1.0 Scope: Appearance + Wallpaper + Mood Pages Only)

**Status:** ❌ `apps/settings-studio/` does not exist
**Blocked by:** Step 1 (lumina_core must be complete first — RULE-042)
**Architecture source:** `IMPLEMENTATION_REFERENCE.md §S-01`

**Remaining Work:**
- [ ] Create `apps/settings-studio/` directory
- [ ] Create `apps/settings-studio/lumina-settings-studio.py` as a `LuminaApplication` subclass
- [ ] Primary window: `Adw.ApplicationWindow` + `Adw.NavigationSplitView` (sidebar + content pane)
- [ ] Sidebar: category list — for v1.0 scope: Appearance, Wallpaper, Mood (remaining pages in NEXT tier)
- [ ] Header: inline search field that filters visible settings (client-side, ≤ 16 ms response)
- [ ] Implement deep-link CLI: `lumina-settings-studio --page=<page> --section=<section>` (required for Lumina Search integration)
- [ ] Implement config write pattern: validate against schema → write atomically → emit D-Bus signal → show toast (RULE-009, RULE-010, RULE-011, RULE-006)
- [ ] Implement in-memory undo stack (last 10 changes per session); `CTRL+Z` reverts last change + shows toast
- [ ] Create `apps/settings-studio/schemas/` directory
- [ ] **Appearance Page:**
  - [ ] Glass Mode `Adw.ComboRow` (5 options) → writes `glass.json`, calls `lumina-glass reload`, shows toast
  - [ ] Advanced glass expander (opacity, blur, noise, brightness sliders)
  - [ ] Accent Color `Adw.ActionRow` + `Gtk.ColorButton` → writes `palette-overrides.json`, re-runs `lumina-theme apply`
  - [ ] Icon Theme `Adw.ComboRow` (auto-discovered)
  - [ ] Cursor Theme `Adw.ComboRow` (auto-discovered)
  - [ ] Font `Adw.ActionRow` with font chooser popover
  - [ ] Lock Screen section (clock style, show battery, show date, blur strength)
- [ ] **Wallpaper Page:**
  - [ ] Wallpaper directory `Adw.EntryRow` with folder picker
  - [ ] Auto-rotate `Adw.SwitchRow` → enables/disables `lumina-wallpaper-rotate.timer`
  - [ ] Rotation Interval `Adw.SpinRow` (visible only when auto-rotate is on)
  - [ ] Animated wallpaper support `Adw.SwitchRow`
  - [ ] Transition style `Adw.ComboRow` (Fade / Zoom / Wipe / None)
- [ ] **Mood Page:**
  - [ ] Current mood display `Adw.ActionRow` + mood picker dialog (8 cards, 4×2 grid)
  - [ ] Auto-detect from wallpaper `Adw.SwitchRow`
  - [ ] Auto-start ambient sound `Adw.SwitchRow`
  - [ ] Auto-set clock style `Adw.SwitchRow`
  - [ ] Auto-adjust glass mode `Adw.SwitchRow`
  - [ ] Color temperature `Adw.SpinRow` (only when auto-detect is off)
- [ ] App must launch within 400 ms (RULE-033)
- [ ] Settings writes confirm with toast within 200 ms (RULE-028)
- [ ] All `Adw.PreferencesRow` subclasses carry `accessible-name` and `accessible-description` (RULE-024)
- [ ] Keyboard navigation: Tab / Enter / Space / Escape fully functional (RULE-023)
- [ ] Add `SUPER + ,` keybind to `binds.conf`, document in `docs/keybindings.md` (RULE-022)
- [ ] Register Settings Studio in Keybind Overlay under "System" (RULE-018)

**Exit Criteria:**
- [ ] `lumina-settings-studio` launches in ≤ 400 ms from keybind
- [ ] Changing Glass Mode in Appearance page changes compositor glass in ≤ 500 ms and shows toast
- [ ] Changing wallpaper directory and toggling auto-rotate writes config atomically and emits D-Bus signal
- [ ] Changing mood from the Mood page calls `apply_mood()` and shows "Mood: X active" toast
- [ ] `lumina-settings-studio --page=appearance --section=glass-mode` opens directly to Glass Mode section
- [ ] `CTRL+Z` reverts the last settings change and shows "Reverted: X → Y" toast
- [ ] `bash tests/validate-repo.sh` exits 0
- [ ] `python3 tests/validate-lumina-core.py` exits 0

---

### Step 3 — Wire Existing Apps to D-Bus

**Blocked by:** Step 1 (D-Bus interface must be active)

**Remaining Work:**

#### Control Center (S-06)
- [ ] Verify `apps/control-center/lumina-control-center.py` matches the 360px-wide, 6-row layout spec from `IMPLEMENTATION_REFERENCE.md §S-06`
- [ ] Add D-Bus subscriber: `dev.lumina.*` signals to stay live-updated
- [ ] Replace any direct `notify-send` calls with `lumina-toast`
- [ ] Confirm window is **pre-rendered and hidden** (not spawned on demand); activate via opacity/transform for ≤ 80 ms (RULE-027)
- [ ] Wire Mood row to `lumina-mood set <mood>` and show mood picker overlay
- [ ] Wire Glass row buttons to `lumina-glass set <mode>`
- [ ] Confirm all toggle buttons show both icon and text label (RULE-023)
- [ ] Every Control Center action produces a toast (RULE-006)

**Control Center Exit Criteria:**
- [ ] `SUPER+SHIFT+S` → visible Control Center in ≤ 80 ms
- [ ] Glass mode change from Control Center updates compositor and shows toast in ≤ 500 ms
- [ ] D-Bus subscription confirmed: mood change from Settings Studio updates Control Center mood row within 1 second

#### Keybind Overlay (S-09)
- [ ] Apply `# category: <Name>` and `# desc: <Description>` comment convention to all binds in `binds.conf`
- [ ] Categories minimum: Navigation, Windows, System, Apps, Productivity, Help
- [ ] Confirm overlay pre-rendering for ≤ 80 ms (RULE-027)
- [ ] Confirm search filter responds in ≤ 16 ms (client-side)
- [ ] Register every current Lumina keybind in `docs/keybindings.md` (RULE-022)

**Keybind Overlay Exit Criteria:**
- [ ] `SUPER+/` → visible overlay in ≤ 80 ms
- [ ] Typing "glass" returns the glass mode keybind or Control Center entry in top 3 results
- [ ] All categories contain at least one entry

#### Mission Control (S-08)
- [ ] Confirm `hyprland-overview` plugin is loaded in `hypr/conf.d/plugins.conf`
- [ ] Confirm glass-surface styling is applied via Glass Engine CSS variables
- [ ] Confirm workspace tiles have accessible names: "Workspace N: AppName, AppName" (RULE-024)
- [ ] Add `SUPER+TAB` to `docs/keybindings.md` and Keybind Overlay under "Navigation"

**Mission Control Exit Criteria:**
- [ ] `SUPER+TAB` → overview renders in ≤ 100 ms
- [ ] Plugin is confirmed active in Hyprland on the target host (loq-15irx9)

---

### Step 4 — Wallpaper Cascade Formalization (S-07)

**Blocked by:** Steps 1–2 (theme + mood engines must exist)

**Remaining Work:**
- [ ] Update `scripts/wallpaper-apply.sh` to call `lumina-theme apply --wallpaper="$path"` (not ad-hoc Matugen invocation)
- [ ] Update `scripts/wallpaper-apply.sh` to call `lumina-mood detect --wallpaper="$path"` (when auto-detect is on)
- [ ] Replace `notify-send` in `wallpaper-apply.sh` with `lumina-toast`
- [ ] Add `--no-theme` and `--no-mood` flags for testing/override use
- [ ] Add `--transition-type` and `--transition-duration` from Settings Studio → Wallpaper → Transition Style
- [ ] Wallpaper directory thumbnail generation: 200×112 px thumbs cached in `~/.cache/lumina/thumbnails/`
- [ ] Ensure Theme Engine runs **after** `swww` transition completes (not during)

**Wallpaper Exit Criteria:**
- [ ] Setting a wallpaper via `lumina-wallpaper <path>` causes: compositor updates → Matugen runs → tokens update → mood detects → all in ≤ 3,200 ms total
- [ ] Toast: "Wallpaper applied" shown on completion
- [ ] Wallpaper transition respects `prefers-reduced-motion` (no animated transition when set)

---

## NEXT

> Work that becomes permitted after **all** ACTIVE NOW exit criteria pass.
> Do not start any of these. Do not design them in detail. Do not prototype them.

### S-10 Lumina Search — Phase 1 Walker Integration
Wire Walker to be Lumina Search's placeholder with proper configuration:
- [ ] Ensure Walker is registered in Keybind Overlay under `SUPER+SPACE`
- [ ] Document Walker as the S-10 placeholder per RULE-044
- [ ] Any new feature that integrates with search must document against the Lumina Search daemon IPC spec, not Walker internals

### A-07 Action Feedback Toasts — Settings Studio Integration
Once Settings Studio exists:
- [ ] Add Notifications page to Settings Studio (toast duration, position, per-category toggles)
- [ ] Wire all existing toast categories to Settings Studio toggles

### A-04 Lock Screen Studio
Once Mood Engine is complete:
- [ ] Create `scripts/apply-lockscreen-style.sh` that generates `hyprlock.conf` from mood + tokens
- [ ] Define `CLOCK_STYLES` dict with 6 styles
- [ ] Add Lock Screen section to Settings Studio → Appearance (clock style, auto-set from mood, show battery, show date, blur strength)

### A-05 Gesture Engine — Settings Studio Page
Once Settings Studio exists:
- [ ] Create `scripts/system/generate-gesture-conf.py` from `gestures.json`
- [ ] Add Gestures page to Settings Studio with per-slot `Adw.EntryRow`
- [ ] Create `gestures.json` JSON schema

### Settings Studio — Remaining Pages
Add after v1.0 Foundation pages (Appearance, Wallpaper, Mood) are stable:
- [ ] Animations page
- [ ] Gestures page
- [ ] Widgets page
- [ ] Audio page
- [ ] Notifications page
- [ ] Lumina Search page
- [ ] AI page
- [ ] Battery page
- [ ] Performance page
- [ ] Updates page
- [ ] Recovery page

### B-05 Focus Mode — System Wiring
Once Glass Engine + Mood Engine + toasts are complete:
- [ ] Update `scripts/system/focus-mode.sh` to call `lumina-glass set material`, `lumina-mood` (temporary override), `dunstctl set-paused`, `lumina-toast`
- [ ] Wire to Control Center Focus toggle
- [ ] Wire to Activity Timeline logging
- [ ] Add Focus page to Settings Studio

### A-08 Battery Analytics
Once `lumina_core` is complete and Settings Studio has a Battery page:
- [ ] Create `apps/battery-analytics/`
- [ ] Battery logger service + chart UI

### A-01 Music Center
- [ ] Create `apps/music-center/` once S-Tier is complete
- [ ] MPRIS D-Bus subscription, compact + expanded views
- [ ] Wire to Control Center Row 5

### A-02 Clipboard Center
- [ ] Create `apps/clipboard-center/` once Settings Studio exists
- [ ] `cliphist` backend + GTK4 UI

---

## LATER

> Work intentionally deferred after NEXT tier completes.

- **A-03 Widget Engine** — GTK4 layer-shell per-widget daemon. Deferred due to scope.
- **A-06 Context Menu System** — Transparent desktop overlay. Deferred.
- **B-01 Screenshot Studio** — `grim`+`slurp` annotation overlay. Deferred.
- **B-02 Session Restoration** — Known Wayland geometry limitations per RULE-045. Deferred.
- **B-03 Activity Timeline** — `apps/activity-history/` exists but JSONL format alignment needed.
- **C-01 Theme Studio** — `apps/theme-studio/` exists; token-level editing verification deferred.
- **C-03 Update Center** — `update.sh` exists; GUI wrapper deferred.
- **D-01 Animated Wallpapers** — `mpvpaper` partial; Settings Studio hook deferred.
- **D-02 Ambient Sounds** — `mpv` loop service deferred; Mood Engine must exist first.
- **D-03 Ultra Minimal Mode** — Shell script is trivial; deferred until D-Tier opens.

---

## FROZEN

> Work forbidden until a future architecture review explicitly unlocks it.
> An agent that starts any of these is in violation.

- **C-02 App Center** — `pacman`/`paru`/`flatpak` GUI. Significant scope; requires stable platform first.
- **S-10 Custom Lumina Search Daemon** — Full custom daemon with SQLite FTS5, 9 plugin types, AI integration. Walker is the accepted placeholder (RULE-044). Custom daemon is frozen until v1.0 Platform Foundation is shipped and the next release cycle opens.
- **AI Integration** (beyond search placeholder) — Ollama/Gemma backend in Settings Studio. Frozen.
- **Voice Activation** — Whisper/Vosk hotword. Frozen.
- **Settings Sync** — Cross-device sync via git/rclone. Frozen.
- **Cross-device Clipboard Sync** — Syncthing integration. Frozen.
- **Scheduled Moods / Themes** — Calendar-driven automation. Frozen.
- **Third-party Plugin API** — D-Bus manifest for external apps. Frozen until platform APIs are stable.
- **Multi-monitor per-wallpaper themes** — Token sets per output. Frozen.

---

# Scope Lock Rules

The following rules are permanent for this release cycle. They may not be overridden by any agent, contributor, or implementation decision.

1. **No A-Tier work before all S-Tier requirements (Steps 1–4) pass their exit criteria.**
2. **No B-Tier work before all A-Tier requirements pass their exit criteria.**
3. **No C-Tier or D-Tier work before all B-Tier requirements pass their exit criteria.**
4. **No new features while foundational systems are incomplete.** This means: no new GTK4 apps, no new shell scripts that invent their own glass/theme/toast logic, no new config files outside `~/.config/lumina/`.
5. **Bug fixes are always allowed** regardless of tier.
6. **Documentation updates are always allowed** regardless of tier.
7. **Refactoring is allowed only when it directly supports an ACTIVE NOW checklist item.** Do not refactor for its own sake.
8. **Any work that would violate a rule in RULES.md is not allowed regardless of tier.**

---

# Release Gate

Before any system may move from NEXT to ACTIVE NOW, the following must be true:

## Required Conditions to Open NEXT

- [ ] `bash tests/validate-repo.sh` → exit 0
- [ ] `python3 tests/validate-lumina-core.py` → exit 0
- [ ] `bash install.sh --dry-run --host=generic` → exit 0 or 20
- [ ] `bash install.sh --dry-run --host=loq-15irx9` → exit 0 or 20
- [ ] `lumina_core` complete: `glass.py`, `mood.py`, `toasts.py`, `theme.py` all have full public APIs
- [ ] D-Bus interface active: `gdbus introspect` returns full `dev.lumina.core` interface
- [ ] Settings Studio launches with Appearance + Wallpaper + Mood pages functional
- [ ] All existing scripts migrated from `notify-send` to `lumina-toast`
- [ ] Control Center wired to D-Bus and appears in ≤ 80 ms
- [ ] Keybind Overlay has `# category:` / `# desc:` on all binds and appears in ≤ 80 ms
- [ ] All new keybinds documented in `docs/keybindings.md` and visible in Keybind Overlay (RULE-022)
- [ ] All new settings pages validated against their JSON schemas (RULE-039)
- [ ] All toasts tested at each glass mode for contrast compliance (RULE-041)
- [ ] Lumina Search (Walker) returns each new ACTIVE NOW feature within top 3 results for its primary keyword (RULE-040)
- [ ] Every new feature has at least one setting in Settings Studio (RULE-019)
- [ ] Every new feature is discoverable via at least 3 of the 4 discovery paths (RULE-018)
- [ ] `prefers-reduced-motion` respected by all animations in new features (RULE-021)
- [ ] Glass `minimal` mode behavior defined for every new feature (RULE-034)
- [ ] All interactive elements have `accessible-name` and `accessible-description` (RULE-024)
- [ ] Architecture review scheduled for the next release cycle

---

# Rules for Future Agents

An agent working on this codebase **must refuse** to do the following. These are not suggestions.

| Prohibited Action | Rule Violated |
|---|---|
| Building any FROZEN or LATER feature | Scope Lock |
| Building A-Tier features before S-Tier exit criteria pass | Scope Lock |
| Building any new GTK4 app before `lumina_core` is complete | RULE-042 |
| Hardcoding any color value (e.g. `#1a1a2e`) outside `FALLBACK_TOKENS` | RULE-003 |
| Hardcoding any blur value outside `glass.py` | RULE-001 |
| Calling `notify-send` directly without going through `lumina-toast` | RULE-017 |
| Writing a config file outside `~/.config/lumina/` | RULE-008 |
| Using a non-JSON config format | RULE-007 |
| Writing a config file without schema validation | RULE-009 |
| Writing a config file without atomic write pattern | RULE-010 |
| Writing a config file without emitting `dev.lumina.settings.Changed` | RULE-011 |
| Creating a feature with no Settings Studio page | RULE-004 |
| Creating a feature not indexed by Lumina Search (Walker) | RULE-005 |
| Creating a service that crashes when its config file is missing | RULE-012 |
| Using D-Bus informally before the `dev.lumina.core` descriptor is active | RULE-043 |
| One service directly writing another service's config file | RULE-014 |
| Creating an overlay window that spawns on demand (not pre-rendered) | RULE-027 |
| Any animation that does not respect `prefers-reduced-motion` | RULE-021 |
| Adding a keybind not documented in `docs/keybindings.md` | RULE-022 |
| Reordering the architecture layers (e.g. building Music Center before Glass Engine) | ARCHITECTURE.md §2.1 |
| Introducing duplicate ownership (two systems controlling the same thing) | RULE-001, RULE-002, RULE-003 |
| Bypassing Settings Studio by creating a separate settings UI | RULE-004 |
| Bypassing Lumina Search by making a feature non-indexable | RULE-005 |
| Bypassing Toast infrastructure with silent actions | RULE-006 |
| Integrating Walker internals directly instead of documenting against daemon IPC spec | RULE-044 |

**When uncertain,** read `RULES.md` before making any decision. If a rule and a feature request conflict, **the rule wins**.

---

*CURRENT_PRIORITY.md — Lumina v1.0 Platform Foundation*
*Derived from: `ARCHITECTURE.md`, `RULES.md`, `IMPLEMENTATION_REFERENCE.md`*
*Repository snapshot: 2026-06-22 | Next review: After all ACTIVE NOW exit criteria pass*
