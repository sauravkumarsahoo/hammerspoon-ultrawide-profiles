-- =============================================================================
-- Ultrawide Window Engine for 3440x1440
-- Profiles (Denominators 2 to 6):
--   2: [      1/2       ][      1/2       ]
--   3: [   1/3    ][   1/3    ][   1/3    ]
--   4: [  1/4  ][      1/2       ][  1/4  ]
--   5: [ 1/5 ][        3/5         ][ 1/5 ]
--   6: [ 1/6 ][        2/3         ][ 1/6 ]
-- =============================================================================

require("hs.ipc")
require("hs.canvas")

-- Clean up any existing instance before reloading
if _G.WindowEngine then
  pcall(function() _G.WindowEngine:stop() end)
  _G.WindowEngine = nil
end

local Engine = require("engine")
Engine:start()

-- Export to global environment for CLI integration and GC retention
_G.WindowEngine = Engine

-- Notify readiness on load
hs.alert.show(
  string.format("Window Engine Loaded\n%s", Engine:getCurrentProfile().label),
  Engine.config.alert_style,
  hs.screen.mainScreen(),
  1.0
)

return Engine
