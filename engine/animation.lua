-- =============================================================================
-- engine/animation.lua
-- 100 FPS animation engine with a quick yet graceful easing curve
-- =============================================================================

local animation = {
  activeAnimations = {}
}

-- Easing curve: Quick initial burst followed by a feathered, graceful deceleration
-- Reaches ~72% distance in first 30% of time, with zero velocity and acceleration at rest
local function easeQuickGraceful(t)
  if t <= 0 then return 0 end
  if t >= 1 then return 1 end
  local f = 1 - t
  return 1 - (f * f * f * (0.6 * f + 0.4))
end

function animation.animate(win, target, duration)
  if not win then return end
  local id = win:id()
  if not id then
    win:setFrame(target, 0)
    return
  end

  -- Stop and replace any active animation on this window
  if animation.activeAnimations[id] then
    animation.activeAnimations[id].timer:stop()
    animation.activeAnimations[id] = nil
  end

  duration = duration or 0.30
  if duration <= 0 then
    win:setFrame(target, 0)
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

  local startTime = hs.timer.secondsSinceEpoch()
  local animEntry = {}

  -- 10ms timer provides 100 FPS updates
  animEntry.timer = hs.timer.new(0.010, function()
    local now = hs.timer.secondsSinceEpoch()
    local progress = (now - startTime) / duration

    if progress >= 1 then
      animEntry.timer:stop()
      animation.activeAnimations[id] = nil
      win:setFrame(target, 0)
    else
      local r = easeQuickGraceful(progress)
      local currentFrame = {
        x = math.floor(start.x + (target.x - start.x) * r + 0.5),
        y = math.floor(start.y + (target.y - start.y) * r + 0.5),
        w = math.floor(start.w + (target.w - start.w) * r + 0.5),
        h = math.floor(start.h + (target.h - start.h) * r + 0.5)
      }
      local ok = pcall(function() win:_setFrame(currentFrame) end)
      if not ok then
        animEntry.timer:stop()
        animation.activeAnimations[id] = nil
        win:setFrame(target, 0)
      end
    end
  end)

  animation.activeAnimations[id] = animEntry
  animEntry.timer:start()
end

function animation.stopAll()
  for id, anim in pairs(animation.activeAnimations) do
    if anim.timer then
      anim.timer:stop()
    end
  end
  animation.activeAnimations = {}
end

return animation
