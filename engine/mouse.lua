-- =============================================================================
-- engine/mouse.lua
-- Snap zone detection, 200ms dwell hold timer, and mouse drag event tap
-- =============================================================================

local mouseModule = {}

-- Helper: Find standard window under mouse cursor
function mouseModule.getWindowUnderMouse(p)
  p = p or hs.mouse.absolutePosition()
  local wins = hs.window.orderedWindows()
  for _, w in ipairs(wins) do
    if w:isStandard() and w:isVisible() and not w:isMinimized() then
      local f = w:frame()
      if p.x >= f.x and p.x <= f.x + f.w and p.y >= f.y and p.y <= f.y + f.h then
        return w
      end
    end
  end
  return nil
end

-- Snap Zone Detector
--   Bottom edge -> center full (3-col) or halves, and bottom corners (dock-aware)
--   Top edge    -> corners only (middle returns nil to prevent Mission Control conflict!)
--   Left/Right  -> full height and corners
function mouseModule.detectSnapZone(mousePos, fFrame, uFrame, config, profile)
  local edge = config.edge_threshold
  local corner = config.corner_threshold

  local usable_top = (uFrame and uFrame.y) or fFrame.y
  local usable_bottom = (uFrame and (uFrame.y + uFrame.h)) or (fFrame.y + fFrame.h)

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

  -- 3. Bottom screen border (Center Stage & bottom corners)
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
      -- 3-Column profiles: Bottom Center triggers Center Stage!
      return {col = "center", row = "full"}
    end
  end

  -- 4. Top screen border (Only corners! Middle of top edge returns nil to leave Mission Control unhindered)
  local top_threshold_y = usable_top + edge
  if mousePos.y <= top_threshold_y then
    if mousePos.x <= fFrame.x + corner then
      return {col = "left", row = "top"}
    elseif mousePos.x >= fFrame.x + fFrame.w - corner then
      return {col = "right", row = "top"}
    end
    -- Middle of top edge returns nil!
  end

  return nil
end

-- Create the EventTap with 200ms dwell delay and smooth animation commit
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
      local zone = mouseModule.detectSnapZone(mousePos, fFrame, uFrame, engine.config, profile)

      if zone then
        local win = state.targetWindow
        if not win or not win:isStandard() then
          win = mouseModule.getWindowUnderMouse(mousePos) or hs.window.focusedWindow() or hs.window.orderedWindows()[1]
          state.targetWindow = win
        end

        if win and win:isStandard() then
          local isSameZone = state.activeZone and
                             state.activeZone.col == zone.col and
                             state.activeZone.row == zone.row

          if not isSameZone then
            -- Zone entered or changed: restart 200ms dwell timer
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
                engine.preview:show(target, 0.08)
              end
            end)
          end
        end
      else
        -- Cursor left snap zone
        if state.activeZone then
          cancelDwell()
          state.activeZone = nil
          if engine.preview then engine.preview:hide(0.10) end
        end
      end

    elseif eventType == hs.eventtap.event.types.leftMouseUp then
      local wasArmed = state.snapArmed
      local zone = state.activeZone
      local win = state.targetWindow or hs.window.focusedWindow()

      if state.dwellTimer then
        state.dwellTimer:stop()
        state.dwellTimer = nil
      end
      state.snapArmed = false

      if engine.preview then engine.preview:hide(0.10) end

      if wasArmed and zone and win then
        local targetWin = win
        local targetZone = zone
        -- Small 10ms delay allows macOS WindowServer to finish the native drag release
        -- before our animation engine takes full control of the window coordinates
        hs.timer.doAfter(0.01, function()
          if not targetWin or not targetWin:isVisible() then
            targetWin = hs.window.focusedWindow()
          end
          if targetWin and targetWin:isStandard() then
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
