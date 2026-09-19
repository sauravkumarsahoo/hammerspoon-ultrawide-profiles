-- =============================================================================
-- engine/geometry.lua
-- Pure layout solver & frame calculation logic
-- =============================================================================

local geometry = {}

function geometry.calculateFrame(profile, split_horizontal, col, row, screen, win)
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
  local is_split = split_horizontal and (col == "left" or col == "right")
  if is_split and row ~= "full" then
    h = math.floor(screen.h / 2)
    y = (row == "top") and screen.y or (screen.y + (screen.h - h))
  elseif row == "top" then
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

return geometry
