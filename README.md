# Ultrawide Window Engine for Hammerspoon

A lightweight, high-performance, modular window management engine built in Lua for [Hammerspoon](https://www.hammerspoon.org/). Originally optimized for 3440×1440 ultrawide monitors, it seamlessly adapts to any display aspect ratio and resolution.

---

## ✨ Highlights

- **Dynamic Column Profiles**: Choose between 2-column halves or 3-column layouts with customizable ratios (Thirds, Fourths, Fifths, Sixths).
- **Dynamic Layout Refit**: When you switch or cycle profiles, windows currently fitting snap positions automatically and smoothly glide into the newly chosen profile's proportions. Loose or floating windows are left untouched.
- **Modifier Control Mode & Window Reel Scroller (`⌃⌥⇧`)**: Hold `Ctrl + Alt + Shift` to immediately enter a control mode with a glassmorphic tooltip HUD. Use single keys (`A`, `S`, `D`, `W`, `X`, `F`) for instant placement, and `↑`/`↓` as a height scroller and window stack cycler for windows in that position. Press `Esc` or release the modifiers to dismiss. Normal single `Shift` key usage across all macOS apps is 100% unaffected.
- **Intelligent Halves Window Assignment**: When switching from a 3-column layout to **Halves (1/2 1/2)**, an interactive glassmorphic modal displays all center stage windows with live app icons and thumbnails, allowing you to route each center window to the **Left** or **Right** half via arrow buttons or keyboard hotkeys (`←` / `1` or `→` / `2`).
- **Mission Control Safe Snapping**: Center Stage snapping triggers exclusively from the **bottom screen edge** (Dock-aware). The top-center edge is intentionally unmapped to avoid interfering with macOS Mission Control.
- **Hold-to-Snap Dwell Delay**: Avoid accidental snaps during fast cursor movement or window relocation. Holding at an edge for **50ms** arms the snap and instantly displays a visual footprint preview.
- **Synchronized Smooth Animation**: Windows animate over **250ms** via a centralized 60 FPS master loop using a smooth quadratic ease-out curve ($t(2-t)$). When multiple windows refit simultaneously, they glide in lockstep with zero tearing, frame drops, or CPU thrashing.
- **Corner Quadrant Snapping**: Direct snapping to top/bottom quadrants on screen corners.
- **One-Handed Keyboard Cluster**: Fast layout control via `Ctrl + Alt` hotkeys.
- **Modular Architecture**: Clean, decoupled Lua modules with zero external dependencies.
- **CLI & IPC Ready**: Full control via `hs -c "WindowEngine:..."`.

---

## 📐 Profiles

Profiles define how horizontal screen space is partitioned across columns:

| Profile | Denominator | Layout Preview (Fixed-Width) | Column Proportions |
|---|:---:|---|---|
| **Halves** | `2` | `[      1/2       ][      1/2       ]` | Left: 50%, Right: 50% (Center alternates) |
| **Thirds** | `3` | `[   1/3    ][   1/3    ][   1/3    ]` | Left: 33.3%, Center: 33.3%, Right: 33.3% |
| **Fourths** *(Default)* | `4` | `[  1/4  ][      1/2       ][  1/4  ]` | Left: 25%, Center: 50%, Right: 25% |
| **Fifths** | `5` | `[ 1/5 ][        3/5         ][ 1/5 ]` | Left: 20%, Center: 60%, Right: 20% |
| **Sixths** | `6` | `[ 1/6][         2/3          ][ 1/6]` | Left: 16.7%, Center: 66.7%, Right: 16.7% |

---

## ⌨️ Keyboard Shortcuts

All hotkeys utilize the left-hand modifier cluster: `Ctrl + Alt`.

### Column Snapping
| Shortcut | Action |
|---|---|
| `Ctrl + Alt + A` | Snap focused window to **Left** column |
| `Ctrl + Alt + S` | Snap focused window to **Center** column |
| `Ctrl + Alt + D` | Snap focused window to **Right** column |

### Corner Snapping (Quadrants)
| Shortcut | Action |
|---|---|
| `Ctrl + Alt + Q` | Snap to **Top-Left** quadrant |
| `Ctrl + Alt + Z` | Snap to **Bottom-Left** quadrant |
| `Ctrl + Alt + E` | Snap to **Top-Right** quadrant |
| `Ctrl + Alt + C` | Snap to **Bottom-Right** quadrant |

### Profile Selection
| Shortcut | Action |
|---|---|
| ``Ctrl + Alt + ` `` | **Cycle** to next layout profile (2 → 3 → 4 → 5 → 6 → 2) |
| `Ctrl + Alt + 2` | Switch directly to **Halves** `[ 1/2 ][ 1/2 ]` |
| `Ctrl + Alt + 3` | Switch directly to **Thirds** `[ 1/3 ][ 1/3 ][ 1/3 ]` |
| `Ctrl + Alt + 4` | Switch directly to **Fourths** `[ 1/4 ][ 1/2 ][ 1/4 ]` |
| `Ctrl + Alt + 5` | Switch directly to **Fifths** `[ 1/5 ][ 3/5 ][ 1/5 ]` |
| `Ctrl + Alt + 6` | Switch directly to **Sixths** `[ 1/6 ][ 2/3 ][ 1/6 ]` |

---

## 🖱️ Mouse Drag Snapping

Drag any standard macOS window by its titlebar toward screen boundaries:

1. **Center Stage**:
   - Drag into the **center column anywhere from the Dock up to 2/3 of the vertical screen height** (or all the way to the bottom Dock bezel).
   - Hold for **50ms**: a blue translucent preview footprint will appear.
   - Release the mouse button to snap!
2. **Side Columns**:
   - Drag to the **left** or **right** screen edge.
   - Hold for 50ms until armed, then release.
3. **Corner Quadrants**:
   - Drag to any of the 4 screen corners to snap into half-height corner slots.
4. **Mission Control Protection**:
   - The **top 1/3 of the screen** (and the top-center edge) does not trigger center snapping, leaving Mission Control, fullscreen spaces, and menu bar access completely conflict-free.
5. **Accidental Drag Cancellation**:
   - Quickly dragging a window past an edge or through the center without pausing for 50ms will **not** snap.
   - Pulling the window back before releasing cancels the snap.

---

## 🏗️ Project Architecture

```
~/.hammerspoon/
├── init.lua                 # Lightweight entrypoint & global exporter
├── .gitignore               # Ignores macOS artifacts
├── README.md                # Documentation & shortcut reference
└── engine/
    ├── config.lua           # Profiles (2–6), thresholds, timing, and UI styles
    ├── geometry.lua         # Pure layout solver & frame calculation math
    ├── animation.lua        # Synchronized 60 FPS master animation loop with easeOutQuad
    ├── shift_control.lua    # Modifier Control Mode: 3-column layout, position key cycling & instant release
    ├── halves_picker.lua    # Glassmorphic modal for routing center windows to halves
    ├── preview.lua          # Canvas visual footprint overlay manager
    ├── hud.lua              # Glassmorphic HUD with real-time SVG ultrawide split layout previews
    ├── mouse.lua            # Dock-aware snap detection, 50ms dwell timer & event tap
    ├── hotkeys.lua          # Keyboard shortcuts (Ctrl + Alt cluster)
    └── init.lua             # Central Engine coordinator & lifecycle manager
```

---

## 🖥️ Glassmorphic Profile HUD with SVG Split Previews

When switching layout profiles (or cycling through them via ``Ctrl + Alt + ` ``), the engine displays a floating glassmorphic HUD centered on your display.

Instead of basic text alerts, the HUD renders an **interactive SVG ultrawide monitor layout diagram**:
- **Proportional Splits**: Renders the exact column ratios (Halves `50%/50%`, Thirds `33.3%`, Fourths `25%/50%/25%`, Fifths `20%/60%/20%`, Sixths `16.7%/66.7%/16.7%`).
- **Visual Hierarchy**: The primary center stage column is highlighted with an accented gradient and glow, while side columns display exact fractional and percentage metrics.
- **Flicker-Free Cycling**: When rapidly switching or cycling profiles, the HUD updates in-place seamlessly and automatically fades away smoothly after 1.4 seconds.

---

## ⌃⌥⇧ Modifier Control Mode & Instant Position-Key Stack Cycling

Holding down the main modifiers along with Shift (**`Ctrl + Alt + Shift`** / **`⌃⌥⇧`**) instantly activates **Modifier Control Mode**, displaying a glassmorphic 3-column HUD across your screen that mirrors your ultrawide monitor layout.

```
+---------------------------------------------------------------------------------------+
|  [^⌥⇧ WINDOW CONTROL]                 CENTER COLUMN                       [Esc] Cancel|
+---------------------------------------------------------------------------------------+
|   [ A ] LEFT (25%)          |        [ S ] CENTER (50%)        |   [ D ] RIGHT (25%)  |
|                             |                                  |                      |
|  * Chrome (active)          |   * Cursor IDE (active)          |  * Spotify (active)  |
|  * Slack                    |   * Terminal                     |                      |
|                             |   * Notes                        |                      |
+---------------------------------------------------------------------------------------+
|  HOLD [A], [S], [D] TO CYCLE WINDOWS IN THAT POSITION • [W/X/F] HEIGHT • RELEASE TO COMMIT |
+---------------------------------------------------------------------------------------+
```

### Features:
1. **Instant 0ms Activation (`Ctrl + Alt + Shift`)**: Holding `Ctrl + Alt + Shift` immediately pops up the 3-column layout HUD (< 35ms, with zero synchronous screenshot overhead). Normal `Shift` key usage across all other apps remains 100% normal and untouched.
2. **Direct Position-Key Stack Cycling**:
   - Hold or tap **`A`**: Targets the **Left** column and cycles through all windows stacked in that position (`1` → `2` → `3` → `1`), bringing each one to the front and focusing it.
   - Hold or tap **`S`**: Targets the **Center** column and cycles through all windows stacked in Center stage.
   - Hold or tap **`D`**: Targets the **Right** column and cycles through all windows stacked in the Right position.
   - If a column is empty, pressing its key snaps the active window into that position immediately.
3. **Instant Zero-Delay Release**:
   - The exact millisecond you release `Ctrl`, `Alt`, or `Shift`, the GUI vanishes immediately (< 7ms) with zero debounces, no timers, and no residual delay.
4. **Height & Corner Controls**:
   - `W`: Top Half of current column
   - `X`: Bottom Half of current column
   - `F`: Full Height of current column
   - `Q` / `Z` / `E` / `C`: Corner quadrant snaps
   - `Esc`: Immediate cancel without altering window positions

---

## 🪟 Interactive Halves Window Assignment

When working in a 3-column layout (Thirds, Fourths, Fifths, Sixths), you may have primary tasks running in the center stage. When switching or cycling to **Halves (`1/2 1/2`)**, there is no natural center column.

Instead of arbitrarily dropping or forcing center windows into an unintended position, the engine presents an elegant glassmorphic modal:

1. **App Identity**: Shows each center window's application icon (extracted via bundle ID) and live thumbnail snapshot.
2. **Interactive Choice**:
   - Click the **Left** arrow button or press `←` / `1` to glide that window to the left 50% half.
   - Click the **Right** arrow button or press `→` / `2` to glide that window to the right 50% half.
   - Press `Esc` to dismiss the picker and leave any remaining center windows in place.
3. **Micro-Animations**: Cards slide smoothly out of view in the chosen direction and automatically dismiss when all center windows are assigned.

---

## ⚙️ Customization

Tuning values can be adjusted in [`engine/config.lua`](engine/config.lua):

```lua
-- Timing
hold_delay = 0.05,            -- Hold at edge for ~50ms before arming snap & showing preview
animation_duration = 0.25,    -- Buttery smooth 250ms window snap animation

-- Spatial Thresholds (pixels & ratios)
edge_threshold = 35,          -- Distance from edge / Dock boundary to trigger snap zone
corner_threshold = 180,       -- Corner quadrant threshold
edge_hysteresis = 25,         -- Buffer to keep zone active during mouse jitter
corner_hysteresis = 20,       -- Buffer to keep corner zone active
center_drop_height_ratio = 2/3, -- Vertical span for center drop zone (from dock to 2/3 up the screen)
center_drop_margin = 50,      -- Horizontal buffer around center column bounds (pixels)

-- Behavior
refit_on_profile_change = true, -- Automatically refit snapped windows when changing profile
show_halves_picker = true,      -- Show interactive GUI picker for center windows when switching to Halves (1/2 1/2)
```

To reload changes immediately, press your Hammerspoon reload shortcut or run:
```bash
hs -c "hs.reload()"
```

---

## 💻 CLI Integration

The engine exposes methods to `_G.WindowEngine` for terminal scripting or external launchers (Raycast, Alfred, Shortcuts, Karabiner):

```bash
# Snap focused window to center
hs -c "WindowEngine:snap('center', 'full')"

# Switch to fifths profile
hs -c "WindowEngine:setProfile(5)"

# Cycle to next profile
hs -c "WindowEngine:cycleProfile()"

# Adjust animation duration (e.g. 0.25s)
hs -c "WindowEngine:setAnimationDuration(0.25)"
```

---

## 📋 Requirements & Permissions

1. macOS 12+ (tested through macOS 15+ Sequoia).
2. [Hammerspoon](https://www.hammerspoon.org/) installed.
3. Ensure Hammerspoon has **Accessibility** permissions enabled under:
   `System Settings > Privacy & Security > Accessibility`.

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
