-- =============================================================================
-- engine/init.lua
-- Central Engine coordinator assembling all modules
-- =============================================================================

local config    = require("engine.config")
local geometry  = require("engine.geometry")
local animation = require("engine.animation")
local preview   = require("engine.preview")
local hud       = require("engine.hud")
local mouse     = require("engine.mouse")
local hotkeys   = require("engine.hotkeys")

local Engine = {
  config = config,
  geometry = geometry,
  animation = animation,
  hud = hud,
  mouse = mouse,
  hotkeys = hotkeys,

  current_profile = config.default_profile,
  previous_profile = nil,
  mouse_snap_enabled = true,

  preview = nil,
  eventTap = nil,
  mouseState = nil
}

function Engine:getCurrentProfile()
  return self.config.profiles[self.current_profile]
end

function Engine:showHUD()
  self.hud.showHUD(self:getCurrentProfile(), self.config.alert_style)
end

function Engine:resolveProfileIndex(val)
  if type(val) == "number" then
    if val >= 2 and val <= 6 then
      return val - 1
    else
      return ((val - 1) % #self.config.profiles) + 1
    end
  elseif type(val) == "string" then
    val = val:lower()
    local num = tonumber(val)
    if num and num >= 2 and num <= 6 then
      return num - 1
    end
    for i, p in ipairs(self.config.profiles) do
      if p.id == val or tostring(p.denominator) == val then
        return i
      end
    end
  end
  return nil
end

function Engine:setProfile(val)
  local target_idx = self:resolveProfileIndex(val)
  if target_idx then
    self.previous_profile = self.current_profile
    self.current_profile = target_idx
    self:showHUD()
  end
end

function Engine:toggleProfile(val)
  local target_idx = self:resolveProfileIndex(val)
  if not target_idx then return end

  if self.current_profile == target_idx and self.previous_profile then
    local prev = self.previous_profile
    self.previous_profile = self.current_profile
    self.current_profile = prev
  else
    self.previous_profile = self.current_profile
    self.current_profile = target_idx
  end
  self:showHUD()
end

function Engine:cycleProfile()
  self.previous_profile = self.current_profile
  self.current_profile = (self.current_profile % #self.config.profiles) + 1
  self:showHUD()
end

function Engine:setAnimationDuration(sec)
  self.config.animation_duration = tonumber(sec) or 0.30
  hs.window.animationDuration = self.config.animation_duration
  self.hud.showNotice(string.format("ANIMATION: %.2fs", self.config.animation_duration), self.config.alert_style, 0.8)
end

function Engine:setHoldDelay(sec)
  self.config.hold_delay = tonumber(sec) or 0.20
  self.hud.showNotice(string.format("HOLD DELAY: %.2fs", self.config.hold_delay), self.config.alert_style, 0.8)
end

function Engine:toggleMouseSnap(force_state)
  if force_state ~= nil then
    self.mouse_snap_enabled = force_state
  else
    self.mouse_snap_enabled = not self.mouse_snap_enabled
  end
  local status = self.mouse_snap_enabled and "ENABLED" or "DISABLED"
  self.hud.showNotice(string.format("MOUSE SNAP: %s", status), self.config.alert_style, 0.8)
end

-- Geometry calculation proxy
function Engine:calculateFrame(col, row, screen, win)
  return self.geometry.calculateFrame(self:getCurrentProfile(), col, row, screen, win)
end

-- Snap window via hotkey or programmatic call
function Engine:snap(col, row)
  local win = hs.window.focusedWindow()
  if not win then return end
  local screen = win:screen():frame()
  local target = self:calculateFrame(col, row, screen, win)
  self.animation.animate(win, target, self.config.animation_duration)
end

-- Backward compatibility proxies for CLI and external scripts
function Engine:detectSnapZone(mousePos, fFrame, uFrame)
  return self.mouse.detectSnapZone(mousePos, fFrame, uFrame, self.config, self:getCurrentProfile())
end

-- Expose profiles table directly on Engine for backward compatibility
Engine.profiles = config.profiles

-- Start Engine services
function Engine:start()
  self:stop()

  hs.window.animationDuration = self.config.animation_duration
  self.preview = preview.new(self.config.preview_style)

  self.eventTap, self.mouseState = self.mouse.createEventTap(self)
  self.eventTap:start()

  self.hotkeys.bindAll(self)
end

-- Stop Engine services and cleanup resources
function Engine:stop()
  if self.eventTap then
    self.eventTap:stop()
    self.eventTap = nil
  end
  if self.mouseState and self.mouseState.dwellTimer then
    self.mouseState.dwellTimer:stop()
    self.mouseState.dwellTimer = nil
  end
  if self.preview then
    self.preview:destroy()
    self.preview = nil
  end
  self.animation.stopAll()
  self.hotkeys.unbindAll()
end

return Engine
