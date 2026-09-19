-- =============================================================================
-- engine/geometry.lua
-- Pure layout solver & frame calculation logic
-- =============================================================================

local geometry = {}

function geometry.calculateFrame(profile, col, row, screen, win)
  screen = screen or hs.screen.mainScreen():frame()

  local x, w, y, h

  if profile.id == "halves" then
    local half_w = math.floor(screen.w / 2)

    -- If 'center' is requested under halves, alternate between left and right based on win position
    if col == "center" then
      win = win or hs.window.focusedWindow()
      if win then
        local win_frame = win:frame()
        local win_center_x = win_frame.x + math.floor(win_frame.w / 2)
        local screen_mid_x = screen.x + half_w
        if win_center_x >= screen_mid_x then
          col = "left"
        else
          col = "right"
        end
      else
        col = "left"
      end
    end

    if col == "left" then
      x = screen.x
      w = half_w
    elseif col == "right" then
      x = screen.x + half_w
      w = screen.w - half_w
    elseif col == "maximize" or col == "full" then
      x = screen.x
      w = screen.w
    end
  else
    -- 3-Column Profiles (thirds, fourths, fifths, sixths)
    local w_left   = math.floor(screen.w * profile.left)
    local w_right  = math.floor(screen.w * profile.right)
    local w_center = screen.w - (w_left + w_right)

    if col == "left" then
      x = screen.x
      w = w_left
    elseif col == "center" then
      x = screen.x + w_left
      w = w_center
    elseif col == "right" then
      x = screen.x + screen.w - w_right
      w = w_right
    elseif col == "maximize" or col == "full" then
      x = screen.x
      w = screen.w
    end
  end

  -- Vertical Allocation
  if row == "top" then
    h = math.floor(screen.h / 2)
    y = screen.y
  elseif row == "bottom" then
    h = math.floor(screen.h / 2)
    y = screen.y + (screen.h - h)
  else
    y = screen.y
    h = screen.h
  end

  return {x = x, y = y, w = w, h = h}
end

-- Detect if a window matches any valid snap slot under a given profile
function geometry.detectWindowSlot(win, profile, screenFrame, tolerance)
  if not win then return nil end
  tolerance = tolerance or 5
  screenFrame = screenFrame or (type(win.screen) == "function" and win:screen() and win:screen():frame()) or hs.screen.mainScreen():frame()

  local f = (type(win.frame) == "function" and win:frame()) or win
  local slots = {
    {col = "left", row = "full"},
    {col = "right", row = "full"},
    {col = "left", row = "top"},
    {col = "left", row = "bottom"},
    {col = "right", row = "top"},
    {col = "right", row = "bottom"},
  }
  if profile.id ~= "halves" then
    table.insert(slots, {col = "center", row = "full"})
  end

  for _, slot in ipairs(slots) do
    local target = geometry.calculateFrame(profile, slot.col, slot.row, screenFrame, win)
    if math.abs(f.x - target.x) <= tolerance and
       math.abs(f.y - target.y) <= tolerance and
       math.abs(f.w - target.w) <= tolerance and
       math.abs(f.h - target.h) <= tolerance then
      return slot
    end
  end
  return nil
end

-- Find matching slot for window, checking preferredProfile first, then fallback across allProfiles
function geometry.findMatchingSlot(win, preferredProfile, allProfiles, screenFrame, tolerance)
  if not win then return nil end
  tolerance = tolerance or 5
  screenFrame = screenFrame or (type(win.screen) == "function" and win:screen() and win:screen():frame()) or hs.screen.mainScreen():frame()

  if preferredProfile then
    local slot = geometry.detectWindowSlot(win, preferredProfile, screenFrame, tolerance)
    if slot then return slot, preferredProfile end
  end

  if allProfiles then
    for _, prof in ipairs(allProfiles) do
      if not preferredProfile or prof.id ~= preferredProfile.id then
        local slot = geometry.detectWindowSlot(win, prof, screenFrame, tolerance)
        if slot then return slot, prof end
      end
    end
  end

  return nil, nil
end

return geometry
