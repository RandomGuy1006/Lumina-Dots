# RUNTIME_VERIFICATION.md
## Lumina v1.0 Platform Foundation — Runtime Verification Protocol

**Document Class:** Verification and Certification Record
**Release Target:** Lumina v1.0 — Platform Foundation
**Verification Date:** 2026-06-23
**Target Hardware:** `loq-15irx9` (primary), `generic` (secondary)
**Status:** 🔲 IN PROGRESS

> This document is the authoritative record of runtime verification for Lumina v1.0.
> Every section must reach **PASS** status before Release Certification may begin.
> Bug fixes discovered during verification must be logged in the **Defects** subsection
> of the relevant test and committed before re-running that test.
> No new features. No scope changes. Verification only.

---

## How to Use This Document

**For each test:**
1. Run the procedure exactly as written.
2. Record the actual result in the **Result** field.
3. Mark the section `PASS` / `FAIL` / `BLOCKED`.
4. If `FAIL`: log in **Defects**, fix the bug, re-run the test, update the result.
5. A section is complete only when it carries a `PASS` stamp with a recorded timestamp.

**Status Legend:**
- 🔲 Not yet run
- 🔄 In progress
- ✅ PASS
- ❌ FAIL — defect logged, awaiting fix
- ⛔ BLOCKED — depends on another failing section

---

## Section 1 — D-Bus Activation

**Purpose:** Confirm that the `dev.lumina.core` D-Bus service is active within 5 seconds
of Hyprland startup and that all defined signals, methods, and properties are reachable.

**Depends on:** None (substrate-level test)

**Status:** 🔲

### 1.1 Service Introspection

**Procedure:**
```bash
gdbus introspect \
  --session \
  --dest dev.lumina.core \
  --object-path /dev/lumina/core
```

**Required items in output:**
- Signal: `dev.lumina.settings.Changed`
- Signal: `dev.lumina.mood.Changed`
- Signal: `dev.lumina.glass.Changed`
- Signal: `dev.lumina.toast`
- Signal: `dev.lumina.wallpaper.Changed`
- Method: `dev.lumina.mood.Apply`
- Method: `dev.lumina.glass.Set`
- Method: `dev.lumina.search.Query`
- Method: `dev.lumina.toast.Send`
- Property: `CurrentMood` (string)
- Property: `CurrentGlass` (string)
- Property: `CurrentWallpaper` (string)
- Property: `BatteryPercent` (int32)
- Property: `OnBattery` (boolean)

**Result:** _(record actual output or PASS/FAIL)_

---

### 1.2 Startup Timing

**Procedure:**
```bash
START=$(date +%s%N)
until gdbus call --session --dest dev.lumina.core \
  --object-path /dev/lumina/core \
  --method org.freedesktop.DBus.Peer.Ping 2>/dev/null; do
  sleep 0.1
done
END=$(date +%s%N)
echo "D-Bus ready in $(( (END - START) / 1000000 )) ms"
```

**Expected:** Service available within **5000 ms** of session start.

**Result:** _(record measured ms)_

---

### 1.3 Signal Emission Test

**Procedure:**
```bash
# Terminal A — listen:
gdbus monitor --session --dest dev.lumina.core

# Terminal B — trigger:
lumina-glass set frosted
```

**Expected:** Terminal A receives `dev.lumina.glass.Changed` with value `"frosted"` within 500 ms.

**Result:** _(record signal payload and latency)_

---

### Defects — Section 1

| ID | Description | Fixed? | Commit |
|----|-------------|--------|--------|
| — | — | — | — |

**Section 1 Stamp:** 🔲 `_____` PASS / FAIL — Verified by: _____________ Date: _____________

---

## Section 2 — Toast Visibility

**Purpose:** Confirm toasts are emitted correctly by every ACTIVE NOW system,
appear visually on screen, and comply with WCAG AA contrast at all 5 glass modes.
Confirms RULE-006 and RULE-017 (no direct `notify-send` calls remain).

**Depends on:** Section 1

**Status:** 🔲

### 2.1 Direct Toast API

**Procedure:**
```bash
lumina-toast "Info toast" "" info
lumina-toast "Success toast" "" success
lumina-toast "Warning toast" "" warning
lumina-toast "Error toast: click to dismiss" "" error
```

**Expected:**
- `info` — visible ~2 s, auto-dismisses
- `success` — visible ~2 s, auto-dismisses
- `warning` — visible ~4 s, auto-dismisses
- `error` — persists until manually dismissed

**Result:** _(record visual confirmation for each)_

---

### 2.2 Contrast at Each Glass Mode

| Glass Mode | Toast Visible? | Text Contrast ≥ 4.5:1? |
|------------|---------------|------------------------|
| crystal    | 🔲             | 🔲                      |
| frosted    | 🔲             | 🔲                      |
| mica       | 🔲             | 🔲                      |
| material   | 🔲             | 🔲                      |
| minimal    | 🔲             | 🔲                      |

---

### 2.3 No Direct `notify-send` Calls Remain

**Procedure:**
```bash
grep -rn "notify-send" \
  scripts/ apps/ local-bin/ \
  --include="*.sh" --include="*.py"
```

**Expected:** Zero results. Any output is a RULE-017 violation and a blocker.

**Result:** _(paste output or "0 matches")_

---

### 2.4 Canonical Toast Events

| Event | Trigger Command | Toast Shown? | Message Correct? |
|-------|----------------|-------------|-----------------|
| Wallpaper applied | `lumina-wallpaper <path>` | 🔲 | 🔲 |
| Glass mode changed | `lumina-glass set crystal` | 🔲 | 🔲 |
| Mood changed | `lumina-mood set ocean` | 🔲 | 🔲 |
| Theme regenerated | `lumina-theme apply --wallpaper=<path>` | 🔲 | 🔲 |
| Settings saved | Change setting in Settings Studio | 🔲 | 🔲 |
| Settings error | Submit invalid value | 🔲 | 🔲 |

---

### Defects — Section 2

| ID | Description | Fixed? | Commit |
|----|-------------|--------|--------|
| — | — | — | — |

**Section 2 Stamp:** 🔲 `_____` PASS / FAIL — Verified by: _____________ Date: _____________

---

## Section 3 — Control Center Latency

**Purpose:** Confirm Control Center appears within ≤ 80 ms and all 6 rows are
functional and wired to D-Bus. Confirms RULE-027.

**Depends on:** Sections 1, 2

**Status:** 🔲

### 3.1 Open Latency

**Procedure:**
Press `SUPER+SHIFT+S`. Window must be **pre-rendered and hidden** — not spawned on demand (RULE-027).

**Expected:** Visible in **≤ 80 ms**.

**Result:** _(record measured or estimated latency)_

---

### 3.2 Layout Verification

| Row | Content Expected | Renders? |
|-----|-----------------|---------|
| Row 1 | Mood emoji + name, live clock, battery % + status | 🔲 |
| Row 2 | DND / Focus / Ambient / BT / Wi-Fi / Night light toggles | 🔲 |
| Row 3 | 5 glass mode buttons (Crystal→Minimal), active highlighted | 🔲 |
| Row 4 | Volume slider (PipeWire) + Brightness slider (brightnessctl) | 🔲 |
| Row 5 | Music row (visible only when MPRIS player active) | 🔲 |
| Row 6 | Settings / Screenshot / Lock / Log Out buttons | 🔲 |

---

### 3.3 D-Bus Reactivity

**Procedure:**
1. Open Control Center.
2. In a separate terminal: `lumina-mood set cyberpunk`
3. Observe Control Center Row 1 without closing it.

**Expected:** Mood display updates within **1 second** without manual refresh.

**Result:** _(record observed update latency)_

---

### 3.4 Glass Mode Quick Toggle

| Mode | Applied in ≤500ms? | Toast shown? | Button highlighted? |
|------|-------------------|-------------|-------------------|
| crystal | 🔲 | 🔲 | 🔲 |
| frosted | 🔲 | 🔲 | 🔲 |
| mica | 🔲 | 🔲 | 🔲 |
| material | 🔲 | 🔲 | 🔲 |
| minimal | 🔲 | 🔲 | 🔲 |

---

### 3.5 Keyboard Navigation

**Procedure:** Navigate using Tab only — no mouse. Activate with Enter/Space. Dismiss with Escape.

**Expected:** All interactive elements reachable. RULE-023.

**Result:** _(record any elements not reachable by keyboard)_

---

### Defects — Section 3

| ID | Description | Fixed? | Commit |
|----|-------------|--------|--------|
| — | — | — | — |

**Section 3 Stamp:** 🔲 `_____` PASS / FAIL — Verified by: _____________ Date: _____________

---

## Section 4 — Keybind Overlay Latency

**Purpose:** Confirm Keybind Overlay appears within ≤ 80 ms, all binds are categorized,
and search filters in ≤ 16 ms. Confirms RULE-027.

**Depends on:** Section 1

**Status:** 🔲

### 4.1 Open Latency

**Procedure:** Press `SUPER+/`. Window must be pre-rendered and hidden (RULE-027).

**Expected:** Visible in **≤ 80 ms**.

**Result:** _(record observed latency)_

---

### 4.2 Category Coverage

**Procedure:**
```bash
grep "# category:" hypr/conf.d/binds.conf | sort | uniq -c
```

| Category | At Least One Entry? |
|----------|-------------------|
| Navigation | 🔲 |
| Windows | 🔲 |
| System | 🔲 |
| Apps | 🔲 |
| Productivity | 🔲 |
| Help | 🔲 |

---

### 4.3 Search Filter Latency

**Procedure:** Open Keybind Overlay, type "glass". Observe time to first filtered result.

**Expected:** Results update within **≤ 16 ms** (one frame at 60 Hz). RULE-027.

**Result:** _(record observation)_

---

### 4.4 Keybind Completeness

| Keybind | In Overlay? | In `docs/keybindings.md`? |
|---------|-----------|--------------------------|
| SUPER+SPACE (Lumina Search) | 🔲 | 🔲 |
| SUPER+SHIFT+S (Control Center) | 🔲 | 🔲 |
| SUPER+, (Settings Studio) | 🔲 | 🔲 |
| SUPER+TAB (Mission Control) | 🔲 | 🔲 |
| SUPER+/ (Keybind Overlay) | 🔲 | 🔲 |
| SUPER+` (Scratchpad) | 🔲 | 🔲 |
| SUPER+SHIFT+F (Focus Mode) | 🔲 | 🔲 |
| SUPER+L (Lock Screen) | 🔲 | 🔲 |

---

### Defects — Section 4

| ID | Description | Fixed? | Commit |
|----|-------------|--------|--------|
| — | — | — | — |

**Section 4 Stamp:** 🔲 `_____` PASS / FAIL — Verified by: _____________ Date: _____________

---

## Section 5 — Mission Control Latency

**Purpose:** Confirm Mission Control renders within ≤ 100 ms, workspace tiles are labeled,
and keyboard navigation works. Confirms RULE-027 (100 ms budget for compositor features).

**Depends on:** Section 1

**Status:** 🔲

### 5.1 Open Latency

| Trigger | Latency ≤ 100 ms? |
|---------|-----------------|
| SUPER+TAB keybind | 🔲 |
| 3-finger swipe up (Gesture Engine) | 🔲 |

---

### 5.2 Workspace Labels

**Expected:** Each tile shows "Workspace N: AppName, AppName". Min tile width: 200 px.

**Result:** _(record observed label format)_

---

### 5.3 Glass Styling

**Procedure:**
1. Set `lumina-glass set crystal` → open Mission Control → observe surfaces.
2. Set `lumina-glass set minimal` → open Mission Control → observe surfaces.

**Expected:** Crystal: blur + glass surface. Minimal: solid surfaces, no blur. RULE-001.

**Result:** _(record visual observations at each mode)_

---

### 5.4 Keyboard Navigation

**Expected:** Arrow keys navigate tiles, Enter jumps to workspace, Escape dismisses. RULE-023.

**Result:** _(record any navigation gaps)_

---

### Defects — Section 5

| ID | Description | Fixed? | Commit |
|----|-------------|--------|--------|
| — | — | — | — |

**Section 5 Stamp:** 🔲 `_____` PASS / FAIL — Verified by: _____________ Date: _____________

---

## Section 6 — Wallpaper Cascade Timing

**Purpose:** Confirm the complete pipeline: `swww` → `lumina-theme apply` → `lumina-mood detect`
→ token broadcast executes correctly and within ≤ 3,200 ms total.

**Depends on:** Sections 1, 2

**Status:** 🔲

### 6.1 Full Pipeline Timing

**Procedure:**
```bash
time lumina-wallpaper /path/to/test-wallpaper.jpg
```

| Stage | Budget | Measured |
|-------|--------|---------|
| `swww` transition (smooth at 60 Hz) | No frame drops | |
| `lumina-theme apply` (Matugen + token write) | ≤ 2,000 ms | |
| `lumina-mood detect` (non-blocking) | Non-blocking | |
| Total observable pipeline | ≤ 3,200 ms | |
| "Wallpaper applied" toast | Within 500 ms of transition | |

---

### 6.2 Token Broadcast Verification

**Procedure:**
```bash
# After wallpaper change:
cat ~/.cache/lumina/visual-tokens.json | python3 -m json.tool | head -30
cat ~/.config/hypr/conf.d/tokens-colors.conf | head -10
```

**Expected:**
- `visual-tokens.json` timestamp matches wallpaper change time
- `tokens-colors.conf` contains updated hex values
- Running GTK4 app colors shift to match new palette without restart

**Result:** _(record observations)_

---

### 6.3 Flag Testing

```bash
lumina-wallpaper /path/to/image.jpg --no-theme
# Expected: wallpaper changes, theme does NOT regenerate

lumina-wallpaper /path/to/image.jpg --no-mood
# Expected: theme regenerates, mood does NOT auto-detect
```

**Result:** _(record whether each flag works correctly)_

---

### 6.4 `prefers-reduced-motion` — Transition Suppressed

```bash
gsettings set org.gnome.desktop.interface enable-animations false
lumina-wallpaper /path/to/image.jpg
# Expected: immediate swap — no animated transition
```

**Result:** _(confirm transition is suppressed)_

---

### 6.5 Thumbnail Cache

```bash
ls -la ~/.cache/lumina/thumbnails/
```

**Expected:** 200×112 px thumbnail created for each applied wallpaper. IMPLEMENTATION_REFERENCE.md §S-07.

**Result:** _(record thumbnail dimensions)_

---

### Defects — Section 6

| ID | Description | Fixed? | Commit |
|----|-------------|--------|--------|
| — | — | — | — |

**Section 6 Stamp:** 🔲 `_____` PASS / FAIL — Verified by: _____________ Date: _____________

---

## Section 7 — Mood Application Timing

**Purpose:** Confirm `apply_mood()` coordinates all subsystems within ≤ 500 ms
and all 8 moods apply the correct glass mode, color temperature, and clock style.
Confirms RULE-031.

**Depends on:** Sections 1, 2

**Status:** 🔲

### 7.1 Timing — All 8 Moods

```bash
for mood in cyberpunk nature ocean dark warm minimal space retro; do
  echo -n "$mood: "; time lumina-mood set $mood
done
```

| Mood | Time (ms) | ≤ 500 ms? |
|------|----------|-----------|
| cyberpunk | | 🔲 |
| nature | | 🔲 |
| ocean | | 🔲 |
| dark | | 🔲 |
| warm | | 🔲 |
| minimal | | 🔲 |
| space | | 🔲 |
| retro | | 🔲 |

---

### 7.2 Correct Glass Mode Per Mood

| Mood | Expected Glass | Actual Glass | Match? |
|------|---------------|-------------|--------|
| cyberpunk | crystal | | 🔲 |
| nature | frosted | | 🔲 |
| ocean | frosted | | 🔲 |
| dark | mica | | 🔲 |
| warm | material | | 🔲 |
| minimal | minimal | | 🔲 |
| space | crystal | | 🔲 |
| retro | material | | 🔲 |

**Verification command:**
```bash
lumina-mood set ocean && sleep 1 && lumina-glass status
```

---

### 7.3 Toast on Mood Change

**Expected:** Toast appears: "Mood: {mood} {emoji} active" within 500 ms. RULE-006.

**Result:** _(record toast text and timing)_

---

### 7.4 `mood.json` Schema Validity

```bash
lumina-mood set nature
python3 -c "
import json, jsonschema
data = json.load(open('$HOME/.config/lumina/mood.json'))
schema = json.load(open('apps/settings-studio/schemas/mood.schema.json'))
jsonschema.validate(data, schema)
print('Schema valid')
"
```

**Expected:** `Schema valid`. RULE-009.

**Result:** _(paste output)_

---

### 7.5 Fallback — Missing `mood.json`

```bash
mv ~/.config/lumina/mood.json /tmp/mood.json.bak
lumina-mood status
mv /tmp/mood.json.bak ~/.config/lumina/mood.json
```

**Expected:** Returns a valid default mood — no crash. RULE-012.

**Result:** _(record returned default mood)_

---

### Defects — Section 7

| ID | Description | Fixed? | Commit |
|----|-------------|--------|--------|
| — | — | — | — |

**Section 7 Stamp:** 🔲 `_____` PASS / FAIL — Verified by: _____________ Date: _____________

---

## Section 8 — GTK Accessibility

**Purpose:** Confirm all ACTIVE NOW GTK4 apps meet the RULE-023 through RULE-026
accessibility baseline. Keyboard-only navigation and AT-SPI compliance.

**Depends on:** None (can run in parallel with other sections)

**Status:** 🔲

### 8.1 Keyboard-Only Navigation

| Application | All elements Tab-reachable? | Enter activates? | Escape dismisses? |
|------------|---------------------------|-----------------|-----------------|
| Settings Studio | 🔲 | 🔲 | 🔲 |
| Control Center | 🔲 | 🔲 | 🔲 |
| Keybind Overlay | 🔲 | 🔲 | 🔲 |
| Mission Control | 🔲 | 🔲 | 🔲 |

**Expected:** All ✅. RULE-023.

---

### 8.2 Accessible Names

**Procedure:**
```bash
# Use accerciser or AT-SPI inspection tool to identify unlabeled elements.
# Or: run accessibility audit with the Accessibility Inspector in GTK4.
```

| Application | Unlabeled elements found? |
|------------|--------------------------|
| Settings Studio | 🔲 (none expected) |
| Control Center | 🔲 (none expected) |
| Keybind Overlay | 🔲 (none expected) |

**Expected:** None. RULE-024.

---

### 8.3 `prefers-reduced-motion` Compliance

```bash
gsettings set org.gnome.desktop.interface enable-animations false
# Open each app and observe transitions/animations
```

| Application | Non-essential animations suppressed? |
|------------|-------------------------------------|
| Settings Studio | 🔲 |
| Control Center | 🔲 |
| Keybind Overlay | 🔲 |

**Expected:** All ✅. RULE-021.

---

### 8.4 AT-SPI State Change Announcements

**Procedure:**
1. Run Orca screen reader.
2. Change glass mode from Control Center.
3. Apply mood from Settings Studio.

**Expected:** Screen reader announces each toast/state change. RULE-026.

**Result:** _(record screen reader output)_

---

### Defects — Section 8

| ID | Description | Fixed? | Commit |
|----|-------------|--------|--------|
| — | — | — | — |

**Section 8 Stamp:** 🔲 `_____` PASS / FAIL — Verified by: _____________ Date: _____________

---

## Section 9 — Walker Search Ranking

**Purpose:** Confirm Walker returns each ACTIVE NOW feature in the top 3 results
for its primary keyword. Confirms RULE-040 and RULE-044.

**Depends on:** Settings Studio must be installed

**Status:** 🔲

### 9.1 Primary Keyword Tests

Open Walker (`SUPER+SPACE`) and type each query. Record the rank of the expected result.

| Query | Expected Top Result | Actual Rank | Pass? |
|-------|-------------------|------------|-------|
| `glass` | Glass Mode — Settings Studio | | 🔲 |
| `blur` | Glass Mode — Settings Studio | | 🔲 |
| `transparency` | Glass Mode or Control Center | | 🔲 |
| `mood` | Mood — Settings Studio | | 🔲 |
| `vibe` | Mood — Settings Studio | | 🔲 |
| `wallpaper` | Wallpaper — Settings Studio | | 🔲 |
| `theme` | Theme or Theme Studio | | 🔲 |
| `control center` | Control Center | | 🔲 |
| `settings` | Settings Studio | | 🔲 |
| `keybinds` | Keybind Overlay | | 🔲 |

**Expected:** All return the correct feature within rank 1–3.

---

### 9.2 Walker Keybind Registration

```bash
grep -i "SUPER.*SPACE\|walker" hypr/conf.d/binds.conf
grep -i "SUPER.*SPACE" docs/keybindings.md
```

**Expected:** `SUPER+SPACE` bound to Walker and documented in `docs/keybindings.md`. RULE-022.

**Result:** _(paste grep results)_

---

### 9.3 RULE-044 Compliance Check

```bash
grep -rn "walker" apps/ scripts/ local-bin/ --include="*.py" --include="*.sh"
```

**Expected:** Every Walker reference accompanied by a comment documenting the
equivalent Lumina Search daemon IPC spec call (RULE-044). No hardcoded Walker internals.

**Result:** _(paste grep output and review each reference)_

---

### Defects — Section 9

| ID | Description | Fixed? | Commit |
|----|-------------|--------|--------|
| — | — | — | — |

**Section 9 Stamp:** 🔲 `_____` PASS / FAIL — Verified by: _____________ Date: _____________

---

## Section 10 — Battery Mode Behavior

**Purpose:** Confirm that when `battery_mode=True` is active (battery below threshold,
discharging), Glass Engine forces `minimal` without overwriting `glass.json`.
Confirms RULE-034.

**Depends on:** Sections 1, 2, 3

**Status:** 🔲

### 10.1 Battery Mode Activation

**Procedure:**
```bash
# On real hardware, discharge to below threshold, or temporarily lower
# low_battery_threshold in config to simulate.
cat /sys/class/power_supply/BAT0/capacity
```

**Expected:**
- Glass Engine forces `minimal`
- Toast: "Battery low: power-save mode active"
- `glass.json` is NOT overwritten with `minimal` (stored mode preserved)

**Result:** _(record observed behavior)_

---

### 10.2 Glass Mode Preservation

```bash
lumina-glass set frosted
cat ~/.config/lumina/glass.json   # should show "frosted"

# Trigger battery mode simulation
cat ~/.config/lumina/glass.json   # must still show "frosted"

# Remove battery mode simulation
# Expected: glass returns to "frosted" automatically
```

**Result:** _(record glass.json content before, during, after battery mode)_

---

### 10.3 Performance Mode — Halved Blur Values

```bash
# Enable performance_mode in Settings Studio → Appearance → Glass → Performance mode
python3 -c "
from lumina_core.glass import load_glass_config, GLASS_PRESETS, GlassMode
cfg = load_glass_config()
preset = GLASS_PRESETS[cfg.mode]
print(f'Stored blur: {preset.blur_size}, Performance blur: {cfg.blur_size}')
"
```

**Expected:** `performance_mode=True` halves `blur_size` and `blur_passes` vs. preset.

**Result:** _(record actual vs. expected values)_

---

### 10.4 D-Tier Graceful Degradation

| Feature | Expected Behavior in Battery Mode | Verified? |
|---------|----------------------------------|----------|
| Animated wallpapers (D-01) | Freeze to first frame | 🔲 / N/A |
| Ambient sounds (D-02) | Auto-stop | 🔲 / N/A |

Mark N/A if feature not yet built.

---

### Defects — Section 10

| ID | Description | Fixed? | Commit |
|----|-------------|--------|--------|
| — | — | — | — |

**Section 10 Stamp:** 🔲 `_____` PASS / FAIL — Verified by: _____________ Date: _____________

---

## Section 11 — Glass Modes

**Purpose:** Confirm all 5 glass mode presets produce correct visual output,
Hyprland `layerrule` entries are written correctly, and switching completes
in ≤ 500 ms. Confirms RULE-001 and RULE-030.

**Depends on:** Sections 1, 2

**Status:** 🔲

### 11.1 Preset Values Accuracy

```bash
python3 -c "
from lumina_core.glass import GLASS_PRESETS, GlassMode
for mode in GlassMode:
    p = GLASS_PRESETS[mode]
    print(f'{mode.value}: blur={p.blur_size} passes={p.blur_passes} '
          f'opacity={p.opacity} sat={p.saturation} '
          f'noise={p.noise} bright={p.brightness}')
"
```

**Expected values** (from `IMPLEMENTATION_REFERENCE.md §Part I`):

| Mode | blur | passes | opacity | sat | noise | bright |
|------|------|--------|---------|-----|-------|--------|
| crystal | 28 | 4 | 0.55 | 1.4 | 0.025 | 0.95 |
| frosted | 20 | 3 | 0.72 | 1.2 | 0.018 | 0.90 |
| mica | 12 | 2 | 0.85 | 1.0 | 0.012 | 0.88 |
| material | 6 | 1 | 0.92 | 0.9 | 0.006 | 1.00 |
| minimal | 0 | 0 | 1.00 | 1.0 | 0.000 | 1.00 |

**Result:** _(paste actual output; compare to table)_

---

### 11.2 Hyprland `layerrule` Generation

```bash
lumina-glass set crystal
cat ~/.config/hypr/conf.d/glass-rules.conf

lumina-glass set minimal
cat ~/.config/hypr/conf.d/glass-rules.conf
# Expected for minimal: blur=0, opacity=1.0
```

**Result:** _(paste conf output for crystal and minimal at minimum)_

---

### 11.3 Switch Timing

```bash
for mode in crystal frosted mica material minimal; do
  START=$(date +%s%N)
  lumina-glass set $mode
  END=$(date +%s%N)
  echo "$mode: $(( (END - START) / 1000000 )) ms"
done
```

| Mode Switch | Time (ms) | ≤ 500 ms? |
|-------------|----------|-----------|
| → crystal | | 🔲 |
| → frosted | | 🔲 |
| → mica | | 🔲 |
| → material | | 🔲 |
| → minimal | | 🔲 |

**Expected:** All ≤ 500 ms. RULE-030.

---

### 11.4 CSS Token Broadcast

```bash
lumina-glass set crystal
python3 -c "
from lumina_core.glass import load_glass_config, glass_css
print(glass_css(load_glass_config()))
"
```

**Expected:** CSS block contains all 6 `--glass-*` tokens with values matching `crystal` preset.

**Result:** _(paste CSS output)_

---

### 11.5 No Hardcoded Blur Values

```bash
grep -rn "blur_size\s*=\s*[0-9]" apps/ scripts/ local-bin/ \
  --include="*.py" --include="*.sh" | grep -v "glass.py" | grep -v "GLASS_PRESETS"
```

**Expected:** Zero results outside `glass.py`. Any result is a RULE-001 violation — BLOCKER.

**Result:** _(paste output or "0 matches")_

---

### Defects — Section 11

| ID | Description | Fixed? | Commit |
|----|-------------|--------|--------|
| — | — | — | — |

**Section 11 Stamp:** 🔲 `_____` PASS / FAIL — Verified by: _____________ Date: _____________

---

## Section 12 — Theme Switching

**Purpose:** Confirm `lumina-theme apply` produces an atomic, complete token update
across all consumers within ≤ 2,000 ms without visible flash.
Confirms RULE-002 and RULE-029.

**Depends on:** Sections 1, 2

**Status:** 🔲

### 12.1 Matugen Pipeline Timing

```bash
time lumina-theme apply --wallpaper=/path/to/test-image.jpg
```

**Expected:** Completes in **≤ 2,000 ms**. RULE-029.

**Result:** _(record measured time)_

---

### 12.2 Token File Integrity

```bash
python3 -m json.tool ~/.cache/lumina/visual-tokens.json > /dev/null && echo "Valid JSON"
python3 -c "
import json, os
tokens = json.load(open(f'{os.environ[\"HOME\"]}/.cache/lumina/visual-tokens.json'))
required = ['colors', 'spacing', 'typography']
missing = [k for k in required if k not in tokens]
print('Missing:', missing if missing else 'None')
"
```

**Expected:** Valid JSON with all required token categories. Atomic write confirmed (no partial writes). RULE-010.

**Result:** _(paste validation output)_

---

### 12.3 Hyprland Color Update

```bash
# Before:
hyprctl getoption decoration:col.active_border
# Apply new wallpaper:
lumina-theme apply --wallpaper=/path/to/image2.jpg
# After:
hyprctl getoption decoration:col.active_border
```

**Expected:** Border color changes to match new wallpaper palette. RULE-002.

**Result:** _(record before and after values)_

---

### 12.4 GTK App Update — No Flash

**Procedure:**
1. Open a running Lumina GTK4 app.
2. Run `lumina-theme apply --wallpaper=/path/to/new-image.jpg`.
3. Observe the running app.

**Expected:** Colors update within 200 ms. No perceptible white flash during CSS reload. RULE-029.

**Result:** _(record whether flash was observed)_

---

### 12.5 `lumina-theme reset` Correctness

```bash
echo '{"accent": "#ff00ff"}' > ~/.config/lumina/palette-overrides.json
lumina-theme apply --wallpaper=/path/to/image.jpg
lumina-theme reset
cat ~/.config/lumina/palette-overrides.json
```

**Expected:** Palette override cleared; accent returns to wallpaper-derived value (not `#ff00ff`).

**Result:** _(record observed accent color before/after reset)_

---

### 12.6 No Hardcoded Colors

```bash
grep -rn "#[0-9a-fA-F]\{6\}" apps/ scripts/ local-bin/ \
  --include="*.py" --include="*.sh" | grep -v "FALLBACK_TOKENS" | grep -v ".pyc"
```

**Expected:** Zero results outside `FALLBACK_TOKENS`. RULE-003 / RULE-002 violation otherwise.

**Result:** _(paste output or "0 matches")_

---

### Defects — Section 12

| ID | Description | Fixed? | Commit |
|----|-------------|--------|--------|
| — | — | — | — |

**Section 12 Stamp:** 🔲 `_____` PASS / FAIL — Verified by: _____________ Date: _____________

---

## Section 13 — 24-Hour Soak Test

**Purpose:** Run Lumina under normal usage for 24 continuous hours. Confirm stability,
no memory leaks, no zombie processes, no unexpected service restarts.

**Depends on:** ⛔ Sections 1–12 must ALL be PASS before soak begins.

**Status:** ⛔ BLOCKED — run only after all previous sections PASS

### 13.1 Soak Test Setup

```bash
echo "Soak start: $(date)" | tee ~/.local/state/lumina/soak-test.log

cat > /tmp/soak-monitor.sh << 'EOF'
#!/bin/bash
while true; do
  TS=$(date +%s)
  MEM=$(ps aux --no-headers | awk '/lumina/ {sum += $6} END {print sum}')
  PROCS=$(ps aux | grep "lumina" | grep -v grep | wc -l)
  echo "$TS mem_kb=$MEM procs=$PROCS" >> ~/.local/state/lumina/soak-metrics.log
  sleep 900
done
EOF
bash /tmp/soak-monitor.sh &
```

---

### 13.2 Soak Metrics

| Metric | Expected | Recorded at Start | Recorded at End |
|--------|----------|------------------|----------------|
| Total Lumina process RSS (KB) | Stable ±20% | | |
| Lumina process count | Constant (no zombies) | | |
| `dev.lumina.core` D-Bus uptime | 24h continuous | | |
| Walker uptime | 24h continuous | | |
| systemd user service restarts | 0 unintended | | |

---

### 13.3 Required Scenario Coverage During Soak

| Scenario | Time Performed | Outcome |
|----------|---------------|---------|
| Changed wallpaper 5+ times | | |
| Cycled through all 8 moods | | |
| Cycled through all 5 glass modes | | |
| Opened/closed Control Center 20+ times | | |
| Opened/closed Keybind Overlay 10+ times | | |
| Used Settings Studio for 10+ changes | | |
| Simulated battery mode (if on laptop) | | |
| Restarted Hyprland once (not full reboot) | | |
| Locked and unlocked screen 5+ times | | |

---

### 13.4 Post-Soak Health Check

```bash
bash tests/validate-repo.sh
python3 tests/validate-lumina-core.py

ps aux | grep lumina | grep -v grep

gdbus call --session --dest dev.lumina.core \
  --object-path /dev/lumina/core \
  --method org.freedesktop.DBus.Peer.Ping

systemctl --user status lumina-*.service | grep "restarts"

du -sh ~/.local/state/lumina/
du -sh ~/.cache/lumina/
```

---

### 13.5 Soak Test Result Summary

| Item | Status |
|------|--------|
| Memory stable over 24h | 🔲 |
| No unintended service restarts | 🔲 |
| D-Bus continuously available | 🔲 |
| All test suites pass post-soak | 🔲 |
| No crash logs in `logs/` | 🔲 |

---

### Defects — Section 13

| ID | Description | Fixed? | Commit |
|----|-------------|--------|--------|
| — | — | — | — |

**Section 13 Stamp:** 🔲 `_____` PASS / FAIL — Verified by: _____________ Date: _____________

---

## Release Certification Gate

All 13 sections must carry a `PASS` stamp before Release Certification is issued.

| Section | Status |
|---------|--------|
| 1 — D-Bus Activation | 🔲 |
| 2 — Toast Visibility | 🔲 |
| 3 — Control Center Latency | 🔲 |
| 4 — Keybind Overlay Latency | 🔲 |
| 5 — Mission Control Latency | 🔲 |
| 6 — Wallpaper Cascade Timing | 🔲 |
| 7 — Mood Application Timing | 🔲 |
| 8 — GTK Accessibility | 🔲 |
| 9 — Walker Search Ranking | 🔲 |
| 10 — Battery Mode Behavior | 🔲 |
| 11 — Glass Modes | 🔲 |
| 12 — Theme Switching | 🔲 |
| 13 — 24-Hour Soak Test | 🔲 |

```
Release: Lumina v1.0 Platform Foundation
Certified by: _________________________
Date: _________________________________
Hardware: loq-15irx9
Commit hash: __________________________
All 13 verification sections: PASS
```

---

*RUNTIME_VERIFICATION.md — Lumina v1.0 Platform Foundation*
*Pair with: `CURRENT_PRIORITY.md`, `ARCHITECTURE.md`, `RULES.md`*
*No further coding. Verification and bug fixes only.*
