-- =============================================================================
-- engine/init.lua
-- Central Engine coordinator assembling all modules
-- =============================================================================

local config    = require("engine.config")
local geometry  = require("engine.geometry")
local animation = require("engine.animation")
local preview   = require("engine.preview")
local hud           = require("engine.hud")
local mouse         = require("engine.mouse")
local hotkeys       = require("engine.hotkeys")
local halves_picker = require("engine.halves_picker")
local shift_control = require("engine.shift_control")

local Engine = {
  config = config,
  geometry = geometry,
  animation = animation,
  hud = hud,
  mouse = mouse,
  hotkeys = hotkeys,
  halves_picker = halves_picker,
  shift_control = shift_control,

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
    local prev_profile = self:getCurrentProfile()
    self.previous_profile = self.current_profile
    self.current_profile = target_idx
    local new_profile = self:getCurrentProfile()
    self:showHUD()
    if self.config.refit_on_profile_change and prev_profile.id ~= new_profile.id then
      self:refitWindows(prev_profile, new_profile)
    end
  end
end

function Engine:toggleProfile(val)
  local target_idx = self:resolveProfileIndex(val)
  if not target_idx then return end

  if self.halves_picker and self.halves_picker.isOpen() then
    if target_idx == 1 then -- Profile 2 (Halves)
      self.halves_picker.chooseNext("right")
      return
    end
  end

  local prev_profile = self:getCurrentProfile()
  if self.current_profile == target_idx and self.previous_profile then
    local prev = self.previous_profile
    self.previous_profile = self.current_profile
    self.current_profile = prev
  else
    self.previous_profile = self.current_profile
    self.current_profile = target_idx
  end
  local new_profile = self:getCurrentProfile()
  self:showHUD()
  if self.config.refit_on_profile_change and prev_profile.id ~= new_profile.id then
    self:refitWindows(prev_profile, new_profile)
  end
end

function Engine:cycleProfile()
  local prev_profile = self:getCurrentProfile()
  self.previous_profile = self.current_profile
  self.current_profile = (self.current_profile % #self.config.profiles) + 1
  local new_profile = self:getCurrentProfile()
  self:showHUD()
  if self.config.refit_on_profile_change and prev_profile.id ~= new_profile.id then
    self:refitWindows(prev_profile, new_profile)
  end
end

function Engine:refitWindows(prevProfile, newProfile)
  newProfile = newProfile or self:getCurrentProfile()
  prevProfile = prevProfile or (self.previous_profile and self.config.profiles[self.previous_profile]) or newProfile

  local wins = hs.window.visibleWindows()
  local centerWindows = {}

  for _, win in ipairs(wins) do
    if self.mouse.isValidWindow(win) and not win:isMinimized() then
      local screen = win:screen() or hs.screen.mainScreen()
      local uFrame = screen:frame()
      local slot = self.geometry.findMatchingSlot(win, prevProfile, self.config.profiles, uFrame)
      if slot then
        if newProfile.id == "halves" and slot.col == "center" and self.config.show_halves_picker then
          table.insert(centerWindows, {win = win, slot = slot, screen = screen, uFrame = uFrame})
        else
          local target = self.geometry.calculateFrame(newProfile, slot.col, slot.row, uFrame, win)
          self.animation.animate(win, target, self.config.animation_duration)
        end
      end
    end
  end

  -- When switching to halves and center windows exist, show the interactive GUI picker
  if #centerWindows > 0 then
    self.halves_picker.show(centerWindows, function(win, direction, slot)
      local screen = win:screen() or hs.screen.mainScreen()
      local uFrame = screen:frame()
      local row = (slot and slot.row) or "full"
      local target = self.geometry.calculateFrame(newProfile, direction, row, uFrame, win)
      self.animation.animate(win, target, self.config.animation_duration)
    end)
  end
end

function Engine:toggleRefit(force_state)
  if force_state ~= nil then
    self.config.refit_on_profile_change = force_state
  else
    self.config.refit_on_profile_change = not self.config.refit_on_profile_change
  end
  local status = self.config.refit_on_profile_change and "ENABLED" or "DISABLED"
  self.hud.showNotice(string.format("DYNAMIC REFIT: %s", status), self.config.alert_style, 0.8)
end

function Engine:setAnimationDuration(sec)
  self.config.animation_duration = tonumber(sec) or 0.25
  hs.window.animationDuration = self.config.animation_duration
  self.hud.showNotice(string.format("ANIMATION: %.2fs", self.config.animation_duration), self.config.alert_style, 0.8)
end

function Engine:setHoldDelay(sec)
  self.config.hold_delay = tonumber(sec) or 0.05
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

function Engine:toggleShiftControl(force_state)
  if force_state ~= nil then
    self.config.shift_control_enabled = force_state
  else
    self.config.shift_control_enabled = not self.config.shift_control_enabled
  end
  local status = self.config.shift_control_enabled and "ENABLED" or "DISABLED"
  self.hud.showNotice(string.format("SHIFT CONTROL: %s", status), self.config.alert_style, 0.8)
end

-- Geometry calculation proxy
function Engine:calculateFrame(col, row, screen, win)
  return self.geometry.calculateFrame(self:getCurrentProfile(), col, row, screen, win)
end

-- Snap window via hotkey or programmatic call
function Engine:snap(col, row)
  if self.halves_picker and self.halves_picker.isOpen() then
    if col == "left" then
      self.halves_picker.chooseNext("left")
      return
    elseif col == "right" then
      self.halves_picker.chooseNext("right")
      return
    end
  end

  local win = hs.window.focusedWindow()
  if not win then return end
  local screen = win:screen():frame()
  local target = self:calculateFrame(col, row, screen, win)
  self.animation.animate(win, target, self.config.animation_duration)
end

-- Backward compatibility proxies for CLI and external scripts
function Engine:detectSnapZone(mousePos, fFrame, uFrame)
  local activeZone = self.mouseState and self.mouseState.activeZone
  return self.mouse.detectSnapZone(mousePos, fFrame, uFrame, self.config, self:getCurrentProfile(), activeZone)
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
  self.shift_control.start(self)
end

-- Stop Engine services and cleanup resources
function Engine:stop()
  if self.shift_control then
    self.shift_control.stop()
  end
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
  if self.halves_picker then
    self.halves_picker.close()
  end
  self.animation.stopAll()
  self.hotkeys.unbindAll()
end

return Engine
