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
    self.canvas:level(hs.canvas.windowLevels.overlay)
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
    self.canvas:show(fadeInTime or 0.08)
  end

  function instance:hide(fadeOutTime)
    if self.canvas then
      self.canvas:hide(fadeOutTime or 0.10)
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
