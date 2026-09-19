-- =============================================================================
-- engine/hotkeys.lua
-- Keyboard shortcuts cluster (Ctrl + Alt)
-- =============================================================================

local hotkeys = {
  bindings = {}
}

function hotkeys.bindAll(engine)
  hotkeys.unbindAll()

  local mod = {"ctrl", "alt"}

  -- Profile Shortcuts by Denominator (2 to 6) & Cycle
  table.insert(hotkeys.bindings, hs.hotkey.bind(mod, "`", function() engine:cycleProfile() end))
  table.insert(hotkeys.bindings, hs.hotkey.bind(mod, "2", function() engine:toggleProfile(2) end))
  table.insert(hotkeys.bindings, hs.hotkey.bind(mod, "3", function() engine:toggleProfile(3) end))
  table.insert(hotkeys.bindings, hs.hotkey.bind(mod, "4", function() engine:toggleProfile(4) end))
  table.insert(hotkeys.bindings, hs.hotkey.bind(mod, "5", function() engine:toggleProfile(5) end))
  table.insert(hotkeys.bindings, hs.hotkey.bind(mod, "6", function() engine:toggleProfile(6) end))

  -- Column Snapping (Row 2: A, S, D)
  table.insert(hotkeys.bindings, hs.hotkey.bind(mod, "a", function() engine:snap("left", "full") end))
  table.insert(hotkeys.bindings, hs.hotkey.bind(mod, "s", function() engine:snap("center", "full") end))
  table.insert(hotkeys.bindings, hs.hotkey.bind(mod, "d", function() engine:snap("right", "full") end))

  -- Corner Snapping (Rows 1 & 3: Q, Z, E, C)
  table.insert(hotkeys.bindings, hs.hotkey.bind(mod, "q", function() engine:snap("left", "top") end))
  table.insert(hotkeys.bindings, hs.hotkey.bind(mod, "z", function() engine:snap("left", "bottom") end))
  table.insert(hotkeys.bindings, hs.hotkey.bind(mod, "e", function() engine:snap("right", "top") end))
  table.insert(hotkeys.bindings, hs.hotkey.bind(mod, "c", function() engine:snap("right", "bottom") end))

  -- Arrow & Number shortcuts (also route center windows in Halves picker)
  table.insert(hotkeys.bindings, hs.hotkey.bind(mod, "left", function() engine:snap("left", "full") end))
  table.insert(hotkeys.bindings, hs.hotkey.bind(mod, "right", function() engine:snap("right", "full") end))
  table.insert(hotkeys.bindings, hs.hotkey.bind(mod, "1", function()
    if engine.halves_picker and engine.halves_picker.isOpen() then
      engine.halves_picker.chooseNext("left")
    else
      engine:snap("left", "full")
    end
  end))
  table.insert(hotkeys.bindings, hs.hotkey.bind(mod, "escape", function()
    if engine.halves_picker and engine.halves_picker.isOpen() then
      engine.halves_picker.dismiss()
    end
  end))
end

function hotkeys.unbindAll()
  for _, hk in ipairs(hotkeys.bindings) do
    hk:delete()
  end
  hotkeys.bindings = {}
end

return hotkeys
