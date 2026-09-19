-- =============================================================================
-- engine/config.lua
-- Configuration, profiles, timing, thresholds, and styling tokens
-- =============================================================================

local config = {
  profiles = {
    { id = "halves",  denominator = 2, label = "[      1/2       ][      1/2       ]", left = 1/2, center = 1/2, right = 1/2 },
    { id = "thirds",  denominator = 3, label = "[   1/3    ][   1/3    ][   1/3    ]", left = 1/3, center = 1/3, right = 1/3 },
    { id = "fourths", denominator = 4, label = "[  1/4  ][      1/2       ][  1/4  ]", left = 1/4, center = 2/4, right = 1/4 },
    { id = "fifths",  denominator = 5, label = "[ 1/5 ][        3/5         ][ 1/5 ]", left = 1/5, center = 3/5, right = 1/5 },
    { id = "sixths",  denominator = 6, label = "[ 1/6][         2/3          ][ 1/6]", left = 1/6, center = 4/6, right = 1/6 }
  },
  default_profile = 3, -- Default to fourths [  1/4  ][      1/2       ][  1/4  ]

  -- Timing
  hold_delay = 0.05,            -- Hold at edge for ~50ms before arming snap & showing preview
  animation_duration = 0.25,    -- Buttery smooth 250ms cubic ease-out animation

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
  shift_control_enabled = true,   -- Enable Shift-hold control mode for single-key positioning & window cycling

  -- UI Styles
  alert_style = {
    strokeWidth = 2,
    strokeColor = { white = 1, alpha = 0.8 },
    fillColor   = { hex = "#1e1e2e", alpha = 0.95 },
    textColor   = { white = 1, alpha = 1 },
    textFont    = "Menlo-Bold",
    textSize    = 18,
    radius      = 12,
    atScreenEdge = 0,
    fadeInDuration = 0.1,
    fadeOutDuration = 0.3
  },

  preview_style = {
    fillColor   = { hex = "#89b4fa", alpha = 0.25 },
    strokeColor = { hex = "#89b4fa", alpha = 0.85 },
    strokeWidth = 2.5,
    radius      = 14
  }
}

return config
