-- =============================================================================
-- engine/preview.lua
-- Reusable canvas overlay for visual footprint preview
-- =============================================================================

local preview = {}

function preview.new(style)
  local instance = {
    canvas = nil,
    style = style
  }

  function instance:init()
    if self.canvas then
      self.canvas:delete()
    end
    self.canvas = hs.canvas.new({x = 0, y = 0, w = 0, h = 0})
    -- High assistive tech window level guarantees preview is never covered by dragged windows
    self.canvas:level(hs.canvas.windowLevels.assistiveTechHigh)
    self.canvas[1] = {
      type = "rectangle",
      action = "strokeAndFill",
      roundedRectRadii = {xRadius = self.style.radius or 14, yRadius = self.style.radius or 14},
      fillColor   = self.style.fillColor,
      strokeColor = self.style.strokeColor,
      strokeWidth = self.style.strokeWidth or 2.5
    }
  end

  function instance:show(targetFrame, fadeInTime)
    if not self.canvas then self:init() end
    self.canvas:frame(targetFrame)
    self.canvas:alpha(1.0)
    if fadeInTime and fadeInTime > 0 then
      self.canvas:show(fadeInTime)
    else
      self.canvas:show()
    end
  end

  function instance:hide(fadeOutTime)
    if self.canvas and self.canvas:isShowing() then
      if fadeOutTime and fadeOutTime > 0 then
        self.canvas:hide(fadeOutTime)
      else
        -- Instant synchronous hide eliminates AppKit NSAnimationContext race conditions
        self.canvas:hide()
        self.canvas:alpha(1.0)
      end
    end
  end

  function instance:destroy()
    if self.canvas then
      self.canvas:delete()
      self.canvas = nil
    end
  end

  instance:init()
  return instance
end

return preview
