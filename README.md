# Ultrawide Window Engine for Hammerspoon

A lightweight, high-performance, modular window management engine built in Lua for [Hammerspoon](https://www.hammerspoon.org/). Originally optimized for 3440×1440 ultrawide monitors, it seamlessly adapts to any display aspect ratio and resolution.

---

## ✨ Highlights

- **Dynamic Column Profiles**: Choose between 2-column halves or 3-column layouts with customizable ratios (Thirds, Fourths, Fifths, Sixths).
- **Mission Control Safe Snapping**: Center Stage snapping triggers exclusively from the **bottom screen edge** (Dock-aware). The top-center edge is intentionally unmapped to avoid interfering with macOS Mission Control.
- **Hold-to-Snap Dwell Delay**: Avoid accidental snaps during fast cursor movement or window relocation. Holding at an edge for **200ms** arms the snap and softly fades in a visual footprint preview.
- **100 FPS Quick-yet-Graceful Animation**: Windows animate over **300ms** at 100 FPS (10ms tick rate) using a tailored quartic ease-out curve ($1 - (1-t)^3 \times (0.6(1-t) + 0.4)$). It traverses ~72% of the distance within the first 90ms for instantaneous responsiveness, followed by a feathered, silky landing.
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
| **Sixths** | `6` | `[ 1/6 ][        2/3         ][ 1/6 ]` | Left: 16.7%, Center: 66.7%, Right: 16.7% |

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
   - Drag to the **bottom edge of the screen** (hovering right above the Dock or into the bezel).
   - Hold for **200ms**: a blue translucent preview footprint will fade in.
   - Release the mouse button to snap!
2. **Side Columns**:
   - Drag to the **left** or **right** screen edge.
   - Hold for 200ms until armed, then release.
3. **Corner Quadrants**:
   - Drag to any of the 4 screen corners to snap into half-height corner slots.
4. **Mission Control Protection**:
   - The **top-center** screen border does not trigger snapping, leaving Mission Control and full-screen menu gestures completely conflict-free.
5. **Accidental Drag Cancellation**:
   - Quickly dragging a window past an edge without pausing for 200ms will **not** snap.
   - Pulling the window back toward screen center before releasing cancels the snap.

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
    ├── animation.lua        # 100 FPS animation engine with graceful easing curve
    ├── preview.lua          # Canvas visual footprint overlay manager
    ├── hud.lua              # HUD on-screen alert notifications
    ├── mouse.lua            # Dock-aware snap detection, 200ms dwell timer & event tap
    ├── hotkeys.lua          # Keyboard shortcuts (Ctrl + Alt cluster)
    └── init.lua             # Central Engine coordinator & lifecycle manager
```

---

## ⚙️ Customization

Tuning values can be adjusted in [`engine/config.lua`](engine/config.lua):

```lua
-- Timing
hold_delay = 0.20,            -- Hold at edge for ~200ms before arming snap & showing preview
animation_duration = 0.30,    -- Quick yet graceful 300ms window snap animation

-- Spatial Thresholds (pixels)
edge_threshold = 35,          -- Distance from edge / Dock boundary to trigger snap zone
corner_threshold = 180,       -- Corner quadrant threshold
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
