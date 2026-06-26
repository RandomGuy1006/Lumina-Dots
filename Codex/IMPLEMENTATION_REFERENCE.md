# LUMINA IMPLEMENTATION REFERENCE
## Complete Technical Specifications for All Platform Systems

**Document Class:** Implementation Reference — Technical Specifications
**Scope:** All platform layers, S-Tier through D-Tier
**Pair Documents:** `ARCHITECTURE.md` (vision), `RULES.md` (platform constitution)
**Audience:** Platform engineers building, debugging, or extending Lumina systems

> This document contains every technical detail needed to implement any Lumina system.
> It is not a design document. Refer to `ARCHITECTURE.md` for WHY systems exist.
> Refer to `RULES.md` for invariants that constrain HOW they are built.

---

## BUILD STATUS MAP (Architecture Review 2026-06-22)

| System | Directory | Status |
|--------|-----------|--------|
| S-01 Settings Studio | `apps/settings-studio/` | ❌ Does not exist — highest priority |
| S-02 Design System | `apps/lib/lumina_core/theme.py` | ⚠️ Partial — `matugen/` exists, Python API missing |
| S-03 Glass Engine | `apps/lib/lumina_core/glass.py` | ⚠️ Partial — scripts exist, not formalized |
| S-04 Theme Engine | `apps/lib/lumina_core/theme.py` | ⚠️ Partial — `scripts/apply-theme.sh` exists |
| S-05 Mood Engine | `apps/lib/lumina_core/mood.py` | ❌ Not formalized |
| S-06 Control Center | `apps/control-center/` | ✅ Exists — needs D-Bus wiring |
| S-07 Wallpaper Experience | `scripts/wallpaper-apply.sh` | ⚠️ Partial — cascade not formalized |
| S-08 Mission Control | `apps/mission-control/` | ✅ Exists — verify plugin installed |
| S-09 Keybind Overlay | `apps/keybind-overlay/` | ✅ Exists — add comment convention to binds.conf |
| S-10 Lumina Search | `walker/` (placeholder) | ⚠️ Walker stand-in — custom daemon needed |
| A-01 Music Center | `apps/music-center/` | ❌ Not built |
| A-02 Clipboard Center | `apps/clipboard-center/` | ❌ Not built (cliphist backend likely exists) |
| A-03 Widget Engine | `apps/widget-engine/` | ❌ Not built |
| A-04 Lock Screen Studio | `hyprlock` exists | ⚠️ Config generation script needed |
| A-05 Gesture Engine | `scripts/system/` | ⚠️ Partial — `gestures.json` abstraction new |
| A-06 Context Menu | — | ❌ Not built |
| A-07 Toasts | `notify-send` ad-hoc | ⚠️ Needs `lumina_core/toasts.py` |
| A-08 Battery Analytics | `apps/battery-analytics/` | ❌ Not built |
| B-01 Screenshot Studio | `grim`+`slurp` exist | ⚠️ Annotation overlay new |
| B-02 Session Restoration | — | ❌ Not built (Wayland geometry caveat) |
| B-03 Activity Timeline | `apps/activity-history/` | ✅ Exists — align JSONL format |
| B-04 Scratchpad | native Hyprland | ✅ Keybind config only |
| B-05 Focus Mode | `apps/pomodoro/` | ⚠️ Needs glass + ambient wiring |
| B-06 Window Teleportation | native Hyprland | ✅ Keybind config only |
| C-01 Theme Studio | `apps/theme-studio/` | ✅ Exists — verify token editing |
| C-02 App Center | — | ❌ Not built |
| C-03 Update Center | `update.sh` exists | ⚠️ GUI wrapper needed |
| D-01 Animated Wallpapers | `mpvpaper` partial | ⚠️ Settings Studio hook needed |
| D-02 Ambient Sounds | — | ❌ Not built as service |
| D-03 Ultra Minimal Mode | — | ❌ Not built (script trivial) |

**First implementation moves (from review):**
1. Create `apps/lib/lumina_core/` — `glass.py`, `theme.py`, `toasts.py`, `app.py`
2. Formalize `glass.json` + Glass Engine — encode 5-preset table, generate `glass-rules.conf`
3. Build Settings Studio skeleton — Appearance page first
4. Formalize D-Bus interface — write `dev.lumina.core` service descriptor
5. Mood Engine — write `mood.py` with 8 profiles, wire to wallpaper-apply.sh

---

## PART I — SHARED LIBRARY: `apps/lib/lumina_core/`

This library must exist before any new Lumina GTK4 application is built. Every app imports from here.

### `lumina_core/app.py` — Base Application Class

```python
# LuminaApplication — base class for all Lumina GTK4 apps

class LuminaApplication(Adw.Application):
    def load_css(self) -> None:
        """
        Inject Design System tokens + Glass Engine CSS into GTK4 CSS provider.
        Called at startup and whenever dev.lumina.settings.Changed is emitted.
        Uses priority=Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION.
        Must not cause a perceptible flash during reload.
        """
```

### `lumina_core/theme.py` — Design System + Theme Engine API

```python
# Public API

FALLBACK_TOKENS: dict  # hardcoded Material You Dark defaults

def load_tokens() -> dict:
    """Read visual-tokens.json. Returns FALLBACK_TOKENS if missing."""

def tokens_to_css(tokens: dict) -> str:
    """Convert token dict to :root { --token: value; } CSS block."""

def tokens_to_hypr(tokens: dict) -> str:
    """Convert token dict to Hyprland color assignments."""

def regenerate_tokens(
    wallpaper_path: str | None,
    overrides: dict | None = None,
    color_temperature: int = 6500,
) -> dict:
    """
    1. Run Matugen on wallpaper_path (or fallback palette if None)
    2. Apply color_temperature shift via hyprsunset
    3. Apply overrides from palette-overrides.json
    4. Validate contrast ratios (WCAG AA)
    5. Write visual-tokens.json atomically
    6. Emit dev.lumina.settings.Changed on D-Bus
    7. Return final token dict
    """

def apply_hypr_colors(tokens: dict) -> None:
    """Write tokens-colors.conf and call hyprctl reload."""

def apply_gtk_theme(tokens: dict) -> None:
    """Update GTK CSS provider in all running LuminaApplication instances via D-Bus."""
```

### `lumina_core/glass.py` — Glass Engine API

```python
class GlassMode(str, Enum):
    CRYSTAL  = "crystal"   # max blur, near-transparent
    FROSTED  = "frosted"   # standard blur, soft opacity (default)
    MICA     = "mica"      # subtle blur, tinted
    MATERIAL = "material"  # minimal blur, opaque
    MINIMAL  = "minimal"   # no blur, solid surface

@dataclass(frozen=True)
class GlassConfig:
    mode: GlassMode
    blur_size: int        # 0–40
    blur_passes: int      # 1–5
    opacity: float        # 0.0–1.0
    saturation: float     # 0.8–2.0
    tint_color: str       # hex
    noise: float          # 0.0–0.08
    brightness: float     # 0.7–1.2
    performance_mode: bool
    battery_mode: bool

GLASS_PRESETS: dict[GlassMode, GlassConfig]  # canonical preset values

def load_glass_config() -> GlassConfig: ...
def save_glass_config(cfg: GlassConfig) -> None: ...
def glass_css(cfg: GlassConfig) -> str: ...
def apply_glass_layerrules(cfg: GlassConfig, classes: list[str]) -> None: ...
def glass_classes() -> list[str]: ...
```

**Glass Preset Values:**

| Mode | blur | passes | opacity | sat | noise | bright |
|------|------|--------|---------|-----|-------|--------|
| crystal | 28 | 4 | 0.55 | 1.4 | 0.025 | 0.95 |
| frosted | 20 | 3 | 0.72 | 1.2 | 0.018 | 0.90 |
| mica | 12 | 2 | 0.85 | 1.0 | 0.012 | 0.88 |
| material | 6 | 1 | 0.92 | 0.9 | 0.006 | 1.00 |
| minimal | 0 | 0 | 1.00 | 1.0 | 0.000 | 1.00 |

When `performance_mode=True`: halve `blur_size` and `blur_passes`.
When `battery_mode=True`: force `minimal` regardless of stored mode (but do not overwrite `glass.json`).

### `lumina_core/mood.py` — Mood Engine API

```python
class Mood(str, Enum):
    CYBERPUNK = "cyberpunk"
    NATURE    = "nature"
    OCEAN     = "ocean"
    DARK      = "dark"
    WARM      = "warm"
    MINIMAL   = "minimal"
    SPACE     = "space"
    RETRO     = "retro"

@dataclass(frozen=True)
class MoodProfile:
    emoji: str
    display_name: str
    glass_mode: GlassMode
    sound_pack: str | None
    color_temperature: int     # Kelvin
    clock_style: str
    motion_speed: float        # multiplier
    wallpaper_hint: str        # aesthetic hint for wallpaper auto-detect

MOOD_PROFILES: dict[Mood, MoodProfile]

def apply_mood(
    mood: Mood,
    auto_sound: bool = True,
    auto_glass: bool = True,
    auto_clock: bool = True,
) -> None:
    """Coordinate all systems for the given mood."""

def detect_mood_from_wallpaper(wallpaper_path: str) -> Mood:
    """Analyze dominant color palette and return closest mood."""

def current_mood() -> Mood:
    """Read mood.json and return current mood."""
```

### `lumina_core/toasts.py` — Toast API

```python
ICON_MAP = {
    "info":    "dialog-information-symbolic",
    "success": "emblem-ok-symbolic",
    "warning": "dialog-warning-symbolic",
    "error":   "dialog-error-symbolic",
}

def toast(
    message: str,
    subtitle: str = "",
    category: str = "info",
) -> None:
    """Emit a system notification via dev.lumina.toast.Send."""

class LuminaToastOverlay:
    """Wraps Adw.ToastOverlay for in-app use."""
    def __init__(self, child: Gtk.Widget): ...
    def toast(self, message: str, timeout: int = 2, action_label: str = "", action_callback=None) -> None: ...
    @property
    def widget(self) -> Adw.ToastOverlay: ...
```

**Toast duration by category:**
- `info` — 2 seconds
- `success` — 2 seconds
- `warning` — 4 seconds
- `error` — 6 seconds (persists until dismissed)

---

## PART II — S-TIER IMPLEMENTATION SPECIFICATIONS

---

### S-01 — Settings Studio

**App ID:** `dev.lumina.settings-studio`
**Config written:** All platform config files
**Backend module:** None (orchestrates all other modules)

#### Required Backend Architecture

```
dev.lumina.settings-studio (GTK4 process)
    ├── Reads: all config files under ~/.config/lumina/
    ├── Writes: config files, then emits dev.lumina.settings.Changed
    ├── Validates: all writes against JSON schema before saving
    ├── History: maintains undo stack (last 10 changes per session)
    └── Search endpoint: exposes settings page manifest for Lumina Search
```

**Config validation:** Every settings page has a corresponding JSON schema in `apps/settings-studio/schemas/`. A write that fails schema validation is rejected with an in-app error toast. Schemas are versioned; migration functions run automatically on first launch after an update.

**Undo/redo:** Settings Studio maintains an in-memory undo stack. `CTRL+Z` reverts the last change within the current session. Each undo operation writes the previous value back, emits the change signal, and shows a toast: "Reverted: Glass Mode → Frosted."

#### Required UI Surfaces

**Primary window:** `Adw.ApplicationWindow` with `Adw.NavigationSplitView`
- Left sidebar: category list (Appearance, Wallpaper, Mood, Animations, Gestures, Widgets, Audio, Notifications, Lumina Search, AI, Battery, Performance, Updates, Recovery)
- Right content: `Adw.PreferencesPage` for selected category
- Header: search field that filters settings across all pages (client-side, instant)

**Deep-link support:** Every settings section is addressable via CLI: `lumina-settings-studio --page=<page> --section=<section>`. Lumina Search uses this to navigate directly to any setting.

**Onboarding overlay:** On first launch, an `Adw.Dialog` overlay runs the Lumina Setup Wizard (see §S-01-OB in `ARCHITECTURE.md`).

#### Settings Pages — Full Specification

**Appearance**
- Glass Mode: `Adw.ComboRow` (Crystal / Frosted / Mica / Material / Minimal) → writes `glass.json`, emits glass changed signal, triggers compositor reload, shows toast
- Accent Color: `Adw.ActionRow` + `Gtk.ColorButton` → writes `palette-overrides.json`, re-runs token generation, shows preview chip
- Icon Theme: `Adw.ComboRow` (discovered via `find /usr/share/icons -mindepth 1 -maxdepth 1 -type d`) → `gsettings set org.gnome.desktop.interface icon-theme`
- Cursor Theme: `Adw.ComboRow` (same discovery) → `gsettings set org.gnome.desktop.interface cursor-theme`
- Font: `Adw.ActionRow` with font chooser popover → writes fontconfig template, regenerates
- Lock Screen section:
  - Clock style: `Adw.ComboRow` (6 styles)
  - Auto-set from mood: `Adw.SwitchRow`
  - Show battery on lock screen: `Adw.SwitchRow`
  - Show date: `Adw.SwitchRow`
  - Blur strength: `Adw.ScaleRow` (0–10)

**Wallpaper**
- Wallpaper Directory: `Adw.EntryRow` with folder picker button → writes to host profile
- Auto-rotate: `Adw.SwitchRow` → enables/disables `lumina-wallpaper-rotate.timer`
- Rotation Interval: `Adw.SpinRow` (5–1440 min) — only visible when auto-rotate is on
- Animated Wallpaper Support: `Adw.SwitchRow` → toggles mpvpaper mode
- Transition Style: `Adw.ComboRow` (Fade / Zoom / Wipe / None)

**Mood**
- Current Mood: `Adw.ActionRow` showing current mood name + emoji, tap to open mood picker dialog (8 moods as a card grid)
- Auto-detect from wallpaper: `Adw.SwitchRow`
- Auto-start ambient sound: `Adw.SwitchRow`
- Auto-set clock style: `Adw.SwitchRow`
- Auto-adjust glass mode: `Adw.SwitchRow`
- Color temperature: `Adw.SpinRow` (2700–6500 K, only when mood auto-detect is off)

**Animations**
- Enable animations: `Adw.SwitchRow` (master kill-switch)
- Animation speed: `Adw.ScaleRow` (0.5×–3.0×) → writes motion token multiplier
- Reduce motion: `Adw.SwitchRow` (forces 0.1× and disables non-essential animations)

**Gestures**
- Each gesture slot shows action name + current binding in an `Adw.EntryRow`
- "Save and Reload" button at bottom of page
- "Reset to Defaults" button

**Lumina Search**
- Keyboard shortcut: `Adw.ShortcutRow` (default: SUPER+SPACE)
- Plugins enabled: `Adw.ExpanderRow` for each plugin (Apps, Settings, Files, Commands, Keybinds, Clipboard, Calculator, AI)
- File search roots: `Adw.EntryRow` list of directories
- Show recent files: `Adw.SwitchRow`
- Calculator precision: `Adw.SpinRow`
- AI search backend: `Adw.ComboRow` (None / Ollama / Gemma API)
- AI model: `Adw.EntryRow` (visible when AI enabled)
- Maximum results per plugin: `Adw.SpinRow` (3–10)

**Widgets**
- Active widgets list with `Adw.SwitchRow` per widget
- "Add Widget" → opens widget picker overlay
- Per-widget: long-press row → configuration popover

**Audio**
- Default output: `Adw.ComboRow` (populated from `wpctl status`)
- Startup ambient sound: `Adw.SwitchRow` + pack selector `Adw.ComboRow`
- Music Center: toast on track change `Adw.SwitchRow`; startup behavior `Adw.ComboRow`

**Notifications**
- Do Not Disturb: `Adw.SwitchRow`
- Toast duration: `Adw.SpinRow` (1–10 s)
- Toast position: `Adw.ComboRow` (top-right / bottom-right / top-center)
- "Show toasts for glass changes" `Adw.SwitchRow`
- "Show toasts for mood changes" `Adw.SwitchRow`
- Clipboard history: On/Off `Adw.SwitchRow`
- Maximum clipboard entries `Adw.SpinRow` (50–500)
- Include images `Adw.SwitchRow`
- Auto-clear after `Adw.ComboRow` (Never / 1 day / 1 week / 1 month)
- Control Center position `Adw.ComboRow` (top-right / top-left / bottom-right / bottom-left / bottom-center)

**AI**
- Backend: `Adw.ComboRow` (None / Ollama / Gemma API)
- Model: `Adw.EntryRow`
- API Key: `Adw.PasswordEntryRow`
- "Test Connection" button → runs inference with "hello" prompt, shows latency toast

**Battery**
- Battery logger: `Adw.SwitchRow` → enables `lumina-battery-logger.service`
- Low battery alert threshold: `Adw.SpinRow` (5–30%)
- Auto-enable minimal glass on battery: `Adw.SwitchRow`
- Auto-disable animations on battery: `Adw.SwitchRow`

**Performance**
- Glass mode on battery: `Adw.ComboRow` (override when on battery)
- Disable animations on battery: `Adw.SwitchRow`
- Compositor hints: `Adw.SwitchRow` (enables `misc:vfr = true` in hyprland.conf)

**Focus (under Productivity)**
- Focus glass mode: `Adw.ComboRow`
- Focus ambient sound: `Adw.ComboRow` (None + available packs)
- Disable notifications: `Adw.SwitchRow`
- Focus duration reminder: `Adw.SpinRow` (0 = no reminder, 25 = Pomodoro default)

**Updates**
- Check for updates: button → runs `update.sh --dry-run`, shows results dialog
- Auto-update: `Adw.SwitchRow` → enables `lumina-update.timer`
- Update channel: `Adw.ComboRow` (Stable / Beta)

**Recovery**
- View snapshots: button → opens `lumina-snapshot-manager`
- Create snapshot now: button → runs `dotfiles backup` with progress dialog
- Emergency recovery: button → opens step-by-step recovery guide dialog

#### Accessibility Implementation Requirements

- All `Adw.PreferencesRow` subclasses carry full `accessible-name` and `accessible-description`
- Keyboard navigation: Tab moves between rows, Enter activates, Space toggles switches
- Color contrast: all text on glass surfaces meets WCAG AA minimum (4.5:1)
- Font size follows GNOME accessibility settings; no hardcoded sizes

#### Performance Budgets

- Settings Studio must launch within 400 ms (measured from keybind to visible window)
- Settings writes must complete within 100 ms before showing the confirmation toast
- The search filter within the app must respond within 16 ms (one frame at 60 Hz)
- Config files are written atomically: write to `.tmp`, then `os.rename()` to final path

---

### S-02 — Design System

**Config file:** `~/.cache/lumina/visual-tokens.json`
**Backend module:** `apps/lib/lumina_core/theme.py`

#### Token Taxonomy — Full Specification

**Color tokens** (generated by Theme Engine from Matugen)
```css
--color-primary          /* dominant accent */
--color-primary-variant  /* darker/lighter accent */
--color-secondary        /* supporting accent */
--color-surface          /* window background (before glass) */
--color-surface-variant  /* subtle differentiation (cards within windows) */
--color-on-surface       /* text/icons on surface */
--color-outline          /* borders */
--color-outline-variant  /* subtle borders */
--color-error            /* error states */
```

**Glass tokens** (generated by Glass Engine)
```css
--glass-bg               /* rgba(surface-rgb, opacity) */
--glass-blur             /* reference value (px); actual blur via Hyprland layerrule */
--glass-noise            /* 0.0–0.08 film grain */
--glass-border           /* rgba(255,255,255, border-alpha) */
--glass-tint             /* rgba(primary-rgb, tint-alpha) */
--glass-bright           /* brightness multiplier */
```

**Motion tokens**
```css
--motion-speed           /* multiplier (0.1–3.0) */
--motion-easing-standard /* cubic-bezier(0.4, 0, 0.2, 1) */
--motion-easing-enter    /* cubic-bezier(0.0, 0.0, 0.2, 1) */
--motion-easing-exit     /* cubic-bezier(0.4, 0.0, 1, 1) */
--motion-easing-spring   /* cubic-bezier(0.22, 1, 0.36, 1) */
--motion-duration-short  /* 150ms × speed */
--motion-duration-medium /* 280ms × speed */
--motion-duration-long   /* 450ms × speed */
```

**Spatial tokens**
```css
--radius-xs   /* 4px */
--radius-sm   /* 8px */
--radius-md   /* 12px */
--radius-lg   /* 18px */
--radius-xl   /* 24px */
--spacing-xs  /* 4px */
--spacing-sm  /* 8px */
--spacing-md  /* 16px */
--spacing-lg  /* 24px */
--spacing-xl  /* 40px */
```

**Typography tokens**
```css
--font-sans    /* Inter, system-ui, -apple-system, sans-serif */
--font-mono    /* JetBrains Mono, Cascadia Code, monospace */
--font-size-sm /* 13px */
--font-size-md /* 15px */
--font-size-lg /* 17px */
--font-size-xl /* 22px */
```

#### Performance Budgets

- Token generation (Matugen run) must complete within 2 seconds
- CSS provider reload must not cause a perceptible flash; inject with `priority=Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION`
- Token files are watched with inotify; reload is debounced by 200 ms to avoid cascade

---

### S-03 — Glass Engine

**Shell accessor:** `lumina-glass`
**Config file:** `~/.config/lumina/glass.json`
**Hyprland output:** `~/.config/hypr/conf.d/glass-rules.conf`
**Backend module:** `apps/lib/lumina_core/glass.py`

#### Required UI Surfaces

No standalone window. Glass Engine surfaces through:
- Settings Studio → Appearance → Glass Mode (full config + presets)
- Control Center → quick glass mode picker (5-button row)
- Lumina Search → "glass" → navigates to Settings Studio glass page

#### Settings Studio Integration — Appearance Page, Glass Mode Section

- `Adw.ComboRow` for mode selection
- `Adw.ExpanderRow` "Advanced" revealing individual sliders for opacity, blur size, noise, brightness
- Live preview panel showing a simulated window at current settings
- "Performance mode" `Adw.SwitchRow` — halves GPU load
- "On battery, use:" `Adw.ComboRow` (overrides active mode when on battery)

#### Control Center Integration

A horizontal 5-icon row of glass mode buttons (Crystal / Frosted / Mica / Material / Minimal). Tapping any calls `lumina-glass set <mode>` and shows a toast.

#### Accessibility Implementation Requirements

- `minimal` mode is never auto-disabled by the system
- Glass mode changes must not cause layout shifts in app content
- Performance mode is automatically recommended (via toast) when frame rate drops below 30 Hz

#### Performance Budgets

- `apply_glass_layerrules()` must complete within 50 ms (file write + `hyprctl reload` is async)
- `glass_css()` is a pure function with no I/O; must return in under 1 ms
- Use `hyprctl --batch` to apply all layerrules atomically

---

### S-04 — Theme Engine

**Shell accessor:** `lumina-theme`
**Config file:** `~/.cache/lumina/visual-tokens.json` (output)
**Input:** `~/.config/lumina/palette-overrides.json`
**Backend module:** `apps/lib/lumina_core/theme.py`

#### `lumina-theme` CLI

```bash
lumina-theme apply [--wallpaper=<path>] [--temperature=<K>]
lumina-theme reset          # removes overrides, re-derives from wallpaper
lumina-theme preview <path> # shows token preview without applying
lumina-theme export         # prints current token set as JSON
```

#### Required UI Surfaces

No standalone window. Surfaces through:
- Settings Studio → Appearance (accent override, wallpaper triggers re-derive)
- Theme Studio (C-Tier) — advanced token editing UI
- Lumina Search → "theme" or "colors"

#### Settings Studio Integration — Appearance Page

- Current primary color as a swatch (derived, not user-set)
- "Override accent" toggle + color picker (`Adw.ActionRow`)
- "Reset to wallpaper colors" button (calls `lumina-theme reset`)

#### Accessibility Implementation Requirements

- All generated token pairs validated for WCAG AA before file is written
- `--high-contrast` flag generates higher-contrast token variant
- User-set overrides that fail contrast validation show a warning toast but are still applied

#### Performance Budgets

- Full Matugen run + token write: under 2 seconds
- `apply_hypr_colors()` + `apply_gtk_theme()` combined: under 500 ms
- Token file is watched with inotify; all consumers reload within 200 ms of file change

---

### S-05 — Mood Engine

**Shell accessor:** `lumina-mood`
**Config file:** `~/.config/lumina/mood.json`
**Backend module:** `apps/lib/lumina_core/mood.py`

#### `lumina-mood` CLI (implied by architecture)

```bash
lumina-mood set <mood>          # apply named mood
lumina-mood detect --wallpaper=<path>  # detect mood and apply if auto-detect on
lumina-mood status              # print current mood
```

#### Mood Profiles Table (Full)

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

#### Required UI Surfaces

- **Mood Picker overlay**: 8 cards in a 4×2 grid, each showing mood name, emoji, and a small color swatch. Available from Control Center, Settings Studio → Mood, and Lumina Search.
- **Control Center row**: "Current mood: 🌊 Ocean" with a tap-to-change affordance
- **Lumina Hub status bar**: mood emoji + name in the status area

#### Settings Studio Integration — Mood Page

- Current mood display with "Change" button
- "Auto-detect from wallpaper" `Adw.SwitchRow`
- "Auto-start ambient sound" `Adw.SwitchRow`
- "Auto-set clock style" `Adw.SwitchRow`
- "Adjust glass mode automatically" `Adw.SwitchRow`
- "Adjust motion speed" `Adw.SwitchRow`
- "Color temperature" `Adw.SpinRow` (only when auto-detect is off)

#### Control Center Integration

Row 1 shows current mood emoji + name. Tapping opens mood picker overlay (8 card grid). Selecting calls `lumina-mood set <mood>` and shows toast.

#### Accessibility Implementation Requirements

- Mood picker cards are keyboard-navigable (arrow keys, Enter to apply)
- Each card has accessible description: "Nature mood: frosted glass, forest sounds, warm motion"
- Mood changes emit a toast announced by screen readers
- All mood transitions respect `prefers-reduced-motion`

#### Performance Budgets

- `apply_mood()` completes within 500 ms (coordinates 4–5 subsystems in parallel via `asyncio.gather`)
- Mood detection from wallpaper runs in a background thread
- Mood picker overlay must appear within 100 ms of trigger

---

### S-06 — Control Center

**App ID:** `dev.lumina.control-center`
**Backend:** GTK4 LayerShell window (`zwlr_layer_surface_v1`, `LAYER_TOP`)

#### Required Backend Architecture

```
lumina-control-center (GTK4, layer-shell)
    ├── D-Bus subscriber: dev.lumina.* (all platform signals)
    ├── D-Bus client: sends commands to subsystems (mood, glass, audio)
    ├── Hyprland IPC: reads workspace + window count
    └── PipeWire: reads audio device + volume
```

#### Required UI Layout

Single GTK4 window with `gtk4-layer-shell`. Dimensions: 360 px wide, auto-height. Anchored to top-right corner. Dismisses on click-outside.

**Row 1 — Mood + Status**
- Current mood (emoji + name), tap to open mood picker overlay
- Clock (live, updates every second)
- Battery: icon + percentage + status

**Row 2 — Quick Toggles (icon buttons)**
- Do Not Disturb toggle
- Focus Mode toggle
- Ambient Sound toggle (if pack is set)
- Bluetooth toggle (via `bluetoothctl power on/off`)
- Wi-Fi toggle (via `nmcli radio wifi on/off`)
- Night light toggle (via `hyprsunset -t 4000` / `-t 6500`)

**Row 3 — Glass Mode**
- 5-button row: Crystal / Frosted / Mica / Material / Minimal
- Active mode highlighted with accent color

**Row 4 — Volume + Brightness**
- Volume: `Gtk.Scale` (0–150%), populated from PipeWire
- Brightness: `Gtk.Scale` (0–100%), populated from `brightnessctl`
- Both update live and emit toasts on change

**Row 5 — Music** (only visible if Music Center is running)
- Track name + artist (marquee if long)
- Previous / Play-Pause / Next buttons
- Progress bar (`Gtk.ProgressBar`, updates every second)

**Row 6 — Actions**
- "Open Settings" button → `lumina-settings-studio`
- "Take Screenshot" button → `lumina-screenshot`
- "Lock Screen" button → `hyprlock`
- "Log Out" button → `hyprctl dispatch exit`

#### Performance Budgets

- Control Center must appear within 80 ms of keybind (pre-rendered, shown via opacity/transform)
- All D-Bus reads are cached and refreshed every 1 second; never blocks on I/O during show animation
- Uses `Gtk.ListBox` + `Gtk.Box` only (no `GtkColumnView`); layout is O(1)

---

### S-07 — Wallpaper Experience

**Shell accessor:** `lumina-wallpaper`
**Services:** `lumina-wallpaper-rotate.timer`, `lumina-wallpaper-rotate.service`

#### Required Backend Architecture

```bash
# scripts/wallpaper-apply.sh
# Usage: wallpaper-apply.sh <path> [--no-theme] [--no-mood]

swww img "$path" --transition-type="$TRANSITION" --transition-duration=1.2
lumina-theme apply --wallpaper="$path"           # unless --no-theme
lumina-mood detect --wallpaper="$path"           # unless --no-mood
notify-send --urgency=low "Wallpaper applied" "$path"
```

```bash
# scripts/wallpaper-rotate.sh
# Called by lumina-wallpaper-rotate.service
# Picks a random image from WALLPAPER_DIR, calls wallpaper-apply.sh
```

`swww` is the wallpaper daemon. All transition types and durations are configurable through Settings Studio → Wallpaper → Transition Style.

#### Required UI Surfaces

- Settings Studio → Wallpaper: directory picker, rotation interval, transition style
- Lumina Search: "change wallpaper" navigates to Settings Studio Wallpaper page
- Context Menu (on desktop): "Set as Wallpaper" for any image file

#### Accessibility Implementation Requirements

- Wallpaper transitions are suppressed when `prefers-reduced-motion` is set
- Wallpaper does not affect text readability (all readable content is on glass surfaces)

#### Performance Budgets

- `swww img` transition: smooth at 60 Hz, no frame drops on the active window
- Theme Engine triggered asynchronously after wallpaper transition completes (not during)
- Wallpaper file picker shows 200×112 px thumbnails, generated on-demand and cached in `~/.cache/lumina/thumbnails/`

---

### S-08 — Mission Control

**App ID:** `dev.lumina.mission-control` (Hyprland Overview plugin)

#### Required Backend Architecture

Mission Control uses the `hyprland-overview` Hyprland plugin. Lumina configures and styles it via:
- `hypr/.config/hypr/conf.d/plugins.conf` (plugin load + options)
- CSS variables injected by Glass Engine for surface styling

No separate Python process. Mission Control is a compositor-side feature.

#### Required UI Surfaces

Hyprland Overview plugin provides the core renderer. Lumina contributes:
- Workspace labels (derived from active window title or workspace name)
- Consistent glass-surface styling
- Keyboard navigation hints overlay (shown on first use)

#### Accessibility Implementation Requirements

- Full keyboard navigation (arrow keys, Enter, Escape)
- Workspace tiles have accessible names: "Workspace 1: Firefox, Terminal"
- Sufficient thumbnail size (minimum 200px width) for visual identification

#### Performance Budgets

- Overview must render within 100 ms of trigger at 60 Hz
- Window thumbnails rendered by compositor (GPU-accelerated); no CPU thumbnail generation

---

### S-09 — Keybind Overlay

**App ID:** `dev.lumina.keybind-overlay`

#### Required Backend Architecture

```python
# apps/keybind-overlay/lumina-keybind-overlay.py

def parse_binds_conf(path: str) -> list[Keybind]:
    """
    Parse binds.conf. Extract:
    - key combination
    - action
    - description (from inline comment: # desc: Move to workspace)
    - category (from section comment: # category: Navigation)
    """

def render_overlay(keybinds: list[Keybind]) -> None:
    """GTK4 layer-shell window, dismiss on Escape or SUPER+/"""
```

**Comment convention for binds.conf:**
```
# category: Navigation
bind = $mod, 1, workspace, 1  # desc: Switch to workspace 1
bind = $mod, 2, workspace, 2  # desc: Switch to workspace 2
```

#### Required UI Surfaces

GTK4 layer-shell window, fullscreen-overlay (semi-transparent backdrop). Layout:
- Search box at top (`Gtk.SearchEntry`)
- Tab bar: All / Navigation / Windows / System / Apps / Custom
- `Gtk.GridView` of keybind cards: key badge(s) + action description
- Interactive bindings have an "Execute" button

#### Accessibility Implementation Requirements

- Overlay is keyboard-navigable (Tab, arrow keys, Enter)
- Search results announced by screen reader as they filter
- Key badges use monospace font with sufficient size (14 px minimum)

#### Performance Budgets

- Overlay must appear within 80 ms
- Search filter must respond within 16 ms (client-side, no I/O)
- binds.conf is parsed at launch and cached; file watcher invalidates cache on change

---

### S-10 — Lumina Search

**App ID:** `dev.lumina.search`
**Owner module:** `lumina_core.search`
**IPC:** `dev.lumina.search.Query`

> **Implementation:** `dev.lumina.search.Query` is served by `lumina-core-service`, which delegates indexing and ranking to `lumina_core.search`.

#### Required Backend Architecture

**Owner module:** `lumina_core.search`:
- Owns search indexing and ranking
- Serves settings destinations and `.desktop` application entries
- Is called only through `lumina-core-service` for public D-Bus search queries

**Client window:** `lumina-search` is a GTK4 layer-shell window activated by keybind. It:
- Calls `dev.lumina.search.Query`
- Sends query string on each keystroke
- Receives ranked results within 50 ms
- Renders results in a `Gtk.ListBox` with custom row renderers per result type

#### Query Protocol (D-Bus)

```text
dev.lumina.search.Query("glass")
  -> [
       ("settings:glass", "Glass Mode", "Adjust blur and opacity", "settings", "lumina-settings-studio --page=appearance --section=glass-mode")
     ]
```

#### Index Provider Interface

```python
class IndexProvider(ABC):
    @abstractmethod
    def name(self) -> str: ...

    @abstractmethod
    def index(self) -> list[SearchResult]: ...

    @abstractmethod
    def on_query(self, query: str) -> list[SearchResult]:
        """Live results (not pre-indexed): calculator, AI, windows."""
```

#### Ranking Algorithm

1. Exact title prefix match (score: 100)
2. Title contains query (score: 80)
3. Subtitle contains query (score: 60)
4. Tag/alias match (score: 70)
5. Fuzzy title match (score: 40)
6. Recency bonus: results accessed in last 24h get +15
7. Type priority: Apps > Settings > Windows > Files > Commands

#### Calculator Plugin

- Triggers when query matches `^\d` or starts with `=`
- Uses Python `eval` in a sandboxed subprocess (no builtins, no imports)
- Shows result inline as a preview row; Enter copies to clipboard
- Supports unit conversion via `pint` library

#### AI Plugin (optional)

- Triggers when query starts with `?` or contains a question word ("what", "how", "why")
- Sends query to configured Ollama/Gemma backend
- Streams response into a result row (first 80 characters shown)
- "Open full answer" expands to a detail overlay

#### Lumina Actions Plugin (hardcoded platform results)

```
"change wallpaper"  → lumina-settings-studio --page=wallpaper
"switch mood"       → opens mood picker overlay
"glass crystal"     → lumina-glass set crystal
"take screenshot"   → lumina-screenshot
"lock screen"       → hyprlock
"log out"           → hyprctl dispatch exit
"restart hyprland"  → hyprctl reload
```

#### Required UI Surfaces

**Search window** (GTK4, layer-shell, LAYER_OVERLAY):
- Centered, 640 px wide, max 480 px tall
- Single `Gtk.SearchEntry` at top (autofocused on open)
- `Gtk.ListBox` of result rows below
- Each row: icon (32×32) + title + subtitle + type badge
- Keyboard: arrow keys navigate results, Enter executes, Escape dismisses, Tab for secondary action
- "No results" empty state with suggestions based on query
- Footer: shows active plugins + "Settings" link to Search preferences

**Result row types:**
- `app` — app icon + name + comment
- `setting` — gear icon + setting name + page path (breadcrumb)
- `file` — file-type icon + filename + directory path
- `keybind` — keyboard icon + action + key badge
- `window` — app icon + window title + "Switch to"
- `command` — terminal icon + command name + description
- `calculator` — equals sign + result + "Copy"
- `action` — lightning icon + action name + "Execute"
- `ai` — sparkle icon + truncated answer + "Expand"

#### Accessibility Implementation Requirements

- Search window is fully keyboard-navigable; mouse not required
- Screen reader announces result count on query change: "5 results for glass"
- Screen reader announces selected result as arrow keys navigate
- Text contrast in result rows: subtitle text is `--color-text-secondary` (validated for 4.5:1)
- Search entry has `accessible-name: "Lumina Search"` and placeholder text
- All result type badges have accessible descriptions
- Respects `prefers-reduced-motion`: result list transitions are disabled

#### Performance Budgets

- Window open-to-visible: ≤ 80 ms (window is pre-created, show via opacity)
- First results on keypress: ≤ 50 ms (from first character typed to first result visible)
- Full result set on complete query: ≤ 150 ms
- AI results may arrive after 1–5 seconds; shown as a streaming placeholder row
- Daemon memory footprint: ≤ 50 MB RSS with full index loaded
- File index: uses SQLite FTS5 (trigram tokenizer); queries O(log n)
- App index: ≤ 1,000 `.desktop` files; in-memory, instant
- Settings index: ≤ 200 entries; in-memory, instant

---

## PART III — A-TIER IMPLEMENTATION SPECIFICATIONS

---

### A-01 — Music Center

**Backend:** MPRIS D-Bus interface (`org.mpris.MediaPlayer2.*`)

#### Required Backend Architecture

```python
# apps/music-center/lumina-music-center.py
# Subscribes to org.mpris.MediaPlayer2.* on D-Bus
# Aggregates all active players into a unified queue view

class MPRISPlayer:
    def play_pause(self): ...
    def next(self): ...
    def previous(self): ...
    def seek(self, position_us: int): ...

    @property
    def metadata(self) -> dict: ...  # title, artist, album, art_url, length
    @property
    def position(self) -> int: ...   # microseconds
    @property
    def status(self) -> str: ...     # Playing / Paused / Stopped
```

#### Required UI Surfaces

Primary window: compact mode (280 px wide, album art + title + transport) and expanded mode (480 px, adds queue + equalizer). Toggle with a resize button.

Control Center: 2-row compact view (title/artist + three transport buttons + progress bar).

#### Settings Studio Integration

No dedicated page. Music Center preferences (startup behavior, toast on track change) live in Settings Studio → Audio.

#### Control Center Integration

Row 5: visible when any MPRIS player is active. Shows album art thumbnail (32×32), title (marquee if >24 chars), artist, and three transport buttons.

#### Accessibility Implementation Requirements

- Transport buttons have accessible labels ("Play", "Pause", "Next", "Previous")
- Progress bar has accessible value-text: "2:34 of 4:10"
- Album art has alt text: "{Title} by {Artist}"

#### Performance Budgets

- MPRIS polling: no polling — event-driven via D-Bus property change signals
- Control Center music row updates within 100 ms of track change
- Activity Timeline write: async, non-blocking

---

### A-02 — Clipboard Center

**Backend:** `cliphist` daemon + `wl-clipboard`

#### Required Backend Architecture

```bash
# Hyprland exec-once entries:
exec-once = wl-paste --type text --watch cliphist store
exec-once = wl-paste --type image --watch cliphist store
```

```python
# apps/clipboard-center/lumina-clipboard-center.py

def get_history() -> list[ClipEntry]: ...
def delete_entry(entry_id: int) -> None: ...
def clear_all() -> None: ...
def paste_entry(entry: ClipEntry) -> None:
    # Write to clipboard via wl-copy, then simulate CTRL+V
```

#### Required UI Surfaces

GTK4 layer-shell window (like Lumina Search but full-height, left-anchored). Layout:
- Search box at top
- `Gtk.ListBox` of clip entries, newest first
- Each row: type icon + content preview (text: first 80 chars; image: 64px thumbnail) + timestamp
- Right-click: Delete / Pin / Copy
- Pinned entries shown at top, separated by a divider

#### Settings Studio Integration

Settings Studio → Notifications page:
- "Clipboard history: On/Off" `Adw.SwitchRow`
- "Maximum entries" `Adw.SpinRow` (50–500)
- "Include images" `Adw.SwitchRow`
- "Auto-clear after" `Adw.ComboRow` (Never / 1 day / 1 week / 1 month)

#### Accessibility Implementation Requirements

- All clip content accessible via keyboard (arrow keys, Enter to paste, Delete to remove)
- Image clips have alt text: "Image copied [timestamp]"

#### Performance Budgets

- Window open to visible: ≤ 80 ms
- Search filter: client-side, ≤ 16 ms
- History read: SQLite query, ≤ 10 ms for 500 entries

---

### A-03 — Widget Engine

**Config:** `~/.config/lumina/widgets.json`
**Service:** `lumina-widget-daemon.service`

#### Required Backend Architecture

Widget daemon (`lumina-widget-daemon`) is a GTK4 layer-shell process that:
- Reads `widgets.json` on start and on D-Bus `dev.lumina.settings.Changed`
- Renders each widget as a sub-window at specified screen coordinates
- Each widget is a GTK4 `Box` rendered onto the desktop layer

**Built-in widget types:**
- `clock` — time + date, style driven by Mood Engine
- `calendar` — mini-month with event dots (from local `.ics` files)
- `system-stats` — CPU%, RAM%, temperatures
- `weather` — via `wttr.in` API (no account required)
- `music` — now-playing from MPRIS
- `focus-timer` — countdown when Focus Mode is active

#### Required UI Surfaces

No dedicated window. Widget placement configured through Settings Studio → Widgets:
- List of active widgets with on/off toggles
- "Add Widget" → type picker overlay
- Drag-and-drop reordering (initial release uses numeric position)
- Per-widget: long-pressing row → configuration popover

#### Accessibility Implementation Requirements

- Desktop layer widgets are `aria-hidden` equivalents: informational only, not interactive
- Interactive widgets (focus timer, music controls) are keyboard-accessible when focused with SUPER+Tab

#### Performance Budgets

- All widgets render in a single GTK4 process (one `GtkWindow` per widget)
- System stats widget: polled every 2 seconds
- Weather widget: fetched every 15 minutes, cached between
- Widget draw calls: ≤ 16 ms each (60 Hz budget)

---

### A-04 — Lock Screen Studio

**Underlying tool:** `hyprlock`

#### Required Backend Architecture

```python
# apps/lock-screen-studio/lumina-lockscreen.py
# Or: scripts/apply-lockscreen-style.sh <style>

CLOCK_STYLES: dict[str, str] = {
    "cyber":     "...",  # hyprlock LABEL block, JetBrains Mono, large hours
    "minimal":   "...",  # Inter thin, small
    "android":   "...",  # two-line, bold hour / thin minute
    "terminal":  "...",  # monospace, unix timestamp + HH:MM
    "material":  "...",  # Inter, baseline-aligned hours/minutes
    "windows":   "...",  # centered, medium weight
}

def apply_lockscreen_style(style: str, tokens: dict) -> None:
    """Generate hyprlock.conf from template + style + tokens, write atomically."""
```

#### Settings Studio Integration — Appearance Page, Lock Screen Section

- Clock style: `Adw.ComboRow` (6 styles)
- Auto-set from mood: `Adw.SwitchRow`
- Show battery on lock screen: `Adw.SwitchRow`
- Show date: `Adw.SwitchRow`
- Blur strength: `Adw.ScaleRow` (0–10)

#### Accessibility Implementation Requirements

- Lock screen clock must pass WCAG AA contrast against blurred wallpaper background
- All clock styles include both hour and minute
- Input field accessible label: "Password"

#### Performance Budgets

- `hyprlock.conf` regeneration: under 200 ms
- Lock screen activation (SUPER+L): compositor-side, Lumina has no performance impact

---

### A-05 — Gesture Engine

**Config:** `~/.config/lumina/gestures.json` (source of truth)
**Generated:** `~/.config/libinput-gestures.conf`
**Generator:** `scripts/system/generate-gesture-conf.py`

#### Required Backend Architecture

```python
# scripts/system/generate-gesture-conf.py
# Reads gestures.json → writes libinput-gestures.conf → restarts lumina-gestures.service

GESTURE_SCHEMA = {
    "swipe_up_3":    {"default": "hyprctl dispatch overview:toggle", "desc": "Mission Control"},
    "swipe_down_3":  {"default": "hyprctl dispatch togglespecialworkspace scratch", "desc": "Scratchpad"},
    "swipe_left_3":  {"default": "hyprctl dispatch workspace r-1", "desc": "Previous workspace"},
    "swipe_right_3": {"default": "hyprctl dispatch workspace r+1", "desc": "Next workspace"},
    "swipe_up_4":    {"default": "lumina-hub", "desc": "Lumina Hub"},
    "swipe_down_4":  {"default": "lumina-control-center", "desc": "Control Center"},
    "pinch_in_2":    {"default": "hyprctl dispatch fullscreen 1", "desc": "Fullscreen"},
    "pinch_out_2":   {"default": "hyprctl dispatch fullscreen 0", "desc": "Exit fullscreen"},
}
```

#### Settings Studio Integration — Gestures Page

One `Adw.EntryRow` per gesture slot, pre-filled from `gestures.json`. "Save and Reload" button. "Reset to Defaults" button.

#### Performance Budgets

- Gesture recognition: libinput-gestures latency ≤ 50 ms
- Config regeneration: ≤ 200 ms
- Service restart: ≤ 500 ms

---

### A-06 — Context Menu System

**Backend:** GTK4 `Gtk.PopoverMenu` + `Gio.MenuModel`

#### Required Backend Architecture

```python
# lumina_core/menus.py

class LuminaContextMenu:
    """Wrapper around Gtk.PopoverMenu that applies Lumina glass styling."""
    def __init__(self, menu_model: Gio.MenuModel): ...
    def popup_at_pointer(self, event: Gdk.Event) -> None: ...
    def add_section(self, title: str, items: list[tuple[str, str]]) -> None:
        """items: [(label, action_name)]"""
```

Desktop context menu (via transparent GTK4 overlay window covering the desktop):
- "Change Wallpaper" → Settings Studio Wallpaper page
- "Mission Control" → `hyprctl dispatch overview:toggle`
- "Open Terminal" → `$TERMINAL`
- "Lumina Settings" → `lumina-settings-studio`

#### Accessibility Implementation Requirements

- All context menu items keyboard-accessible (arrow keys, Enter, Escape)
- Context menus dismissed on Escape
- Menu items with submenus have accessible expanded/collapsed state

---

### A-07 — Action Feedback Toasts

**Backend module:** `apps/lib/lumina_core/toasts.py`

#### System-Wide Toast Events (Canonical List)

| Event | Message | Category |
|-------|---------|----------|
| Wallpaper applied | "Wallpaper applied" | success |
| Glass mode changed | "Glass: {mode} applied" | info |
| Mood changed | "Mood: {mood} {emoji} active" | info |
| Theme regenerated | "Theme updated from wallpaper" | success |
| Focus mode on | "Focus mode enabled" | info |
| Focus mode off | "Focus mode disabled" | info |
| Screenshot saved | "Screenshot saved to {path}" | success |
| Clipboard copied | "{n} characters copied" | info |
| Settings saved | "{setting} updated" | success |
| Settings error | "Error: {message}" | error |
| Update available | "Lumina update available" | info |
| Snapshot created | "Snapshot created" | success |

#### Performance Budgets

- `toast()` must return in under 5 ms (fire-and-forget subprocess via `notify-send`)
- In-app toast overlay must not affect layout (overlay, not inline)

---

### A-08 — Battery Analytics

**Service:** `lumina-battery-logger.service`
**Data:** `~/.local/state/lumina/battery.jsonl`

#### Required Backend Architecture

```bash
# scripts/system/battery-logger.sh
# Called every 60 seconds by lumina-battery-logger.service
# Reads from /sys/class/power_supply/BAT0/

STATUS=$(cat /sys/class/power_supply/BAT0/status)
CAPACITY=$(cat /sys/class/power_supply/BAT0/capacity)
TIMESTAMP=$(date +%s)
echo '{"ts":'$TIMESTAMP',"status":"'$STATUS'","capacity":'$CAPACITY'}' >> ~/.local/state/lumina/battery.jsonl
```

```python
# apps/battery-analytics/lumina-battery-analytics.py

def load_battery_history(days: int = 7) -> list[BatteryEvent]: ...
def render_discharge_chart(events: list[BatteryEvent], area: Gtk.DrawingArea) -> None: ...
def render_weekly_cycles_chart(events: list[BatteryEvent], area: Gtk.DrawingArea) -> None: ...
def estimate_time_remaining(events: list[BatteryEvent]) -> str: ...  # "~2h 15m"
def health_assessment(events: list[BatteryEvent]) -> str: ...        # "Good" | "Moderate" | "Degraded"
```

#### Auto-Power-Save Monitor

`lumina-battery-monitor.service` (runs continuously):
```bash
while true; do
    CAPACITY=$(cat /sys/class/power_supply/BAT0/capacity)
    STATUS=$(cat /sys/class/power_supply/BAT0/status)
    THRESHOLD=$(jq .low_battery_threshold ~/.config/lumina/mood.json)

    if [[ "$STATUS" == "Discharging" && "$CAPACITY" -le "$THRESHOLD" ]]; then
        lumina-glass set minimal
        lumina-toast "Battery low: power-save mode active" "" warning
    fi
    sleep 60
done
```

#### Required UI Surfaces

Full GTK4 window with three tabs:
- **Overview**: current status card (%, status, time remaining, health), today's charge events
- **History**: 7-day discharge rate chart + charge cycle count
- **Settings**: threshold sliders, logger on/off (links to Settings Studio Battery page)

---

## PART IV — B-TIER IMPLEMENTATION SPECIFICATIONS

---

### B-01 — Screenshot Studio

**Backend:** `grim` + `slurp`

#### Required Backend Architecture

```bash
# scripts/screenshot.sh
# Usage: screenshot.sh [region|window|screen]

case "$1" in
    region)   grim -g "$(slurp)" /tmp/lumina-screenshot.png ;;
    window)   grim -g "$(hyprctl activewindow -j | jq -r '.at,.size | @csv')" /tmp/lumina-screenshot.png ;;
    screen)   grim /tmp/lumina-screenshot.png ;;
esac

# Open annotation window
lumina-screenshot-annotate /tmp/lumina-screenshot.png
```

Annotation window is a GTK4 app (`Gtk.DrawingArea` + `Gtk.Overlay` toolbar): draw mode, text mode, blur mode, crop. Save button writes to configured directory, copies path to clipboard, emits toast.

---

### B-02 — Session Restoration

**Service:** `lumina-session.service`
**Config:** `~/.config/lumina/session.json`

> **Known Wayland limitation:** App geometry restoration requires app cooperation. Many apps (Electron, Firefox) do not reliably save/restore geometry via Wayland. Expected coverage: ~70% of apps. Remaining apps must be skipped gracefully with a log entry, not a crash. The feature must emit a toast on restore: "Session restored: 4 apps (2 skipped — unsupported)."

#### Required Backend Architecture

```python
# scripts/system/session-save.sh  → called by Hyprland exit hook
# scripts/system/session-restore.sh → called at startup by lumina-session.service

# session.json format:
{
    "timestamp": 1234567890,
    "workspaces": [
        { "id": 1, "windows": [
            { "class": "firefox", "title": "...", "geometry": [0, 0, 1920, 1080] }
        ]}
    ]
}
```

---

### B-03 — Activity Timeline

**Data:** `~/.local/state/lumina/activity.jsonl`

#### Required UI Surfaces

GTK4 window with three views:
- **Today**: 24-hour timeline bar (color-coded by event type) + summary cards
- **Week**: bar chart of daily focus hours + most-used apps
- **Data**: raw event log with filtering

#### Data Streams (Logging Sources)

- **Focus Mode**: logs `focus_start` / `focus_end` events
- **Music Center**: logs track changes
- **Battery Analytics**: logs charge events
- **App usage**: logged by `activity-logger.sh` (polls `hyprctl activewindow` every 30 seconds)

---

### B-04 — Scratchpad System

Native Hyprland. Keybind config only.

```
bind = $mod, grave, togglespecialworkspace, scratch   # desc: Toggle scratchpad
bind = $mod SHIFT, grave, movetoworkspace, special:scratch  # desc: Move window to scratchpad
```

---

### B-05 — Focus Mode

**Shell accessor:** `lumina-focus`
**Config:** `~/.config/lumina/focus.json`

#### Required Backend Architecture

```bash
# scripts/system/focus-mode.sh
# Usage: focus-mode.sh enable | disable | toggle | status

enable() {
    lumina-glass set material
    dunstctl set-paused true
    systemctl --user restart lumina-ambient.service  # starts focus pack
    echo '{"type":"focus_start","ts":'$(date +%s)',"mood":"'$MOOD'"}' >> "$ACTIVITY_LOG"
    lumina-toast "Focus mode enabled" "" success
}

disable() {
    lumina-glass set "$(jq -r .mode ~/.config/lumina/glass.json)"  # restore previous
    dunstctl set-paused false
    systemctl --user stop lumina-ambient.service
    DURATION=$(( $(date +%s) - $START_TS ))
    echo '{"type":"focus_end","ts":'$(date +%s)',"duration_s":'$DURATION'}' >> "$ACTIVITY_LOG"
    lumina-toast "Focus mode disabled" "" info
}
```

#### Settings Studio Integration — Focus Page

- Focus glass mode: `Adw.ComboRow`
- Focus ambient sound: `Adw.ComboRow` (None + available packs)
- Disable notifications: `Adw.SwitchRow`
- Focus duration reminder: `Adw.SpinRow` (0 = no reminder, 25 = Pomodoro default)

---

### B-06 — Window Teleportation

Native Hyprland. Keybind config only.

```
bind = $mod SHIFT, 1, movetoworkspace, 1   # desc: Move window to workspace 1
...
bind = $mod SHIFT, left, movetoworkspace, r-1   # desc: Move window left
bind = $mod SHIFT, right, movetoworkspace, r+1  # desc: Move window right
```

---

## PART V — C-TIER IMPLEMENTATION SPECIFICATIONS

---

### C-01 — Theme Studio

**App ID:** `dev.lumina.theme-studio`
**Existing:** `apps/theme-studio/` — verify token-level editing is present.

Extends Theme Engine with a visual editing surface. Writes `palette-overrides.json` and calls `lumina-theme apply`. Power users export as `.lumina-theme` files.

---

### C-02 — App Center

**Backend:** `pacman` + `paru` + `flatpak`

#### Required Backend Architecture

```python
# apps/app-center/lumina-app-center.py

@dataclass
class Package:
    name: str
    version: str
    description: str
    source: str  # "pacman" | "aur" | "flatpak"
    installed: bool

def get_installed() -> list[Package]: ...
def search(query: str) -> list[Package]: ...
def get_updates() -> list[Package]: ...
def install(pkg: Package, on_output: Callable[[str], None]) -> None: ...
def remove(pkg: Package, on_output: Callable[[str], None]) -> None: ...
```

#### Accessibility Implementation Requirements

- Package list is keyboard-navigable
- Install/remove operations show progress as text (accessible) in addition to a progress bar

---

### C-03 — Update Center

**Service:** `lumina-update-checker.timer` (checks daily)

Manages Lumina dotfile updates, package updates, and Hyprland plugin updates. Distinguishes between platform updates (dotfiles), system updates (pacman), and AUR updates.

---

## PART VI — D-TIER IMPLEMENTATION SPECIFICATIONS

---

### D-01 — Animated Wallpapers

**Backend:** `mpvpaper` + `swww` hybrid

#### Required Backend Architecture

The Wallpaper Experience system detects whether the active wallpaper is a video file and activates mpvpaper automatically.

#### Performance Budgets

- mpvpaper GPU usage must not exceed 15% on integrated graphics at 1080p
- Animation framerate matches display refresh rate (no over-rendering)
- CPU video decode preferred over GPU decode on battery

---

### D-02 — Ambient Sounds

**Backend:** `mpv` (headless audio playback)
**Service:** `lumina-ambient.service`

#### Required Backend Architecture

```bash
# scripts/system/ambient-sound.sh
# Usage: ambient-sound.sh start <pack> | stop | status | list

PACK_DIR="$DOTFILES_DIR/audio/ambient"
start() {
    stop  # kill previous if running
    mpv --loop=inf --volume=40 --no-video "$PACK_DIR/$1/*.flac" &
    echo $! > /tmp/lumina-ambient.pid
}
stop() { kill $(cat /tmp/lumina-ambient.pid 2>/dev/null) 2>/dev/null; }
```

#### Control Center Integration

Quick toggle (icon button, only shown if pack is configured).

#### Performance Budgets

- Audio decode: CPU usage ≤ 2% for FLAC at 44.1 kHz
- Must not conflict with PipeWire audio routing for music/video

---

### D-03 — Ultra Minimal Mode

**Shell accessor:** `lumina-minimal`

#### Required Backend Architecture

```bash
# scripts/system/ultra-minimal.sh
# Toggle: if active → restore previous state; if inactive → apply minimal

enable() {
    PREV_STATE=$(cat ~/.cache/lumina/pre-minimal-state.json)
    lumina-glass set minimal
    systemctl --user stop lumina-widget-daemon.service
    hyprctl keyword misc:no_direct_scanout false
    lumina-toast "Ultra minimal mode active" "" info
}
restore() {
    # Read pre-minimal-state.json, restore glass mode, restart widget daemon
}
```

---

## PART VII — TESTING REQUIREMENTS

Before any feature is marked complete:

1. `bash tests/validate-repo.sh` → exit 0
2. `python3 tests/validate-lumina-core.py` → exit 0
3. `bash install.sh --dry-run --host=generic` → exit 0 or 20
4. `bash install.sh --dry-run --host=loq-15irx9` → exit 0 or 20
5. All new keybinds documented in `docs/keybindings.md` and visible in Keybind Overlay
6. All new settings pages validated against JSON schema
7. All new toasts tested at each glass mode for contrast compliance
8. Lumina Search returns the feature within the top 3 results for its primary keyword

---

## PART VIII — IMPLEMENTATION SEQUENCE

Teams do not move to the next step until all items in the current step pass their completion requirements.

**Step 1 — Token Infrastructure**
Design System, Glass Engine, Theme Engine (without Mood integration), Action Feedback Toasts, `lumina_core` shared library

**Step 2 — Settings Studio Shell**
Settings Studio UI with Appearance, Wallpaper, Notifications pages (no Mood page yet). Lumina Search daemon (Apps + Settings plugins only). Formalize D-Bus interface (`dev.lumina.core` service descriptor).

**Step 3 — Orchestration Layer**
Mood Engine, Wallpaper Experience (full pipeline), Gesture Engine

**Step 4 — Platform Core**
Settings Studio (all pages), Lumina Search (all plugins), Control Center, Mission Control, Keybind Overlay, Lock Screen Studio

**Step 5 — Daily Experience (A-Tier)**
Music Center, Clipboard Center, Widget Engine, Battery Analytics, Context Menu System

**Step 6 — Productivity (B-Tier)**
Screenshot Studio, Focus Mode, Scratchpad System, Activity Timeline, Session Restoration, Window Teleportation

**Step 7 — Platform Services (C-Tier)**
Theme Studio, App Center, Update Center

**Step 8 — Enhancements (D-Tier)**
Ambient Sounds, Animated Wallpapers, Ultra Minimal Mode

---

## APPENDIX A — KEYBIND REGISTRY

| Action | Keybind | Category | Overlay Group |
|--------|---------|----------|---------------|
| Lumina Search | SUPER + SPACE | Platform | Search |
| Control Center | SUPER + SHIFT + S | Platform | System |
| Settings Studio | SUPER + , | Platform | System |
| Mission Control | SUPER + TAB | Navigation | Navigation |
| Keybind Overlay | SUPER + / | Platform | Help |
| Scratchpad toggle | SUPER + ` | Navigation | Navigation |
| Focus Mode toggle | SUPER + SHIFT + F | Productivity | Productivity |
| Ultra Minimal toggle | SUPER + SHIFT + M | System | System |
| Lock Screen | SUPER + L | System | System |
| Music Center | SUPER + M | Apps | Apps |
| Clipboard Center | SUPER + V | Productivity | Productivity |
| Screenshot (region) | PRINT | Productivity | Productivity |
| Screenshot (window) | SUPER + PRINT | Productivity | Productivity |
| Screenshot (fullscreen) | SHIFT + PRINT | Productivity | Productivity |

---

## APPENDIX B — D-BUS INTERFACE REFERENCE

```
Service: dev.lumina.core
Object: /dev/lumina/core

Signals:
  dev.lumina.settings.Changed(string key, variant value)
  dev.lumina.mood.Changed(string mood)
  dev.lumina.glass.Changed(string mode)
  dev.lumina.toast(string message, string category)
  dev.lumina.wallpaper.Changed(string path)

Methods:
  dev.lumina.mood.Apply(string mood) → ()
  dev.lumina.glass.Set(string mode) → ()
  dev.lumina.search.Query(string query) → array[struct SearchResult]
  dev.lumina.toast.Send(string message, string subtitle, string category) → ()

Properties:
  dev.lumina.core.CurrentMood → string
  dev.lumina.core.CurrentGlass → string
  dev.lumina.core.CurrentWallpaper → string
  dev.lumina.core.BatteryPercent → int32
  dev.lumina.core.OnBattery → boolean
```

> **Architecture Review Note:** This interface is not yet active. Writing the `dev.lumina.core` service descriptor and formalizing it as a systemd user service is a Step 2 prerequisite.

---

## APPENDIX C — IPC CHANNEL REFERENCE

| Channel | Protocol | Direction | Used For |
|---|---|---|---|
| `dev.lumina.settings.Changed` | D-Bus signal | broadcast | Settings changes |
| `dev.lumina.toast` | D-Bus method | any → toast daemon | Toast from any process |
| `dev.lumina.mood.Apply` | D-Bus method | any → mood engine | Mood change requests |
| `dev.lumina.search` | D-Bus method | client → core service | Search queries |
| `dev.lumina.glass.Mode` | D-Bus property | any → glass engine | Glass mode read/write |
| `hyprctl dispatch` | Hyprland IPC | any → compositor | Workspace/window commands |

---

*Lumina Implementation Reference — Technical Specifications*
*Pair with: `ARCHITECTURE.md` and `RULES.md`*
