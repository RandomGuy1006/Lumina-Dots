# LUMINA PLATFORM ARCHITECTURE
## Authoritative Platform Vision and Architecture Reference

**Document Class:** Platform Architecture — Vision and Structure
**Scope:** All platform layers, S-Tier through D-Tier
**Pair Documents:** `RULES.md` (platform constitution), `IMPLEMENTATION_REFERENCE.md` (technical specs)
**Audience:** Platform engineers, UX leads, integration architects

> **Implementability Status (Architecture Review 2026-06-22):**
> Architecture is internally consistent and implementable. Technology choices are realistic.
> Primary gap: `apps/settings-studio/` does not yet exist. `apps/lib/lumina_core/` is not yet
> formalized. D-Bus interface (`dev.lumina.*`) is not yet active in the codebase.
> Existing foundations: `matugen/`, `walker/`, `waypaper/`, `apps/control-center/`,
> `apps/keybind-overlay/`, `apps/mission-control/`, `apps/theme-studio/`, `scripts/`.

---

## FOREWORD — FROM PHASES TO PLATFORM

The original prompt describes Lumina as a sequence of engineering phases. This document replaces that framing entirely.

A phase plan answers the question *"what do we build next?"* A platform architecture answers the question *"what is this, and why does every part of it exist?"* The first produces a checklist. The second produces a coherent operating environment.

Lumina is not a Hyprland configuration that has grown ambitious. It is a desktop shell — a complete, opinionated, discoverable environment that happens to run on top of Hyprland and Arch Linux. Every decision in this document is made as if Lumina were competing with macOS Sonoma, Windows 11, GNOME 46, and KDE Plasma 6. Not in market share, but in internal coherence.

The core problem with the phase-oriented roadmap is that it produces *features*, not *systems*. A feature is something you build. A system is something every other feature relies on. When you build features first, you eventually discover that Glass Mode needs to live in three places, that wallpaper logic is duplicated across four scripts, and that the user has no single place to understand what Lumina actually does. This document eliminates that problem before it compounds.

---

## PART I — PLATFORM VISION

### 1.1 What Lumina Is

Lumina is a **unified desktop shell** for Arch Linux built on the Hyprland compositor. It provides a complete, cohesive environment where:

- Every visual decision flows from a single source of truth (the Design System and Theme Engine)
- Every user action produces consistent, discoverable feedback
- Every preference is findable through a single application (Settings Studio) or a single search interface (Lumina Search)
- Every component knows about every other component through defined system boundaries

Lumina's ambition is not to be the most feature-complete Linux desktop. It is to be the most *internally consistent* one — the desktop where a new user can figure out how to do anything within 60 seconds, and an experienced user never has to touch a config file to accomplish something the UI supports.

### 1.2 The Six Platform Pillars

These are not features. They are the structural load-bearing walls of the platform. Every feature in every tier must have a defined relationship to at least two of them.

**Pillar 1 — The Design System**
A single, centrally managed set of visual tokens (colors, radii, spacing, motion curves, typography) that all GTK4 apps, Hyprland rules, lock screen, and shell surfaces consume. No component hard-codes a color. No component hard-codes a blur value. Every visual attribute is a token.

**Pillar 2 — The Glass Engine**
The single authority on blur, opacity, noise, saturation, and brightness for every surface in the platform. Apps do not decide how glassy they are. The Glass Engine decides, and apps comply.

**Pillar 3 — The Theme Engine**
The pipeline that transforms a wallpaper or manual palette selection into a complete, coherent token set via Matugen, then broadcasts that token set to every surface simultaneously. Theme changes are atomic — the entire desktop transitions together.

**Pillar 4 — The Mood Engine**
A higher-level semantic layer that sits above the Theme Engine. Where the Theme Engine asks "what are the colors?", the Mood Engine asks "what is the feeling?" It drives glass mode, ambient sound, motion speed, color temperature, and lock screen style as a coordinated emotional state.

**Pillar 5 — Settings Studio**
The canonical, discoverable home for every preference in the platform. If a preference is not findable through Settings Studio, it does not exist as far as users are concerned. There are no hidden config files, no `~/.config` archaeology required.

**Pillar 6 — Lumina Search**
The universal entry point for any action, app, file, setting, or command. The answer to "where do I go to do X?" is always "press SUPER+SPACE." This eliminates the discoverability cliff that plagues most Linux desktop configurations.

> **Architecture Review Note (S-10):** The current codebase uses `walker/` as a stand-in for Lumina Search. Walker is a general-purpose launcher. The full platform-aware Lumina Search daemon described in S-10 is a significant custom build. Walker serves as an acceptable placeholder until the custom daemon is implemented. See `IMPLEMENTATION_REFERENCE.md §S-10` for the phased migration path.

### 1.3 Design Commandments

These apply to every feature decision made in this document and every engineering decision made from it. (Formalized as enforceable rules in `RULES.md`.)

1. **No configuration sprawl.** Every setting lives in Settings Studio. Shell scripts may exist as backend mechanisms but never as the user-facing interface.
2. **No isolated utilities.** Every standalone tool must be discoverable through Lumina Search and must have a presence in either Settings Studio or Control Center.
3. **No duplicated logic.** If two features do the same thing, one delegates to the other. The Glass Engine owns blur. Nothing else touches blur.
4. **Feedback is mandatory.** Every user action produces a visible toast notification. Silence is not acceptable.
5. **Accessibility is not optional.** Every UI surface must be keyboard-navigable and screen-reader compatible from day one.
6. **Performance degrades gracefully.** Every feature must have a defined behavior when the Glass Engine is in `minimal` mode and when the battery falls below 20%.
7. **The platform teaches itself.** Onboarding overlays, empty states, and contextual hints are required — not an afterthought.

---

## PART II — PLATFORM ARCHITECTURE

### 2.1 System Dependency Graph

The following describes which systems depend on which others. This is the authoritative resolution order: lower-numbered systems must be stable before higher-numbered systems are integrated.

```
Layer 0 — Substrate (Hyprland, systemd, libinput, PipeWire, D-Bus)
    │
Layer 1 — Core Token Infrastructure
    ├── Design System          (visual-tokens.json)
    ├── Glass Engine           (glass.json → glass-rules.conf)
    └── Theme Engine           (Matugen pipeline → visual-tokens.json)
    │
Layer 2 — Semantic Orchestration
    ├── Mood Engine            (reads Theme Engine, drives Glass + ambient + motion)
    └── Wallpaper Experience   (drives Theme Engine, reads Mood Engine)
    │
Layer 3 — User-Facing Platform Core
    ├── Settings Studio        (reads/writes everything in Layers 1–2)
    ├── Lumina Search          (indexes everything in Layers 1–3)
    ├── Control Center         (exposes Mood, Glass, quick toggles from Layers 1–2)
    ├── Mission Control        (reads workspace state from Hyprland)
    └── Keybind Overlay        (reads binds.conf, indexed by Lumina Search)
    │
Layer 4 — Daily Experience (A-Tier)
    ├── Music Center           (integrates with Mood Engine, Control Center)
    ├── Clipboard Center       (integrates with Lumina Search)
    ├── Widget Engine          (reads Design System tokens)
    ├── Lock Screen Studio     (reads Mood Engine, Glass Engine)
    ├── Gesture Engine         (triggers Control Center, Mission Control)
    ├── Context Menu System    (reads Design System tokens)
    ├── Action Feedback Toasts (used by every other layer)
    └── Battery Analytics      (drives Glass Engine battery_mode)
    │
Layer 5 — Productivity (B-Tier)
    ├── Screenshot Studio
    ├── Session Restoration
    ├── Activity Timeline
    ├── Scratchpad System
    ├── Focus Mode
    └── Window Teleportation
    │
Layer 6 — Platform Services (C-Tier)
    ├── Theme Studio
    ├── App Center
    └── Update Center
    │
Layer 7 — Enhancements (D-Tier)
    ├── Animated Wallpapers
    ├── Ambient Sounds
    └── Ultra Minimal Mode
```

### 2.2 Data Flow Architecture

**Token Flow (read-only, broadcast)**
```
Wallpaper file
    → Theme Engine (Matugen)
        → visual-tokens.json
            → All GTK4 apps (via LuminaApplication.load_css)
            → Hyprland colors (via token-to-hypr.py)
            → Lock screen (via apply-lockscreen-style.sh)
            → Widget Engine (via CSS custom properties)
```

**Mood Flow (read-write, coordinated)**
```
User selects mood  OR  wallpaper analyzed
    → Mood Engine
        → Glass Engine (set mode)
        → Theme Engine (set color temperature via hyprsunset)
        → Ambient Sound Engine (start/stop pack)
        → Lock Screen (set clock style)
        → Motion tokens (set speed multiplier)
        → Control Center (update mood display)
```

**Settings Flow (write-on-change)**
```
User changes setting in Settings Studio
    → Write config file (glass.json / gestures.json / etc.)
    → Broadcast D-Bus signal: dev.lumina.settings.Changed
    → Affected services reload automatically
    → Toast notification confirms change
```

**Search Index Flow (background, incremental)**
```
Lumina Search module (lumina_core.search)
    → Indexes: apps, settings pages, files, commands, keybinds
    → Listens: dev.lumina.settings.Changed (invalidate settings index)
    → Listens: inotify on $HOME (invalidate file index)
    → Serves: dev.lumina.search.Query through lumina-core-service
```

### 2.3 Inter-Process Communication

All Lumina services communicate through a defined IPC hierarchy. No service may directly write another service's config file. It must signal through the appropriate channel.

| Channel | Protocol | Used For |
|---|---|---|
| `dev.lumina.settings.Changed` | D-Bus signal | Settings changes broadcast |
| `dev.lumina.toast` | D-Bus method call | Toast from any process |
| `dev.lumina.mood.Apply` | D-Bus method call | Mood change requests |
| `dev.lumina.search` | D-Bus method call | Search queries |
| `dev.lumina.glass.Mode` | D-Bus property | Glass mode read/write |
| `hyprctl dispatch` | Hyprland IPC | Workspace/window commands |

> **Architecture Review Note:** The D-Bus interface (`dev.lumina.*`) is architecturally correct but not yet active in the codebase. Formalizing the service descriptor is a prerequisite for all inter-component communication. See `IMPLEMENTATION_REFERENCE.md — Appendix B` for the full D-Bus interface reference.

### 2.4 File System Layout

```
~/.config/lumina/
├── glass.json              # Glass Engine config
├── mood.json               # Mood Engine state + preferences
├── gestures.json           # Gesture bindings (source of truth)
├── widgets.json            # Widget Engine layout
├── clipboard.json          # Clipboard Center preferences
├── search.json             # Lumina Search preferences
├── focus.json              # Focus Mode config
├── session.json            # Session Restoration state
└── palette-overrides.json  # Manual accent overrides

~/.cache/lumina/
├── visual-tokens.json      # Current token set (generated, do not edit)
├── search-index/           # Lumina Search index (generated)
├── thumbnails/             # Wallpaper thumbs (generated)
└── activity.jsonl          # Activity Timeline stream

~/.config/hypr/conf.d/
├── glass-rules.conf        # Generated by Glass Engine
├── gestures-rules.conf     # Generated by Gesture Engine
└── tokens-colors.conf      # Generated by Theme Engine
```

---

## PART III — S-TIER PLATFORM SYSTEMS

S-Tier systems are load-bearing. They are not features — they are the platform. Nothing in A-Tier through D-Tier is spec'd, designed, or built until every S-Tier system has a stable public API and a working implementation.

---

### S-01 — Settings Studio

**Keybind:** `SUPER + ,`
**App ID:** `dev.lumina.settings-studio`

> **Architecture Review Note:** `apps/settings-studio/` does not yet exist. This is the highest-priority gap in the entire platform. Everything else in the architecture has no canonical home without it.

#### Purpose

Settings Studio is the single, canonical, discoverable home for every preference in the Lumina platform. It is the answer to every question of the form "where do I go to change X?"

It is not a configuration file editor. It is not a front-end for shell scripts. It is a first-class GTK4 application that understands the semantics of every setting it exposes — what it affects, what depends on it, and what confirmation to show when it changes.

#### User Value

A user who has never seen a config file can configure every aspect of their Lumina environment through Settings Studio. A user who knows exactly what they want can find it in under three keystrokes (SUPER+SPACE → type setting name → Enter). There are no hidden knobs, no "advanced" config files that the UI doesn't expose, and no settings that require terminal access.

#### Relationship to Other Systems

Settings Studio is the **write interface** for every Layer 1–2 system:
- Writes `glass.json` → signals Glass Engine to reload
- Writes `mood.json` → signals Mood Engine to apply
- Writes `gestures.json` → triggers `generate-gesture-conf.py` → reloads `lumina-gestures.service`
- Writes `widgets.json` → signals Widget Engine to relayout
- Calls `lumina-theme apply` when palette is changed

Settings Studio is also the primary target for Lumina Search deep links. Every settings page is a searchable destination: `lumina-settings-studio --page=appearance --section=glass-mode`.

#### Discoverability Strategy

- Lumina Search indexes every settings page by name, description, and aliases
- Every setting has a search-friendly label (e.g. "blur" finds Glass Mode)
- First-launch onboarding wizard walks through the five most impactful settings
- Empty states in each page show what the setting does, not just how to set it

#### Accessibility Philosophy

- All `Adw.PreferencesRow` subclasses carry full `accessible-name` and `accessible-description`
- Keyboard navigation: Tab moves between rows, Enter activates, Space toggles switches
- Color contrast: all text on glass surfaces meets WCAG AA minimum (4.5:1)
- Font size follows GNOME accessibility settings; no hardcoded sizes

#### Onboarding Wizard (§S-01-OB)

Triggered on first launch (detected via absence of `~/.config/lumina/.setup-complete`).

Five steps, each as a full-screen `Adw.Dialog` card:
1. **Welcome** — "This is Lumina. Here's what it is." Brief description + platform pillars in plain language.
2. **Choose your vibe** — Mood picker (8 moods as visual cards showing a wallpaper preview, glass style, and ambient sound name). Selecting one applies the mood immediately in the background.
3. **Glass style** — Three-option picker (Crystal / Frosted / Minimal) with a live preview area showing a simulated window at each mode.
4. **Discover quickly** — Animated demonstration of SUPER+SPACE (Lumina Search) and SUPER+/ (Keybind Overlay). Brief and skippable.
5. **You're set** — "Press SUPER+SPACE anytime you're lost." Touches `~/.config/lumina/.setup-complete`.

#### Future Expansion Path

- Plugin system: third-party apps register their own settings pages via a D-Bus manifest
- Settings sync: optional encrypted sync via user-specified backend (git, rclone)
- Profile export/import: save a named profile of all settings as a single `.lumina-profile` archive

---

### S-02 — Design System

**No keybind (infrastructure only)**
**Config file:** `~/.cache/lumina/visual-tokens.json`

> **Architecture Review Note:** `matugen/` and `schemas/` exist, confirming the token pipeline is partially built. Missing: `lumina_core/theme.py` as the formal Python API. The scripts likely handle this ad-hoc today.

#### Purpose

The Design System is not an application. It is the single source of truth for every visual attribute in the platform. It is the contract between the Theme Engine (which generates tokens) and every surface that consumes them (GTK4 apps, Hyprland config, lock screen, widgets).

Without a Design System, each component becomes an island of hard-coded values. With one, changing the accent color is a single atomic operation that updates every surface simultaneously.

#### User Value

Users never see the Design System directly. They see its effects: a desktop that changes color, depth, and motion as a unified whole — never partially, never inconsistently.

#### Token Taxonomy Philosophy

The Design System defines five categories of tokens: **Color**, **Glass**, **Motion**, **Spatial**, and **Typography**. Color tokens are generated by the Theme Engine from Matugen. Glass tokens are generated by the Glass Engine. Motion, Spatial, and Typography tokens are stable constants with override hooks. No surface may use a raw value in any of these dimensions — only the named token.

#### Accessibility Philosophy

- All generated color pairs must be validated for WCAG AA contrast (4.5:1 text, 3:1 UI components) before writing to `visual-tokens.json`
- If Matugen generates a token pair below threshold, the generator applies a luminance correction before writing
- A `--high-contrast` mode override is stored in `palette-overrides.json`

> **Architecture Review Note:** WCAG AA auto-correction of Matugen output is non-trivial and may produce unexpected color shifts. This validation can be deferred to a later pass — the token pipeline should ship first, contrast enforcement second.

#### Future Expansion Path

- Multiple named themes stored as separate token sets; instant switch without regeneration
- Token inheritance: "dark mode" overrides specific tokens without full regeneration
- Third-party token packs distributed as `.lumina-theme` archives

---

### S-03 — Glass Engine

**Shell accessor:** `lumina-glass`
**Config file:** `~/.config/lumina/glass.json`

> **Architecture Review Note:** Partial glass logic exists in `scripts/apply-theme.sh`. Missing: `lumina_core/glass.py` with `GlassMode` enum, `GlassConfig` dataclass, and `apply_glass_layerrules()`. The 5-preset table is ready to encode. Feasibility: High.

#### Purpose

The Glass Engine is the single authority on every blur and opacity decision in the platform. No component hard-codes a blur value. No component manages its own opacity. All glass-related behavior flows through this module.

It bridges three worlds: Python config management, CSS custom properties for GTK4 apps, and Hyprland `layerrule` compositor commands. By centralizing this bridge, changing glass mode anywhere (Settings Studio, Control Center, Focus Mode, Battery Analytics) produces consistent results everywhere.

#### User Value

Users control the visual density of their entire desktop with a single choice: Crystal, Frosted, Mica, Material, or Minimal. They see every window, panel, and overlay respond uniformly. They never have to wonder why their terminal looks different from their notifications.

The glass modes also communicate system state: Minimal mode means "I'm saving power." Crystal mode means "I have resources to spare." This makes glass a UI affordance, not just an aesthetic.

#### Relationship to Other Systems

- **Mood Engine** calls `glass.sh set <mode>` when a mood is applied
- **Battery Analytics** calls `glass.sh set minimal` when battery drops below threshold
- **Focus Mode** calls `glass.sh set minimal` when entering deep focus
- **Settings Studio** writes `glass.json` directly and calls `glass.sh` to reload
- **Control Center** exposes a glass mode picker that calls `lumina-glass set <mode>`
- **Design System** consumes `glass_css()` output for its CSS variable block
- All GTK4 apps inherit glass variables automatically via `LuminaApplication.load_css()`

#### Discoverability Strategy

- "blur", "glass", "transparency", "opacity", "frosted" all route to the Glass Mode section in Settings Studio via Lumina Search
- First-launch wizard shows glass mode as step 3
- Control Center exposes it as a top-row quick toggle

#### Accessibility Philosophy

- `minimal` mode is never auto-disabled by the system; users who need solid surfaces always have access to it
- Glass mode changes must not cause layout shifts in app content — only the background surface changes
- Performance mode is automatically recommended (via toast) when frame rate drops below 30 Hz

#### Future Expansion Path

- Per-app glass overrides: individual apps can request a different glass mode via D-Bus property
- Dynamic glass: Glass Engine responds to CPU temperature data by degrading glass mode automatically
- Glass transitions: animated cross-fade between glass modes using `swww` transition system

---

### S-04 — Theme Engine

**Shell accessor:** `lumina-theme`
**Config file:** `~/.cache/lumina/visual-tokens.json` (output), `~/.config/lumina/palette-overrides.json` (input)

> **Architecture Review Note:** `matugen/` integration and `scripts/apply-theme.sh` are the right foundation. Missing: formalized `lumina-theme` CLI with `apply/reset/preview/export` subcommands. Feasibility: High.

#### Purpose

The Theme Engine is the pipeline that produces the Design System's token set. It takes a wallpaper image (or a manual palette) and produces a complete, coherent visual token set via Matugen, then broadcasts that token set to every consumer simultaneously.

Theme changes in Lumina are **atomic**. The entire desktop — GTK4 apps, Hyprland border colors, lock screen, widget accent colors — transitions together. There is no intermediate state where some surfaces have the old theme and some have the new one.

#### User Value

Every time a user changes their wallpaper, their entire desktop responds: colors, borders, accents, and the lock screen all shift to complement the new image. Users never have to manually pick a matching accent color because the system derives one automatically. Users who want manual control can override specific tokens in Settings Studio.

#### Relationship to Other Systems

- **Wallpaper Experience** triggers the Theme Engine whenever a new wallpaper is applied
- **Mood Engine** calls the Theme Engine with a color temperature override when a mood is applied
- **Design System** consumes the token file that the Theme Engine produces
- **Settings Studio** calls `lumina-theme apply` when the user makes an accent override
- **Lock Screen Studio** reads `visual-tokens.json` to set its clock and surface colors
- **Widget Engine** reads CSS custom properties derived from the token set

#### Future Expansion Path

- Token presets: named palettes that bypass Matugen (import from `.lumina-theme` files)
- Scheduled theme changes: auto-apply a warmer palette at sunset
- Multi-monitor per-wallpaper themes: per-output token sets

---

### S-05 — Mood Engine

**Shell accessor:** `lumina-mood`
**Config file:** `~/.config/lumina/mood.json`

> **Architecture Review Note:** The concept exists but no `lumina-mood` service or `mood.json` contract has been found in the codebase. The coordination logic is straightforward. The wallpaper mood-detection is the trickiest part — achievable with `colorthief` or Matugen's output. Risk: mood detection accuracy is heuristic and may feel wrong for edge-case wallpapers.

#### Purpose

The Mood Engine is a semantic orchestration layer. Where the Theme Engine asks "what colors should the desktop be?", the Mood Engine asks "what should the desktop *feel* like?" It coordinates glass mode, ambient sound, color temperature, lock screen style, and motion speed as a coherent emotional state.

The Mood Engine is not a visual feature. It is a coordination feature. Its job is to make applying a named mood feel like setting a scene, not configuring five separate systems.

#### User Value

A user in a deep-work session selects "Minimal" mood. Their glass mode shifts to Material (less distraction), animations slow to 0.5×, ambient sound switches to brown noise, color temperature warms slightly, and their lock screen clock switches to the minimal analog style — all with one action.

A user who finishes work selects "Ocean" mood. Their desktop transitions to cool blues, gentle Frosted glass, ocean wave ambient sound, and a fluid analog clock.

Moods also auto-detect from wallpaper. A user who sets a nature photograph doesn't need to manually select "Nature" mood — the system detects the dominant palette and selects the closest mood profile.

#### Relationship to Other Systems

- **Theme Engine**: called for color temperature adjustment
- **Glass Engine**: called to set glass mode
- **Ambient Sounds** (D-Tier): called to start/stop sound pack
- **Lock Screen Studio**: called to set clock style
- **Motion tokens**: written directly (speed multiplier)
- **Control Center**: displays current mood, exposes mood picker
- **Lumina Hub**: displays current mood in status bar
- **Settings Studio**: configures which mood auto-triggers are enabled

#### The Eight Moods

| Mood | Glass | Sound | Temp (K) | Clock | Motion |
|------|-------|-------|----------|-------|--------|
| cyberpunk | crystal | synthwave | 4000 | cyber | 1.2× |
| nature | frosted | forest | 5500 | minimal | 0.8× |
| ocean | frosted | ocean | 5200 | android | 0.9× |
| dark | mica | none | 3500 | terminal | 0.7× |
| warm | material | cafe | 3200 | material | 0.8× |
| minimal | minimal | none | 6500 | minimal | 0.5× |
| space | crystal | space | 4500 | cyber | 1.0× |
| retro | material | vinyl | 4000 | windows | 0.9× |

#### Discoverability Strategy

- "mood", "vibe", "atmosphere", "feel", "theme" all route to mood picker via Lumina Search
- First-launch wizard makes mood the first meaningful choice (step 2)
- Control Center makes current mood always visible

#### Accessibility Philosophy

- Mood picker cards are keyboard-navigable (arrow keys between cards, Enter to apply)
- Each card has an accessible description: "Nature mood: frosted glass, forest sounds, warm motion"
- Mood changes emit a toast that screen readers announce
- All mood transitions respect `prefers-reduced-motion`; glass/color changes still apply but animations are disabled

#### Future Expansion Path

- Custom moods: user-defined profiles stored in `mood.json`
- Scheduled moods: auto-apply based on time of day or calendar events
- Mood API: third-party apps can suggest mood changes via D-Bus (with user confirmation)
- AI mood: optional Ollama integration analyzes calendar context to suggest mood

---

### S-06 — Control Center

**Keybind:** `SUPER + SHIFT + S` (or 4-finger swipe down)
**App ID:** `dev.lumina.control-center`

> **Architecture Review Note:** `apps/control-center/` exists. Needs to be wired to the formalized D-Bus interface. Verify the current implementation matches the 360px-wide, 6-row layout spec.

#### Purpose

Control Center is a quick-access panel for the most common in-session adjustments. It is not a settings application — it is a **transient action surface**. Everything in Control Center can also be done in Settings Studio; Control Center is the shortcut layer for users who know what they want.

Control Center appears as a slide-down or slide-up overlay (from top or bottom of screen, configurable), with glass styling from the Glass Engine. It dismisses on Escape, on click-outside, or on the same keybind.

#### User Value

A user wants to switch mood, toggle Do Not Disturb, adjust volume, and check battery — all without opening a full application window. Control Center provides all of this within 2 seconds of activation.

#### Relationship to Other Systems

Control Center is a **read surface and quick-write surface** for:
- Mood Engine (display + set mood)
- Glass Engine (set glass mode)
- Battery Analytics (display battery %, charging status, time remaining)
- Music Center (now-playing + transport controls)
- Action Feedback Toasts (every action in Control Center produces a toast)
- Ambient Sounds (start/stop)
- Focus Mode (enable/disable)
- Lumina Settings Studio (deep-link button)

#### Discoverability Strategy

- SUPER+SHIFT+S keybind documented in Keybind Overlay under "System"
- 4-finger swipe down gesture (documented in Gesture Engine)
- Lumina Search → "control center" → opens it directly
- Onboarding wizard mentions Control Center in step 4

#### Accessibility Philosophy

- Control Center is fully keyboard-navigable: Tab between sections, arrow keys within button rows, Escape to dismiss
- Each section has a visually-hidden heading for screen readers
- Volume and brightness sliders have accessible labels with live value announcement
- All toggle buttons show both icon and text label; icon-only mode is not used

#### Performance Philosophy

- Control Center must appear within 80 ms of keybind (window is pre-rendered, hidden, and shown via opacity/transform)
- All D-Bus reads are cached and refreshed every 1 second; Control Center never blocks on I/O during show animation

> **Architecture Review Note:** The ≤80ms constraint requires overlay windows to be pre-rendered and hidden — not spawned on demand. Verify this is how the existing `apps/control-center/` works.

#### Future Expansion Path

- Widget slots: third-party apps register Control Center widgets via D-Bus manifest
- Per-workspace Control Center state (different quick toggles per workspace profile)
- Voice activation: "Hey Lumina, open control center" via local Whisper model

---

### S-07 — Wallpaper Experience

**Shell accessor:** `lumina-wallpaper`
**Services:** `lumina-wallpaper-rotate.timer`, `lumina-wallpaper-rotate.service`

> **Architecture Review Note:** `scripts/wallpaper-apply.sh` and `waypaper/` are present. Missing: formalization of the cascade (wallpaper → theme → mood). Feasibility: High.

#### Purpose

Wallpaper in Lumina is not a cosmetic setting. It is the primary driver of the platform's entire visual identity. Changing the wallpaper changes the Theme Engine output, which changes the Mood Engine state, which changes glass mode, ambient sound, and lock screen style. Wallpaper is the highest-level user control in the visual stack.

#### User Value

Setting a wallpaper feels like setting the mood for a room. The entire environment responds — colors, surfaces, sounds, and depth all shift to complement the image. Users don't need to manually coordinate anything. One file change cascades through the entire platform.

#### Relationship to Other Systems

- **Theme Engine**: triggered immediately on wallpaper change to regenerate tokens
- **Mood Engine**: triggered to detect mood from new wallpaper (if auto-detect is on)
- **Lock Screen Studio**: receives the wallpaper path for blurred background
- **Lumina Search**: wallpaper directory is indexed for file search
- **Settings Studio**: exposes wallpaper directory, rotation interval, and transition style

#### Future Expansion Path

- Live wallpaper support via mpvpaper (D-Tier: Animated Wallpapers)
- Curated wallpaper packs distributed via App Center
- Wallpaper sync across devices
- AI wallpaper generation via local Stable Diffusion (optional, future D-Tier)

---

### S-08 — Mission Control

**Keybind:** `SUPER + TAB` (or 3-finger swipe up)
**App ID:** `dev.lumina.mission-control` (Hyprland Overview plugin)

> **Architecture Review Note:** `apps/mission-control/` exists. Uses `hyprland-overview` plugin — verify the plugin is installed in the Hyprland setup.

#### Purpose

Mission Control is the workspace and window overview. It provides a bird's-eye view of all open workspaces and windows, enabling navigation, window reorganization, and workspace creation — all from a single gesture or keybind.

#### User Value

Users with complex multi-workspace setups can see their entire session at a glance, drag windows between workspaces, and jump to any window — without cycling through windows blindly or remembering which workspace holds which app.

#### Relationship to Other Systems

- **Gesture Engine**: 3-finger swipe up triggers Mission Control
- **Glass Engine**: Mission Control overlay uses the current glass mode
- **Design System**: workspace tiles use `--color-surface-variant` and `--radius-lg`
- **Keybind Overlay**: Mission Control is documented as a primary navigation shortcut
- **Lumina Search**: "mission control" opens it; individual windows are searchable from Search

---

### S-09 — Keybind Overlay

**Keybind:** `SUPER + /`
**App ID:** `dev.lumina.keybind-overlay`

> **Architecture Review Note:** `apps/keybind-overlay/` exists. The `# category:` / `# desc:` comment convention needs to be applied to `binds.conf` for the overlay to display categorized results correctly.

#### Purpose

Keybind Overlay is a searchable, categorized, always-accurate reference for every keybinding in the Lumina platform. It is never out of date because it reads directly from `binds.conf` — it does not maintain a separate documentation file.

#### User Value

A user who forgets a keybind never has to leave their session to look it up. They press SUPER+/ and type what they're trying to do. The overlay shows them the binding and, for interactive bindings, lets them click to execute it.

#### Relationship to Other Systems

- **Lumina Search**: Keybind Overlay search results appear in Lumina Search as a plugin (category: "Keybinds")
- **Settings Studio**: Lumina Search preferences page has a "Keybinds plugin" toggle
- **binds.conf**: Keybind Overlay parses this file directly; adding a `# category: Navigation` comment to any bind makes it appear in the correct Keybind Overlay category

---

### S-10 — Lumina Search

**Keybind:** `SUPER + SPACE`
**App ID:** `dev.lumina.search`
**Owner module:** `lumina_core.search`

> **Architecture Review Note:** Search is owned by `lumina_core.search` and exposed through `dev.lumina.search.Query`. Walker may invoke the discovery surface, but source indexing and ranking must stay behind the Lumina Search owner module.

#### Purpose

Lumina Search is the universal entry point for every action, destination, file, and command in the Lumina platform. It is the answer to every "where do I go to do X?" question. Inspired by Spotlight, Raycast, Alfred, Android Universal Search, and GNOME Search, it combines indexed local search with live computation, system-awareness, and AI augmentation into a single invocation.

This is the most important discoverability surface in the platform. If Settings Studio is the cathedral, Lumina Search is the door to every room.

#### User Value

- **New users** type "blur" and find Glass Mode in Settings Studio without knowing the terminology
- **Power users** type "ks firefox" and switch to their Firefox window without touching the mouse
- **Everyday users** type "volume 50" and the system executes it without navigating anywhere
- **Curious users** type "what is mood?" and get a plain-language explanation with a link to the Settings Studio page

Lumina Search eliminates the distinction between "I need to configure something" and "I need to do something." Both are one SUPER+SPACE away.

#### Relationship to Other Systems

Lumina Search is the **discovery layer over every other system**:

| Plugin | Indexes | Source |
|--------|---------|--------|
| Apps | All installed applications | `.desktop` files |
| Settings | Every settings page and section | Settings Studio manifest |
| Files | Home directory and configured roots | inotify-updated index |
| Keybinds | All binds.conf entries | Keybind Overlay parser |
| Clipboard | Recent clipboard entries | Clipboard Center |
| Windows | All open windows by title + class | Hyprland IPC |
| Commands | Shell scripts in `~/.local/bin` | Directory scan |
| Calculator | Math expressions | Python `eval` sandbox |
| AI | Open-ended questions | Ollama / Gemma API (optional) |
| Lumina Actions | Platform-specific actions | Hardcoded manifest |

#### Search Philosophy

Lumina Search is itself a discoverability tool and requires minimal additional discoverability:
- SUPER+SPACE is the first keybind introduced in the onboarding wizard
- The wizard includes an animated demo of typing "glass" and seeing Settings Studio appear
- Any Lumina toast that contains an actionable item includes a "Search for this" button
- Keybind Overlay lists "SUPER+SPACE — Lumina Search" as the first entry in every category

#### Future Expansion Path

- Plugin API: third-party apps register search plugins via D-Bus manifest
- Saved searches / bookmarks: pin a result for instant re-access
- Remote search: optional sync with a Nextcloud/Syncthing instance for cross-device results
- Voice input: "Hey Lumina" hotword via local Vosk model, feeds query to Lumina Search
- Natural language actions: "turn off notifications for the next 2 hours" → DND timer

---

## PART IV — A-TIER: DAILY EXPERIENCE SYSTEMS

A-Tier systems are not load-bearing but are high-frequency user-facing features. They depend on S-Tier systems being stable and must integrate with them fully.

### A-01 — Music Center
**Keybind:** `SUPER + M` | **App ID:** `dev.lumina.music-center` | **Backend:** MPRIS D-Bus interface

> **Architecture Review Note:** Not yet built. MPRIS D-Bus binding is well-documented; medium effort.

Music Center is a unified music control surface that bridges any MPRIS-compatible player (Spotify, Rhythmbox, MPD, browser tab) into the Lumina design language. It provides now-playing information, transport controls, and queue management in a single GTK4 window.

**User Value:** Users control music without switching apps. The now-playing state is visible in Control Center. Track changes are logged in Activity Timeline. The current artist or album cover can optionally drive the Mood Engine.

**Relationship to Other Systems:** Control Center (Row 5 music display), Activity Timeline (track change events), Mood Engine (optional genre → mood suggestion), Action Feedback Toasts (track change toasts).

**Future Expansion Path:** Last.fm scrobbling, local library browser via MPD, mood-from-music genre analysis.

---

### A-02 — Clipboard Center
**Keybind:** `SUPER + V` | **App ID:** `dev.lumina.clipboard-center` | **Backend:** `cliphist` daemon

> **Architecture Review Note:** Not yet built as a UI. `cliphist` backend likely exists in the system.

Clipboard Center is a searchable history of everything the user has copied. It replaces the ephemeral single-item clipboard with a persistent, searchable, type-aware archive.

**User Value:** "I copied something 20 minutes ago — where is it?" is one of the most common productivity frustrations. Clipboard Center answers that question instantly.

**Relationship to Other Systems:** Lumina Search (clipboard plugin), Action Feedback Toasts ("View in Clipboard Center" action), Glass Engine (window uses current glass mode), Design System (standard tokens).

**Future Expansion Path:** Cross-device clipboard sync via Syncthing, clipboard macros for text expansion.

---

### A-03 — Widget Engine
**Config:** `~/.config/lumina/widgets.json` | **App ID:** `dev.lumina.widget-engine`

> **Architecture Review Note:** Not yet built. Largest A-tier item; requires one GTK4 layer-shell window per widget.

The Widget Engine renders persistent information overlays on the desktop surface: clock, calendar, system stats, weather, media info, and custom data displays. All widgets use Design System token set and Glass Engine.

**User Value:** Information that would otherwise require opening an app is visible at a glance on the desktop, styled to match the current mood and theme.

**Relationship to Other Systems:** Design System (CSS custom properties), Glass Engine (surface styling), Mood Engine (clock style follows mood clock preference), Settings Studio → Widgets page, Activity Timeline.

**Future Expansion Path:** Widget API for third-party apps, BPM-reactive animations, scripted widgets as Python functions.

---

### A-04 — Lock Screen Studio
**Config:** `~/.config/lumina/lockscreen.json` | **Underlying tool:** `hyprlock`

> **Architecture Review Note:** `hyprlock` exists. Config generation script is the missing piece.

Lock Screen Studio manages the appearance and behavior of the Hyprlock lock screen, translating Mood Engine state, Design System tokens, and user preferences into a regenerated `hyprlock.conf`.

**User Value:** The lock screen feels like a premium, intentional experience — not an afterthought. It matches the user's current mood.

**Relationship to Other Systems:** Mood Engine (`MOOD_CLOCK_STYLE` mapping), Design System (token-derived colors), Wallpaper Experience (blurred background), Glass Engine (input card surface).

---

### A-05 — Gesture Engine
**Config:** `~/.config/lumina/gestures.json` | **Service:** `lumina-gestures.service`

> **Architecture Review Note:** Partial. `libinput-gestures` config likely exists. The `gestures.json` abstraction layer is new.

The Gesture Engine translates `gestures.json` (user-editable, human-readable) into a `libinput-gestures.conf` that the daemon consumes, making gestures configurable through Settings Studio without manual config file editing.

**User Value:** Users navigate their desktop without lifting hands to the keyboard. Workspace switching, Mission Control, and Control Center are all one gesture away.

**Relationship to Other Systems:** Mission Control (3-finger swipe up), Control Center (4-finger swipe down), Lumina Hub (4-finger swipe up), Settings Studio → Gestures page.

---

### A-06 — Context Menu System
**Backend:** GTK4 `Gtk.PopoverMenu` + `Gio.MenuModel`

> **Architecture Review Note:** Not yet built. Requires a transparent GTK4 desktop overlay window.

The Context Menu System provides a consistent, glass-styled right-click contextual menu across all Lumina GTK4 applications and the desktop surface.

**User Value:** Right-clicking in any Lumina context produces a menu that feels part of the same design language: same border radius, same glass surface, same font, same hover state.

**Relationship to Other Systems:** Design System (radius + color tokens), Glass Engine (popover surface), Wallpaper Experience ("Set as Wallpaper" on desktop), Lumina Search (Actions results).

---

### A-07 — Action Feedback Toasts
**Backend module:** `apps/lib/lumina_core/toasts.py`

> **Architecture Review Note:** `notify-send` is used ad-hoc today. Needs `lumina_core/toasts.py` formalization.

Every user-visible action in the Lumina platform produces a brief, non-blocking feedback notification. This is not optional — silence after an action is a bug. Toasts confirm that the system heard the user and did something.

**User Value:** Users know when actions succeed or fail. "Glass mode: Crystal applied" is more informative than silence. "Error: gesture config invalid — check Settings" is more actionable than a terminal error.

**Philosophy:** Toast is the universal feedback primitive. Every system in the platform calls `toast()` or emits a D-Bus toast signal.

---

### A-08 — Battery Analytics
**App ID:** `dev.lumina.battery-analytics` | **Service:** `lumina-battery-logger.service`

> **Architecture Review Note:** Not yet built. Battery logger script is trivial; the GTK4 chart UI is medium effort.

Battery Analytics monitors battery health, charge cycles, and discharge rate, providing actionable intelligence and automatically triggering power-saving behavior at configured thresholds.

**User Value:** Users know their battery will last 2.5 more hours before sitting down to a 3-hour meeting. They know if their battery health is degrading.

**Relationship to Other Systems:** Glass Engine (triggers minimal on low battery), Mood Engine (suggests power-appropriate moods), Action Feedback Toasts (low battery warning), Activity Timeline (battery state logging), Control Center (battery display in Row 1).

---

## PART V — B-TIER: PRODUCTIVITY SYSTEMS

### B-01 — Screenshot Studio
**Keybind:** `PRINT` / `SUPER + PRINT` / `SHIFT + PRINT` | **Backend:** `grim` + `slurp`

> **Architecture Review Note:** `grim` + `slurp` exist. The annotation overlay is the new piece.

A capture-and-annotate tool that integrates with the Lumina clipboard and Design System. Replaces raw `grim | slurp` invocations with a polished capture experience including crop, annotation, and blur region tools.

**Relationship to Other Systems:** Action Feedback Toasts, Clipboard Center (auto-add captured image), Lumina Search ("screenshot" triggers capture mode).

---

### B-02 — Session Restoration
**Service:** `lumina-session.service` | **Config:** `~/.config/lumina/session.json`

> **Architecture Review Note:** Not yet built. **Known Wayland limitation:** Restoring app geometry requires apps to cooperate. Many apps (Electron, Firefox) don't save and restore geometry reliably via Wayland. Expect ~70% app coverage; some apps will silently fail to restore position.

Session Restoration saves and restores the workspace layout (which apps are open, on which workspace, at which size and position) across reboots and Hyprland restarts.

**User Value:** Rebooting after an update doesn't mean starting from scratch.

---

### B-03 — Activity Timeline
**App ID:** `dev.lumina.activity-timeline` | **Data:** `~/.local/state/lumina/activity.jsonl`

> **Architecture Review Note:** `apps/activity-history/` exists. May need alignment with the spec's JSONL format.

A chronological record of the user's session: focus periods, app usage, music, and battery events.

**User Value:** Users see how they spent their day without requiring a SaaS subscription.

---

### B-04 — Scratchpad System
**Keybind:** `SUPER + GRAVE` (toggle), `SUPER + SHIFT + GRAVE` (move to scratchpad)

A named special workspace (`scratch`) that floats above all other workspaces. A persistent parking lot for notes, calculations, and temporary windows.

> **Architecture Review Note:** Native Hyprland feature. Just keybind config.

---

### B-05 — Focus Mode
**Keybind:** `SUPER + SHIFT + F` | **Shell accessor:** `lumina-focus`

> **Architecture Review Note:** `apps/pomodoro/` exists and maps to this. Needs to be wired to glass + ambient systems.

A coordinated distraction-reduction state: enables Do Not Disturb, reduces animation speed, switches to a calmer glass mode, optionally starts a focus-appropriate ambient sound pack.

**User Value:** One keybind transforms the desktop from a general environment into a focused work environment.

**Relationship to Other Systems:** Glass Engine (shifts to `material`), Mood Engine (temporary mood override), Ambient Sounds (focus sound pack), Activity Timeline (focus session logging), Control Center (Focus toggle).

---

### B-06 — Window Teleportation
**Keybind:** `SUPER + SHIFT + [1-9]`, `SUPER + SHIFT + ARROW`

> **Architecture Review Note:** Native Hyprland feature. Just keybind config.

The set of keybinds and gestures that move the focused window to another workspace, monitor, or position — without releasing focus.

---

## PART VI — C-TIER: PLATFORM SERVICES

### C-01 — Theme Studio
**App ID:** `dev.lumina.theme-studio`

> **Architecture Review Note:** `apps/theme-studio/` exists. Verify that token-level editing is present.

An advanced GTK4 application for users who want manual token-level control over the Design System output. Exposes every token as an editable field, shows a live preview, and writes `palette-overrides.json`. Power users craft custom color palettes and export them as `.lumina-theme` files.

---

### C-02 — App Center
**App ID:** `dev.lumina.app-center` | **Backend:** `pacman` + `paru` + `flatpak`

> **Architecture Review Note:** Not yet built. pacman/paru/flatpak GUI is significant effort.

A GUI wrapper over the package manager that allows users to discover, install, and remove applications without terminal access. The package manager remains the ground truth; App Center is a UI layer.

---

### C-03 — Update Center
**App ID:** `dev.lumina.update-center` | **Service:** `lumina-update-checker.timer`

> **Architecture Review Note:** `update.sh` exists. A GUI wrapper is needed.

Manages Lumina dotfile updates, package updates, and Hyprland plugin updates through a single interface. Distinguishes between platform updates (dotfiles), system updates (pacman), and AUR updates.

---

## PART VII — D-TIER: ENHANCEMENTS

D-Tier features are experience enhancements. They depend on all S-Tier and A-Tier systems being stable. They must degrade gracefully (disable themselves) when Glass Engine is in `minimal` mode or when `battery_mode` is active.

### D-01 — Animated Wallpapers
**Backend:** `mpvpaper` + `swww` hybrid

> **Architecture Review Note:** Partially existing. `mpvpaper` integration needs a Settings Studio hook.

Renders video or shader-based backgrounds using `mpvpaper`. Automatically activated when a video file is set as wallpaper. Respects glass mode: in `minimal` mode, animated wallpapers freeze to their first frame.

---

### D-02 — Ambient Sounds
**Backend:** `mpv` (headless) | **Service:** `lumina-ambient.service`

> **Architecture Review Note:** Not yet built as a service. The `mpv` loop script is trivial; Settings Studio integration is new.

Plays looping background audio (nature, rain, brown noise, lo-fi, café) coordinated with Mood Engine state and Focus Mode. Pauses automatically when Music Center begins MPRIS playback.

---

### D-03 — Ultra Minimal Mode
**Keybind:** `SUPER + SHIFT + M` | **Shell accessor:** `lumina-minimal`

> **Architecture Review Note:** Not yet built. Shell script is trivial; state persistence (pre-minimal-state.json) is the key concern.

Disables every non-essential visual element simultaneously: animations off, glass minimal, wallpaper solid color, widgets hidden, bar reduced to workspace indicator only.

**User Value:** Maximum screen space and minimum GPU load. Presentation mode. Recovery mode on low-resource hardware.

---

## PART VIII — PLATFORM COHESION REQUIREMENTS (Philosophy)

### 8.1 Discoverability Philosophy

Every user-facing feature must be discoverable through at least three of the following four paths:

| Path | Description |
|------|-------------|
| **Lumina Search** | Typing the feature name or a related word returns it as a top result |
| **Settings Studio** | The feature has at least one configurable option in Settings Studio |
| **Control Center** | The feature has a quick toggle or status display in Control Center |
| **Keybind Overlay** | The feature's keybind appears in the appropriate category |

Features with no user-visible controls (Design System, backend services) are exempt.

### 8.2 Feedback Philosophy

Every user-visible state change must emit a toast notification. The following are **never acceptable**:
- Silent failure (action runs, nothing happens, no feedback)
- Silent success (action runs, succeeds, user must infer from visual change)
- Error messages shown only in the terminal

Every action must produce output in the form of a toast. Every error must produce a toast with a suggested next step.

### 8.3 Accessibility Philosophy

Every GTK4 application must:
- Be fully operable without a mouse
- Have accessible names on all interactive elements
- Respect `prefers-reduced-motion` (disable non-essential animations)
- Pass WCAG AA contrast for all text-on-surface combinations at every glass mode
- Announce state changes to screen readers via AT-SPI

### 8.4 Performance Philosophy

Performance targets are specific enough to test. "Should feel fast" is not a target. Each bound is measurable.

| Metric | Limit |
|--------|-------|
| Any keybind to visible window | ≤ 80 ms |
| Settings write to confirmation toast | ≤ 200 ms |
| Theme regeneration (Matugen) | ≤ 2,000 ms |
| Glass mode change (all surfaces) | ≤ 500 ms |
| Mood apply (all systems) | ≤ 500 ms |
| Lumina Search first result | ≤ 50 ms |
| Token CSS provider reload | ≤ 50 ms |
| App launch (any Lumina app) | ≤ 400 ms |

> **Architecture Review Note:** The ≤80ms keybind-to-window constraint requires all overlay windows (Control Center, Search, Keybind Overlay) to be pre-rendered and hidden — not spawned on demand. This is an implementation constraint, not just a target.

### 8.5 Configuration File Philosophy

All configuration is JSON, lives in `~/.config/lumina/`, has a schema, is written atomically, and emits a D-Bus signal. There is one config file per system, never one per feature.

### 8.6 No Configuration Sprawl Philosophy

A "configuration sprawl" violation is any situation where:
- A setting requires editing a file not exposed in Settings Studio
- A user must run a shell script manually to accomplish something Settings Studio can do
- Two features expose the same conceptual setting through different UI surfaces
- A feature can only be configured by editing comments in a Hyprland config file

If a violation is found during implementation, the fix is to add the setting to Settings Studio — not to add documentation explaining the manual approach.

---

## APPENDIX C — GLOSSARY

| Term | Definition |
|------|------------|
| **Token** | A named CSS custom property derived from the Design System (e.g. `--color-primary`) |
| **Glass mode** | One of five named configurations of the Glass Engine (Crystal, Frosted, Mica, Material, Minimal) |
| **Mood** | One of eight named Mood Engine states that coordinate visual, audio, and behavioral settings |
| **Toast** | A brief, non-blocking notification confirming a user action |
| **Layer-shell** | A Wayland protocol (`zwlr_layer_shell_v1`) for rendering windows outside the normal compositor stack (used by Control Center, Keybind Overlay, Lumina Search) |
| **LuminaApplication** | The base Python class (`apps/lib/lumina_core/app.py`) that all Lumina GTK4 apps extend |
| **Codebase contract** | The set of architectural rules in this document that no new code may violate |
| **Configuration sprawl** | The anti-pattern where user preferences are distributed across multiple config files, scripts, or settings surfaces with no single entry point |
| **Atomic write** | Writing a file via a `.tmp` intermediary and `os.rename()` to prevent partial reads |
| **Deep link** | A CLI invocation of a Settings Studio page that navigates directly to a specific section |

---

*Lumina Platform Architecture — Vision and Structure*
*Pair with: `RULES.md` and `IMPLEMENTATION_REFERENCE.md`*
