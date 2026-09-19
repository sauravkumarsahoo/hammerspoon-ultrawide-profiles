-- =============================================================================
-- engine/hud.lua
-- On-screen HUD alert notifications
-- =============================================================================

local hud = {}

function hud.showHUD(profile, alert_style, duration)
  local message = string.format("LAYOUT: %s", profile.label)
  hs.alert.closeAll()
  hs.alert.show(message, alert_style, hs.screen.mainScreen(), duration or 1.2)
end

function hud.showNotice(message, alert_style, duration)
  hs.alert.closeAll()
  hs.alert.show(message, alert_style, hs.screen.mainScreen(), duration or 0.8)
end

return hud
