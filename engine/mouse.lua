-- =============================================================================
-- engine/mouse.lua
-- Snap zone detection, 50ms dwell hold timer, hysteresis, and mouse drag event tap
-- =============================================================================

local mouseModule = {}

-- Helper: Validate whether a window is manageable for snapping
function mouseModule.isValidWindow(w)
  if not w then return false end
  local ok, std = pcall(function() return w:isStandard() end)
  if ok and std then return true end
  local ok2, subrole = pcall(function() return w:subrole() end)
  local ok3, role = pcall(function() return w:role() end)
  if ok2 and ok3 and role == "AXWindow" and subrole == "AXDialog" then
    local app = w:application()
    local appName = app and app:name()
    if appName and appName ~= "Hammerspoon" and appName ~= "MenuBarAgent" and (w:title() or "") ~= "" then
      return true
    end
  end
  return false
end

-- Helper: Find window under mouse cursor (checks focusedWindow first for 0.2ms fast path)
function mouseModule.getWindowUnderMouse(p)
  p = p or hs.mouse.absolutePosition()
  local fw = hs.window.focusedWindow()
  if fw and mouseModule.isValidWindow(fw) and fw:isVisible() and not fw:isMinimized() then
    local f = fw:frame()
    if p.x >= f.x and p.x <= f.x + f.w and p.y >= f.y and p.y <= f.y + f.h then
      return fw
    end
  end
  local wins = hs.window.orderedWindows()
  for _, w in ipairs(wins) do
    if mouseModule.isValidWindow(w) and w:isVisible() and not w:isMinimized() then
      local f = w:frame()
      if p.x >= f.x and p.x <= f.x + f.w and p.y >= f.y and p.y <= f.y + f.h then
        return w
      end
    end
  end
  return nil
end

-- Snap Zone Detector with Hysteresis
--   Bottom edge -> center full (3-col) or halves, and bottom corners (dock-aware)
--   Top edge    -> corners only (middle returns nil to prevent Mission Control conflict!)
--   Left/Right  -> full height and corners
function mouseModule.detectSnapZone(mousePos, fFrame, uFrame, config, profile, activeZone)
  local base_edge = config.edge_threshold or 35
  local base_corner = config.corner_threshold or 180

  -- Hysteresis: if already in a snap zone, provide a buffer so mouse jitter
  -- doesn't abruptly drop out of the zone while dwelling or armed
  local edge = base_edge + (activeZone and (config.edge_hysteresis or 25) or 0)
  local corner = base_corner + (activeZone and activeZone.row ~= "full" and (config.corner_hysteresis or 20) or 0)

  local usable_top = (uFrame and uFrame.y) or fFrame.y
  local usable_bottom = (uFrame and (uFrame.y + uFrame.h)) or (fFrame.y + fFrame.h)
  local usable_h = usable_bottom - usable_top

  -- 1. Left screen border
  if mousePos.x <= fFrame.x + edge then
    if mousePos.y <= usable_top + corner then
      return {col = "left", row = "top"}
    elseif mousePos.y >= usable_bottom - corner then
      return {col = "left", row = "bottom"}
    else
      return {col = "left", row = "full"}
    end
  end

  -- 2. Right screen border
  if mousePos.x >= fFrame.x + fFrame.w - edge then
    if mousePos.y <= usable_top + corner then
      return {col = "right", row = "top"}
    elseif mousePos.y >= usable_bottom - corner then
      return {col = "right", row = "bottom"}
    else
      return {col = "right", row = "full"}
    end
  end

  -- 3. Top screen border (Only corners! Middle of top edge returns nil to leave Mission Control unhindered)
  local top_threshold_y = usable_top + edge
  if mousePos.y <= top_threshold_y then
    if mousePos.x <= fFrame.x + corner then
      return {col = "left", row = "top"}
    elseif mousePos.x >= fFrame.x + fFrame.w - corner then
      return {col = "right", row = "top"}
    end
    -- Middle of top edge returns nil!
  end

  -- 4. Bottom corners & Halves profile bottom split
  -- Subtract edge from usable_bottom so cursor triggers comfortably above and into the Dock
  local bottom_threshold_y = usable_bottom - edge
  if mousePos.y >= bottom_threshold_y then
    if mousePos.x <= fFrame.x + corner then
      return {col = "left", row = "bottom"}
    elseif mousePos.x >= fFrame.x + fFrame.w - corner then
      return {col = "right", row = "bottom"}
    elseif profile.id == "halves" then
      if mousePos.x < fFrame.x + math.floor(fFrame.w / 2) then
        return {col = "left", row = "full"}
      else
        return {col = "right", row = "full"}
      end
    else
      -- At bottom dock in 3-column profiles: triggers Center Stage
      return {col = "center", row = "full"}
    end
  end

  -- 5. Center Stage Drop Zone: extends from dock to 2/3 up the vertical screen
  if profile.id ~= "halves" then
    local center_ratio = config.center_drop_height_ratio or (2/3)
    local center_h = usable_h * center_ratio
    local center_hysteresis = (activeZone and activeZone.col == "center") and (config.edge_hysteresis or 25) or 0
    local center_threshold_y = usable_bottom - math.floor(center_h) - center_hysteresis

    if mousePos.y >= center_threshold_y then
      local margin = config.center_drop_margin or 50
      local left_w = fFrame.w * profile.left
      local right_w = fFrame.w * profile.right
      local center_min_x = fFrame.x + math.floor(left_w) - margin - center_hysteresis
      local center_max_x = fFrame.x + fFrame.w - math.floor(right_w) + margin + center_hysteresis

      if mousePos.x >= center_min_x and mousePos.x <= center_max_x then
        return {col = "center", row = "full"}
      end
    end
  end

  return nil
end

-- Create the EventTap with 50ms dwell delay and smooth animation commit
function mouseModule.createEventTap(engine)
  local state = {
    targetWindow = nil,
    activeZone = nil,
    snapArmed = false,
    dwellTimer = nil
  }

  local function cancelDwell()
    if state.dwellTimer then
      state.dwellTimer:stop()
      state.dwellTimer = nil
    end
    state.snapArmed = false
  end

  local tap = hs.eventtap.new({
    hs.eventtap.event.types.leftMouseDown,
    hs.eventtap.event.types.leftMouseDragged,
    hs.eventtap.event.types.leftMouseUp
  }, function(event)
    if not engine.mouse_snap_enabled then return false end

    local eventType = event:getType()

    if eventType == hs.eventtap.event.types.leftMouseDown then
      cancelDwell()
      if engine.preview then engine.preview:hide() end
      local mousePos = hs.mouse.absolutePosition()
      state.targetWindow = mouseModule.getWindowUnderMouse(mousePos) or hs.window.focusedWindow()
      state.activeZone = nil

    elseif eventType == hs.eventtap.event.types.leftMouseDragged then
      local mousePos = hs.mouse.absolutePosition()
      local screen = hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
      local fFrame = screen:fullFrame()
      local uFrame = screen:frame()
      local profile = engine:getCurrentProfile()
      local zone = mouseModule.detectSnapZone(mousePos, fFrame, uFrame, engine.config, profile, state.activeZone)

      if zone then
        local win = state.targetWindow
        if not win or not mouseModule.isValidWindow(win) then
          win = mouseModule.getWindowUnderMouse(mousePos) or hs.window.focusedWindow()
          state.targetWindow = win
        end

        if win and mouseModule.isValidWindow(win) then
          local isSameZone = state.activeZone and
                             state.activeZone.col == zone.col and
                             state.activeZone.row == zone.row

          if not isSameZone then
            -- Zone entered or changed: restart 50ms dwell timer
            cancelDwell()
            state.activeZone = zone
            if engine.preview then engine.preview:hide() end

            state.dwellTimer = hs.timer.doAfter(engine.config.hold_delay, function()
              state.dwellTimer = nil
              if state.activeZone and engine.preview then
                state.snapArmed = true
                local target = engine.geometry.calculateFrame(
                  profile,
                  state.activeZone.col,
                  state.activeZone.row,
                  uFrame,
                  state.targetWindow
                )
                engine.preview:show(target)
              end
            end)
          end
        end
      else
        -- Cursor left snap zone
        if state.activeZone then
          cancelDwell()
          state.activeZone = nil
          if engine.preview then engine.preview:hide() end
        end
      end

    elseif eventType == hs.eventtap.event.types.leftMouseUp then
      local wasArmed = state.snapArmed
      local zone = state.activeZone
      local win = state.targetWindow or hs.window.focusedWindow()

      cancelDwell()

      if engine.preview then engine.preview:hide() end

      if wasArmed and zone and win and mouseModule.isValidWindow(win) then
        local targetWin = win
        local targetZone = zone
        -- Small 10ms delay allows macOS WindowServer to finish the native drag release
        -- before our animation engine takes full control of the window coordinates
        hs.timer.doAfter(0.01, function()
          if not targetWin or not targetWin:isVisible() then
            targetWin = hs.window.focusedWindow()
          end
          if targetWin and mouseModule.isValidWindow(targetWin) then
            local screen = targetWin:screen() or hs.screen.mainScreen()
            local uFrame = screen:frame()
            local profile = engine:getCurrentProfile()
            local target = engine.geometry.calculateFrame(
              profile,
              targetZone.col,
              targetZone.row,
              uFrame,
              targetWin
            )
            engine.animation.animate(targetWin, target, engine.config.animation_duration)
          end
        end)
      end

      state.activeZone = nil
      state.targetWindow = nil
    end

    return false
  end)

  return tap, state
end

return mouseModule
