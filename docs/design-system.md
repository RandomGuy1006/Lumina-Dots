# Lumina Design System

Lumina should feel quiet, adaptive, and deliberate rather than ornamental.

| Element | Rule |
|---|---|
| Radius | Use the centralized ladder: **16px shell**, **12px items**, **8px chips**. |
| Blur | Use one tokenized blur language across bar, launcher, lock, terminal, and menus. |
| Motion | Use the centralized fast curve for hover/focus and soft curves for workspace movement. |
| Spacing | Use the centralized **4 / 8 / 12 / 16 / 24** rhythm only. |
| Typography | Inter for UI, JetBrains Mono for terminal/editor surfaces. |
| Type scale | 12px caption, 14px body, 18px title, 24px display; 1.4 body line height. |
| Icons | Symbolic icons only at 16 / 20 / 24px; never mix filled and outline families in one surface. |
| Borders | 1px structural borders, 2px focus rings; borders must communicate hierarchy or state. |
| Color | Matugen owns accents and semantic color; static files only seed first boot. |
| Transparency | Use transparent surfaces only where the wallpaper still remains readable. |

Motion hierarchy:

1. Micro feedback: fast hover, press, and focus changes.
2. Navigation: softer workspace and launcher movement.
3. State changes: wallpaper and theme transitions should feel calm and intentional.

Accessibility constraints:

- Keep body text at 14px or larger and preserve the 1.4 line-height token.
- Never encode urgency with color alone; pair it with a symbolic icon and explicit text.
- Every keyboard-focusable control must expose the shared 2px accent focus ring.
- Reduced-effects modes may shorten or remove transforms, but must preserve state feedback.

## Unified design tokens (single source of truth)

Lumina enforces a single “design token” source of truth that drives **all** shell surfaces.

- **Token template (in repo)**: `matugen/.config/matugen/templates/visual-tokens.json`
- **Rendered token JSON (runtime)**: `~/.cache/lumina/visual-tokens.json`
  - Written by Matugen through `matugen/.config/matugen/config.toml`:
    - `input_path = "~/.config/matugen/templates/visual-tokens.json"`
    - `output_path = "~/.cache/lumina/visual-tokens.json"`

## Renderer: `render-visual-tokens.sh`

After Matugen updates the cached token JSON, Lumina renders tokens into target surfaces using:

- `scripts/theme/render-visual-tokens.sh`
- Called automatically by `scripts/theme/sync-surfaces.sh` (which runs after `dotfiles theme ...`)

### Surfaces covered

- **Hyprland**: `~/.config/hypr/tokens.conf`
- **Hyprpanel**: `~/.config/hyprpanel/theme.generated.json`
- **Walker**: `~/.config/walker/themes/generated.css`
- **Wlogout**: `~/.config/wlogout/colors.css`
- **Ghostty**: `~/.config/ghostty/lumina-tokens.conf` and `~/.config/ghostty/themes/LoqDynamic`

### Fail-fast validation (prevents “nullpx”)

The renderer **refuses to write outputs** unless all required token keys are present and non-empty. If token generation is corrupted or incomplete, the render step aborts so malformed values like `null` / `nullpx` cannot propagate into Hyprland/CSS/JSON runtime files.

## Scaling ladder (formal)

- **Shell surfaces** (panels, launchers, dialogs): **16px**
- **Dropdown/sub-items** (list rows, menu items): **12px**
- **Chips/contextual elements** (small pills/badges): **8px**

Spacing uses the strict grid:

- **4 / 8 / 12 / 16 / 24px**
