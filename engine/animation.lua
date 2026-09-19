-- =============================================================================
-- engine/animation.lua
-- Synchronized 60 FPS master-loop animation engine with smooth cubic ease-out
-- =============================================================================

local animation = {
  activeAnimations = {},
  masterTimer = nil,
  frameInterval = 0.016 -- 60 FPS (16ms) provides rock-solid redraw cadence for macOS & WebKit/Chromium
}

-- Detect current screen refresh rate dynamically (backward compatibility proxy)
function animation.getScreenRefreshRate(screen)
  screen = screen or hs.screen.mainScreen()
  if screen then
    local mode = screen:currentMode()
    if mode and mode.freq and mode.freq > 0 then
      return mode.freq
    end
  end
  return 60
end

-- Easing curve: Smooth quadratic ease-out (t * (2 - t))
-- Matches macOS native window physics: steady, natural deceleration with zero initial jerk
local function easeOutQuad(t)
  if t <= 0 then return 0 end
  if t >= 1 then return 1 end
  return t * (2 - t)
end

-- Central synchronized tick for all active window animations
local function masterTick()
  local now = hs.timer.secondsSinceEpoch()
  local hasActive = false

  for id, anim in pairs(animation.activeAnimations) do
    local progress = (now - anim.startTime) / anim.duration

    if progress >= 1 then
      animation.activeAnimations[id] = nil
      pcall(function() anim.win:_setFrame(anim.target) end)
    else
      hasActive = true
      local r = easeOutQuad(progress)
      local currentFrame = {
        x = math.floor(anim.start.x + (anim.target.x - anim.start.x) * r + 0.5),
        y = math.floor(anim.start.y + (anim.target.y - anim.start.y) * r + 0.5),
        w = math.floor(anim.start.w + (anim.target.w - anim.start.w) * r + 0.5),
        h = math.floor(anim.start.h + (anim.target.h - anim.start.h) * r + 0.5)
      }
      pcall(function() anim.win:_setFrame(currentFrame) end)
    end
  end

  if not hasActive and animation.masterTimer then
    animation.masterTimer:stop()
    animation.masterTimer = nil
  end
end

function animation.animate(win, target, duration)
  if not win then return end
  local id = win:id()
  if not id then
    pcall(function() win:_setFrame(target) end)
    return
  end

  duration = duration or 0.25
  if duration <= 0 then
    pcall(function() win:_setFrame(target) end)
    return
  end

  local start = win:frame()
  -- If already at target within 1px on all dimensions, skip animation
  if math.abs(start.x - target.x) < 1 and
     math.abs(start.y - target.y) < 1 and
     math.abs(start.w - target.w) < 1 and
     math.abs(start.h - target.h) < 1 then
    return
  end

  animation.activeAnimations[id] = {
    win = win,
    start = start,
    target = target,
    startTime = hs.timer.secondsSinceEpoch(),
    duration = duration
  }

  if not animation.masterTimer then
    animation.masterTimer = hs.timer.new(animation.frameInterval, masterTick)
    animation.masterTimer:start()
  end
end

function animation.stopAll()
  if animation.masterTimer then
    animation.masterTimer:stop()
    animation.masterTimer = nil
  end
  animation.activeAnimations = {}
end

return animation
