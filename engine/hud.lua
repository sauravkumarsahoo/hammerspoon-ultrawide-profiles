-- =============================================================================
-- engine/hud.lua
-- On-screen HUD alert notifications
-- =============================================================================

local hud = {}

function hud.showHUD(profile, split_horizontal, alert_style, duration)
  local split_text = split_horizontal and "ENABLED (Top/Bottom Corners)" or "DISABLED (Full Height)"
  local message = string.format("LAYOUT: %s\nCORNER SPLIT: %s", profile.label, split_text)
  hs.alert.closeAll()
  hs.alert.show(message, alert_style, hs.screen.mainScreen(), duration or 1.2)
end

function hud.showNotice(message, alert_style, duration)
  hs.alert.closeAll()
  hs.alert.show(message, alert_style, hs.screen.mainScreen(), duration or 0.8)
end

return hud
