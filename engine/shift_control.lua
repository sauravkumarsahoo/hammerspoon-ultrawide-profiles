-- =============================================================================
-- engine/shift_control.lua
-- Modifier Control Mode: Main Modifiers (Ctrl + Alt) + Shift
-- Immediate 0ms GUI display, Position Keys ([A], [S], [D]) cycling,
-- and instant release cleanup with zero debounces or delays.
-- =============================================================================

local shiftControl = {
  engine = nil,
  isActive = false,
  isCancelled = false,
  flagsTap = nil,
  keyTap = nil,
  webview = nil,
  usercontent = nil,
  targetedCol = "center",
  colIndices = { left = 1, center = 1, right = 1 },
  allColsData = { left = {}, center = {}, right = {} },
  iconCache = {}
}

-- Escape special HTML characters
local function escapeHTML(str)
  if not str then return "" end
  return str:gsub("&", "&amp;")
            :gsub("<", "&lt;")
            :gsub(">", "&gt;")
            :gsub('"', "&quot;")
            :gsub("'", "&#39;")
end

function shiftControl.isOpen()
  return shiftControl.webview ~= nil and shiftControl.isActive
end

-- Get cached or encoded app icon
local function getAppIconUrl(app)
  if not app then return nil end
  local bid = app:bundleID()
  if not bid then return nil end
  if not shiftControl.iconCache[bid] then
    local img = hs.image.imageFromAppBundle(bid)
    if img then
      shiftControl.iconCache[bid] = img:encodeAsURLString()
    end
  end
  return shiftControl.iconCache[bid]
end

-- Detect column for a given window or frame
local function detectColumn(win, engine, screen)
  if not win then return "center" end
  screen = screen or win:screen() or hs.screen.mainScreen()
  local uFrame = screen:frame()
  local profile = engine:getCurrentProfile()

  -- Check if window matches an exact snap slot
  local slot = engine.geometry.findMatchingSlot(win, profile, engine.config.profiles, uFrame)
  if slot and slot.col then
    return slot.col, slot
  end

  -- Fallback to window frame horizontal midpoint
  local wf = (type(win.frame) == "function" and win:frame()) or win
  local midX = wf.x + (wf.w / 2)
  local leftBoundary = uFrame.x + (uFrame.w * profile.left)
  local rightBoundary = uFrame.x + uFrame.w - (uFrame.w * profile.right)

  if midX < leftBoundary then
    return "left", slot
  elseif midX > rightBoundary then
    return "right", slot
  else
    if profile.id == "halves" then
      return (midX < (uFrame.x + uFrame.w / 2)) and "left" or "right", slot
    else
      return "center", slot
    end
  end
end

-- Fetch all manageable visible windows grouped by column in front-to-back z-order
local function getAllColumnWindows(engine, screen)
  screen = screen or hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
  local profile = engine:getCurrentProfile()

  local cols = { left = {}, center = {}, right = {} }
  local wins = hs.window.orderedWindows()

  for _, w in ipairs(wins) do
    if engine.mouse.isValidWindow(w) and w:screen() == screen and w:isVisible() and not w:isMinimized() then
      local col, slot = detectColumn(w, engine, screen)
      if cols[col] then
        local app = w:application()
        local appName = (app and app:name()) or "Application"
        local title = w:title() or appName
        local iconUrl = getAppIconUrl(app)

        local rowBadge = "Full"
        if slot and slot.row == "top" then
          rowBadge = "Top"
        elseif slot and slot.row == "bottom" then
          rowBadge = "Bottom"
        end

        table.insert(cols[col], {
          win = w,
          id = w:id(),
          title = title,
          appName = appName,
          iconUrl = iconUrl,
          rowBadge = rowBadge,
          slot = slot
        })
      end
    end
  end

  return cols
end

-- Render the HTML document for all 3 columns with prominent position keys
local function buildHTML(engine, screen, colsData, targetedCol, colIndices)
  local profile = engine:getCurrentProfile()
  local denom = profile.denominator or 4

  local ratios = {
    left = string.format("%d%%", math.floor((profile.left or 0.25) * 100 + 0.5)),
    center = (profile.id == "halves") and "50%" or string.format("%d%%", math.floor((profile.center or 0.50) * 100 + 0.5)),
    right = string.format("%d%%", math.floor((profile.right or 0.25) * 100 + 0.5))
  }

  local gridCols = "1fr 1.6fr 1fr"
  if profile.id == "thirds" then
    gridCols = "1fr 1fr 1fr"
  elseif profile.id == "fifths" then
    gridCols = "1fr 2.2fr 1fr"
  elseif profile.id == "sixths" then
    gridCols = "1fr 2.6fr 1fr"
  elseif profile.id == "halves" then
    gridCols = "1fr 1fr"
  end

  local function renderCards(colName)
    local items = colsData[colName] or {}
    local activeIdx = colIndices[colName] or 1
    if #items == 0 then
      local keyLetter = (colName == "left") and "A" or (colName == "center" and "S" or "D")
      return string.format([[
        <div class="empty-col">
          <div class="empty-glyph">⊞</div>
          <div class="empty-text">Empty Position</div>
          <div class="empty-hint">Press <span class="badge">%s</span> to place here</div>
        </div>
      ]], keyLetter)
    end

    local cards = {}
    for i, item in ipairs(items) do
      local isActive = (colName == targetedCol and i == activeIdx)
      local iconHTML = item.iconUrl and string.format('<img class="app-icon" src="%s" alt="Icon"/>', item.iconUrl)
                                     or '<div class="icon-fallback">⊞</div>'
      table.insert(cards, string.format([[
        <div class="win-card %s" id="card-%s-%d" onclick="selectColWin('%s', %d)">
          %s
          <div class="win-info">
            <div class="win-app-row">
              <span class="app-name">%s</span>
              <span class="row-badge">%s</span>
            </div>
            <div class="win-title" title="%s">%s</div>
          </div>
          <div class="index-num">%d</div>
        </div>
      ]], isActive and "active" or "", colName, i, colName, i, iconHTML, escapeHTML(item.appName), item.rowBadge, escapeHTML(item.title), escapeHTML(item.title), i))
    end
    return table.concat(cards, "\n")
  end

  local leftCards = renderCards("left")
  local centerCards = renderCards("center")
  local rightCards = renderCards("right")

  local html = string.format([[
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <style>
    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
      user-select: none;
      -webkit-user-select: none;
    }

    body {
      background: transparent;
      font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", "Inter", "Segoe UI", sans-serif;
      color: #cdd6f4;
      padding: 16px;
      overflow: hidden;
      display: flex;
      justify-content: center;
      align-items: center;
      height: 100vh;
    }

    .modal-shell {
      background: rgba(24, 24, 37, 0.96);
      border: 1px solid rgba(137, 180, 250, 0.35);
      border-radius: 20px;
      box-shadow: 0 24px 64px rgba(0, 0, 0, 0.70), 0 0 0 1px rgba(255, 255, 255, 0.08);
      backdrop-filter: blur(32px);
      -webkit-backdrop-filter: blur(32px);
      display: flex;
      flex-direction: column;
      width: 100%%;
      height: 100%%;
      overflow: hidden;
    }

    /* Header */
    .header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 12px 20px;
      border-bottom: 1px solid rgba(255, 255, 255, 0.08);
      background: rgba(17, 17, 27, 0.50);
      flex-shrink: 0;
    }

    .header-left {
      display: flex;
      align-items: center;
      gap: 12px;
    }

    .mode-badge {
      display: inline-flex;
      align-items: center;
      gap: 5px;
      background: linear-gradient(135deg, #89b4fa, #b4befe);
      color: #11111b;
      font-weight: 800;
      font-size: 11px;
      padding: 4px 10px;
      border-radius: 8px;
      letter-spacing: 0.5px;
      text-transform: uppercase;
    }

    .active-col-pill {
      background: rgba(137, 180, 250, 0.16);
      border: 1px solid rgba(137, 180, 250, 0.40);
      color: #89b4fa;
      font-weight: 800;
      font-size: 11px;
      padding: 4px 10px;
      border-radius: 8px;
      letter-spacing: 0.4px;
      text-transform: uppercase;
    }

    .header-right {
      display: flex;
      align-items: center;
      gap: 10px;
    }

    .esc-hint {
      display: inline-flex;
      align-items: center;
      gap: 5px;
      font-size: 11px;
      color: #a6adc8;
    }

    .key-badge {
      background: rgba(255, 255, 255, 0.08);
      border: 1px solid rgba(255, 255, 255, 0.16);
      border-radius: 5px;
      padding: 2px 7px;
      font-family: ui-monospace, Menlo, monospace;
      font-size: 11px;
      font-weight: 700;
      color: #cdd6f4;
    }

    /* 3-Column Grid */
    .columns-grid {
      flex: 1;
      display: grid;
      grid-template-columns: %s;
      gap: 12px;
      padding: 12px 16px;
      overflow: hidden;
    }

    .col-box {
      background: rgba(30, 30, 46, 0.55);
      border: 1px solid rgba(255, 255, 255, 0.08);
      border-radius: 14px;
      display: flex;
      flex-direction: column;
      overflow: hidden;
      transition: border-color 0.12s ease, background 0.12s ease;
    }

    .col-box.active-col {
      border: 1px solid #89b4fa;
      background: rgba(137, 180, 250, 0.08);
      box-shadow: 0 0 20px rgba(137, 180, 250, 0.20);
    }

    .col-header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 8px 12px;
      border-bottom: 1px solid rgba(255, 255, 255, 0.06);
      background: rgba(17, 17, 27, 0.40);
    }

    .col-header-left {
      display: flex;
      align-items: center;
      gap: 8px;
    }

    .pos-key {
      background: #89b4fa;
      color: #11111b;
      font-family: ui-monospace, Menlo, monospace;
      font-size: 11.5px;
      font-weight: 800;
      padding: 2px 7px;
      border-radius: 6px;
      box-shadow: 0 2px 6px rgba(137, 180, 250, 0.35);
    }

    .col-box:not(.active-col) .pos-key {
      background: rgba(255, 255, 255, 0.12);
      color: #cdd6f4;
      box-shadow: none;
    }

    .col-title {
      font-size: 12px;
      font-weight: 800;
      letter-spacing: 0.4px;
      color: #ffffff;
    }

    .col-ratio {
      font-size: 11px;
      font-weight: 600;
      color: #a6adc8;
      font-family: ui-monospace, Menlo, monospace;
    }

    .cards-list {
      flex: 1;
      overflow-y: auto;
      padding: 8px;
      display: flex;
      flex-direction: column;
      gap: 6px;
    }

    .cards-list::-webkit-scrollbar {
      width: 4px;
    }
    .cards-list::-webkit-scrollbar-thumb {
      background: rgba(255, 255, 255, 0.18);
      border-radius: 3px;
    }

    /* Window Card */
    .win-card {
      display: flex;
      align-items: center;
      gap: 10px;
      padding: 7px 10px;
      background: rgba(24, 24, 37, 0.60);
      border: 1px solid rgba(255, 255, 255, 0.06);
      border-radius: 10px;
      cursor: pointer;
      transition: background 0.10s ease, border-color 0.10s ease;
    }

    .win-card:hover {
      background: rgba(49, 50, 68, 0.70);
      border-color: rgba(137, 180, 250, 0.30);
    }

    .win-card.active {
      background: rgba(137, 180, 250, 0.22);
      border: 1px solid #89b4fa;
      box-shadow: 0 0 12px rgba(137, 180, 250, 0.35);
    }

    .app-icon {
      width: 26px;
      height: 26px;
      object-fit: contain;
      flex-shrink: 0;
      filter: drop-shadow(0 2px 4px rgba(0, 0, 0, 0.35));
    }

    .icon-fallback {
      width: 26px;
      height: 26px;
      border-radius: 6px;
      background: rgba(255, 255, 255, 0.08);
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 14px;
      color: #89b4fa;
      flex-shrink: 0;
    }

    .win-info {
      flex: 1;
      min-width: 0;
      display: flex;
      flex-direction: column;
      gap: 2px;
    }

    .win-app-row {
      display: flex;
      align-items: center;
      justify-content: space-between;
    }

    .app-name {
      font-size: 12px;
      font-weight: 700;
      color: #ffffff;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }

    .row-badge {
      font-size: 9px;
      font-weight: 600;
      color: #89b4fa;
      background: rgba(137, 180, 250, 0.12);
      border: 1px solid rgba(137, 180, 250, 0.25);
      border-radius: 4px;
      padding: 1px 4px;
    }

    .win-title {
      font-size: 11px;
      color: #a6adc8;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }

    .index-num {
      width: 18px;
      height: 18px;
      border-radius: 50%%;
      background: rgba(255, 255, 255, 0.08);
      color: #a6adc8;
      font-size: 10px;
      font-weight: 700;
      display: flex;
      align-items: center;
      justify-content: center;
      flex-shrink: 0;
    }

    .win-card.active .index-num {
      background: #89b4fa;
      color: #11111b;
    }

    /* Empty Column State */
    .empty-col {
      flex: 1;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      gap: 6px;
      padding: 20px 10px;
      color: #6c7086;
      text-align: center;
    }

    .empty-glyph {
      font-size: 24px;
      opacity: 0.5;
    }

    .empty-text {
      font-size: 12px;
      font-weight: 600;
      color: #a6adc8;
    }

    .empty-hint {
      font-size: 11px;
    }

    .empty-hint .badge {
      background: rgba(137, 180, 250, 0.18);
      color: #89b4fa;
      font-weight: 700;
      padding: 1px 5px;
      border-radius: 4px;
    }

    /* Footer */
    .footer {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 10px 20px;
      border-top: 1px solid rgba(255, 255, 255, 0.08);
      background: rgba(17, 17, 27, 0.40);
      font-size: 11.5px;
      color: #bac2de;
      flex-shrink: 0;
    }

    .action-chips {
      display: flex;
      align-items: center;
      gap: 8px;
    }
  </style>
</head>
<body>
  <div class="modal-shell">
    <div class="header">
      <div class="header-left">
        <div class="mode-badge">^⌥⇧ Window Control</div>
        <div class="active-col-pill" id="activePosLabel">%s Column</div>
      </div>
      <div class="header-right">
        <div class="esc-hint">
          <span class="key-badge">Esc</span>
          <span>Cancel</span>
        </div>
      </div>
    </div>

    <div class="columns-grid">
      <!-- Left Column -->
      <div class="col-box %s" id="col-left">
        <div class="col-header">
          <div class="col-header-left">
            <span class="pos-key">A</span>
            <span class="col-title">LEFT</span>
          </div>
          <span class="col-ratio">%s</span>
        </div>
        <div class="cards-list">
          %s
        </div>
      </div>

      <!-- Center Stage Column -->
      <div class="col-box %s" id="col-center">
        <div class="col-header">
          <div class="col-header-left">
            <span class="pos-key">S</span>
            <span class="col-title">CENTER</span>
          </div>
          <span class="col-ratio">%s</span>
        </div>
        <div class="cards-list">
          %s
        </div>
      </div>

      <!-- Right Column -->
      <div class="col-box %s" id="col-right">
        <div class="col-header">
          <div class="col-header-left">
            <span class="pos-key">D</span>
            <span class="col-title">RIGHT</span>
          </div>
          <span class="col-ratio">%s</span>
        </div>
        <div class="cards-list">
          %s
        </div>
      </div>
    </div>

    <div class="footer">
      <div class="action-chips">
        <span>Cycle Column: Hold <span class="key-badge">A</span> <span class="key-badge">S</span> <span class="key-badge">D</span></span>
        <span style="color: #6c7086;">&bull;</span>
        <span>Height: <span class="key-badge">W</span> Top <span class="key-badge">X</span> Bottom <span class="key-badge">F</span> Full</span>
      </div>
      <div>Release keys to commit</div>
    </div>
  </div>

  <script>
    function setActive(col, idx) {
      document.querySelectorAll('.col-box').forEach(b => b.classList.remove('active-col'));
      const activeBox = document.getElementById('col-' + col);
      if (activeBox) {
        activeBox.classList.add('active-col');
        const cards = activeBox.querySelectorAll('.win-card');
        cards.forEach((c, i) => {
          if (i === idx) {
            c.classList.add('active');
            c.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
          } else {
            c.classList.remove('active');
          }
        });
      }
      const label = document.getElementById('activePosLabel');
      if (label) label.textContent = col.toUpperCase() + ' COLUMN';
    }

    function selectColWin(col, idx) {
      window.webkit.messageHandlers.shiftControl.postMessage({
        action: 'selectColWin',
        col: col,
        index: idx
      });
    }
  </script>
</body>
</html>
  ]], gridCols,
      targetedCol:upper(),
      (targetedCol == "left") and "active-col" or "", ratios.left, leftCards,
      (targetedCol == "center") and "active-col" or "", ratios.center, centerCards,
      (targetedCol == "right") and "active-col" or "", ratios.right, rightCards)

  return html
end

-- Refresh data and re-render GUI immediately
function shiftControl.refreshDataAndUI()
  if not shiftControl.engine or not shiftControl.isActive then return end
  local screen = hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
  shiftControl.allColsData = getAllColumnWindows(shiftControl.engine, screen)

  local html = buildHTML(
    shiftControl.engine,
    screen,
    shiftControl.allColsData,
    shiftControl.targetedCol,
    shiftControl.colIndices
  )

  if shiftControl.webview then
    shiftControl.webview:html(html)
  end
end

-- Cycle windows in targeted column immediately
local function cycleColumn(targetCol)
  local engine = shiftControl.engine
  local screen = hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
  local colsData = shiftControl.allColsData or getAllColumnWindows(engine, screen)
  local wins = colsData[targetCol] or {}

  if #wins == 0 then
    -- No windows in this column: snap the currently focused window here!
    local fw = hs.window.focusedWindow()
    if fw then
      engine:snap(targetCol, "full")
      shiftControl.targetedCol = targetCol
      shiftControl.colIndices[targetCol] = 1
      shiftControl.refreshDataAndUI()
    end
    return
  end

  -- Windows exist: advance cycling in this column
  if shiftControl.targetedCol ~= targetCol then
    shiftControl.targetedCol = targetCol
    shiftControl.colIndices[targetCol] = 1
  else
    local curIdx = shiftControl.colIndices[targetCol] or 1
    shiftControl.colIndices[targetCol] = (curIdx % #wins) + 1
  end

  local activeIdx = shiftControl.colIndices[targetCol]
  local targetItem = wins[activeIdx]
  if targetItem and targetItem.win and targetItem.win:isVisible() then
    targetItem.win:focus()
  end

  -- Fast DOM update
  if shiftControl.webview then
    shiftControl.webview:evaluateJavaScript(
      string.format("setActive('%s', %d)", targetCol, activeIdx - 1)
    )
  end
end

-- Enter Modifier Control Mode
function shiftControl.enter()
  if not shiftControl.engine or not shiftControl.engine.config.shift_control_enabled then
    return
  end

  local engine = shiftControl.engine
  local fw = hs.window.focusedWindow()
  local screen = (fw and fw:screen()) or hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
  local curCol = detectColumn(fw, engine, screen)

  shiftControl.isActive = true
  shiftControl.targetedCol = curCol

  -- Fast scan of all windows across 3 columns
  shiftControl.allColsData = getAllColumnWindows(engine, screen)

  -- Identify initial index in this column
  local initialIdx = 1
  if fw and shiftControl.allColsData[curCol] then
    for i, item in ipairs(shiftControl.allColsData[curCol]) do
      if item.id == fw:id() then
        initialIdx = i
        break
      end
    end
  end
  shiftControl.colIndices[curCol] = initialIdx

  local sFrame = screen:frame()
  local width = 800
  local height = 370
  local x = math.floor(sFrame.x + (sFrame.w - width) / 2)
  local y = math.floor(sFrame.y + (sFrame.h - height) / 2)

  local html = buildHTML(engine, screen, shiftControl.allColsData, curCol, shiftControl.colIndices)

  if not shiftControl.webview then
    local uc = hs.webview.usercontent.new("shiftControl")
    shiftControl.usercontent = uc

    uc:setCallback(function(msg)
      local body = msg.body
      if not body then return end
      if body.action == "selectColWin" and body.col and body.index then
        local wins = shiftControl.allColsData[body.col] or {}
        local item = wins[body.index]
        if item and item.win and item.win:isVisible() then
          shiftControl.targetedCol = body.col
          shiftControl.colIndices[body.col] = body.index
          item.win:focus()
          if shiftControl.webview then
            shiftControl.webview:evaluateJavaScript(string.format("setActive('%s', %d)", body.col, body.index - 1))
          end
        end
      end
    end)

    local wv = hs.webview.new({x = x, y = y, w = width, h = height}, {developerExtras = false}, uc)
    shiftControl.webview = wv
    wv:windowStyle("borderless")
    wv:transparent(true)
    wv:shadow(false)
    wv:level(hs.canvas.windowLevels.modalPanel)
  else
    shiftControl.webview:frame({x = x, y = y, w = width, h = height})
  end

  shiftControl.webview:html(html)
  shiftControl.webview:show()
end

-- Exit Modifier Control Mode immediately (0ms, no delays or debounces)
function shiftControl.exit()
  shiftControl.isActive = false
  if shiftControl.webview then
    shiftControl.webview:hide()
  end
end

-- Handle intercepted keydowns while mode is active
function shiftControl.handleKey(code)
  local engine = shiftControl.engine

  -- Esc: Cancel
  if code == 53 then
    shiftControl.isCancelled = true
    shiftControl.exit()
    return true

  -- [A] or [Left Arrow] or [1]: Left Column
  elseif code == 0 or code == 123 or code == 18 then
    cycleColumn("left")
    return true

  -- [S]: Center Stage Column
  elseif code == 1 then
    cycleColumn("center")
    return true

  -- [D] or [Right Arrow] or [19] (2): Right Column
  elseif code == 2 or code == 124 or code == 19 then
    cycleColumn("right")
    return true

  -- [Down Arrow]: Next window in current column
  elseif code == 125 then
    local targetCol = shiftControl.targetedCol or "center"
    local wins = shiftControl.allColsData[targetCol] or {}
    if #wins > 1 then
      local curIdx = shiftControl.colIndices[targetCol] or 1
      shiftControl.colIndices[targetCol] = (curIdx % #wins) + 1
      local targetItem = wins[shiftControl.colIndices[targetCol]]
      if targetItem and targetItem.win and targetItem.win:isVisible() then
        targetItem.win:focus()
      end
      if shiftControl.webview then
        shiftControl.webview:evaluateJavaScript(string.format("setActive('%s', %d)", targetCol, shiftControl.colIndices[targetCol] - 1))
      end
    else
      -- 1 window: cycle height downwards
      local fw = hs.window.focusedWindow()
      local curSlot = fw and engine.geometry.findMatchingSlot(fw, engine:getCurrentProfile(), engine.config.profiles, hs.screen.mainScreen():frame())
      local curRow = (curSlot and curSlot.row) or "full"
      local nextRow = (curRow == "bottom") and "top" or ((curRow == "top") and "full" or "bottom")
      engine:snap(targetCol, nextRow)
      shiftControl.refreshDataAndUI()
    end
    return true

  -- [Up Arrow]: Previous window in current column
  elseif code == 126 then
    local targetCol = shiftControl.targetedCol or "center"
    local wins = shiftControl.allColsData[targetCol] or {}
    if #wins > 1 then
      local curIdx = shiftControl.colIndices[targetCol] or 1
      curIdx = curIdx - 1
      if curIdx < 1 then curIdx = #wins end
      shiftControl.colIndices[targetCol] = curIdx
      local targetItem = wins[curIdx]
      if targetItem and targetItem.win and targetItem.win:isVisible() then
        targetItem.win:focus()
      end
      if shiftControl.webview then
        shiftControl.webview:evaluateJavaScript(string.format("setActive('%s', %d)", targetCol, curIdx - 1))
      end
    else
      -- 1 window: cycle height upwards
      local fw = hs.window.focusedWindow()
      local curSlot = fw and engine.geometry.findMatchingSlot(fw, engine:getCurrentProfile(), engine.config.profiles, hs.screen.mainScreen():frame())
      local curRow = (curSlot and curSlot.row) or "full"
      local nextRow = (curRow == "top") and "bottom" or ((curRow == "bottom") and "full" or "top")
      engine:snap(targetCol, nextRow)
      shiftControl.refreshDataAndUI()
    end
    return true

  -- [W]: Top Half of current column
  elseif code == 13 then
    engine:snap(shiftControl.targetedCol, "top")
    shiftControl.refreshDataAndUI()
    return true

  -- [X]: Bottom Half of current column
  elseif code == 7 then
    engine:snap(shiftControl.targetedCol, "bottom")
    shiftControl.refreshDataAndUI()
    return true

  -- [F]: Full Height of current column
  elseif code == 3 then
    engine:snap(shiftControl.targetedCol, "full")
    shiftControl.refreshDataAndUI()
    return true

  -- Corners: Q (Top-Left), Z (Bottom-Left), E (Top-Right), C (Bottom-Right)
  elseif code == 12 then
    engine:snap("left", "top")
    shiftControl.refreshDataAndUI()
    return true
  elseif code == 6 then
    engine:snap("left", "bottom")
    shiftControl.refreshDataAndUI()
    return true
  elseif code == 14 then
    engine:snap("right", "top")
    shiftControl.refreshDataAndUI()
    return true
  elseif code == 8 then
    engine:snap("right", "bottom")
    shiftControl.refreshDataAndUI()
    return true

  -- Profiles: ` (Cycle), 3, 4, 5, 6
  elseif code == 50 then
    engine:cycleProfile()
    shiftControl.refreshDataAndUI()
    return true
  elseif code == 20 then
    engine:toggleProfile(3)
    shiftControl.refreshDataAndUI()
    return true
  elseif code == 21 then
    engine:toggleProfile(4)
    shiftControl.refreshDataAndUI()
    return true
  elseif code == 23 then
    engine:toggleProfile(5)
    shiftControl.refreshDataAndUI()
    return true
  elseif code == 22 then
    engine:toggleProfile(6)
    shiftControl.refreshDataAndUI()
    return true
  end

  return false
end

-- Initialize persistent modifier and key event taps
function shiftControl.start(engine)
  shiftControl.stop()
  shiftControl.engine = engine

  -- 1. FlagsChanged EventTap: monitors Ctrl + Alt + Shift
  shiftControl.flagsTap = hs.eventtap.new({hs.eventtap.event.types.flagsChanged}, function(event)
    local flags = event:getFlags()
    -- Check if main modifiers (Ctrl + Alt) AND Shift are held down together
    local isComboDown = flags.ctrl and flags.alt and flags.shift and not flags.cmd

    if isComboDown then
      if not shiftControl.isActive and not shiftControl.isCancelled then
        shiftControl.enter()
      end
    else
      if shiftControl.isActive then
        shiftControl.exit()
      end
      shiftControl.isCancelled = false
    end

    return false
  end)

  -- 2. KeyDown EventTap: persistent listener, active only while mode is active
  shiftControl.keyTap = hs.eventtap.new({hs.eventtap.event.types.keyDown}, function(event)
    if not shiftControl.isActive then
      return false
    end

    local flags = event:getFlags()
    local code = event:getKeyCode()

    -- Do not intercept system commands (Cmd+Tab, Cmd+Space)
    if flags.cmd and code ~= 53 then
      return false
    end

    -- Ensure main modifiers and shift are still held (except Esc)
    if not (flags.ctrl and flags.alt and flags.shift) and code ~= 53 then
      return false
    end

    return shiftControl.handleKey(code)
  end)

  shiftControl.flagsTap:start()
  shiftControl.keyTap:start()
end

-- Clean up and stop persistent event taps
function shiftControl.stop()
  shiftControl.exit()

  if shiftControl.flagsTap then
    shiftControl.flagsTap:stop()
    shiftControl.flagsTap = nil
  end

  if shiftControl.keyTap then
    shiftControl.keyTap:stop()
    shiftControl.keyTap = nil
  end

  if shiftControl.webview then
    shiftControl.webview:delete()
    shiftControl.webview = nil
  end

  if shiftControl.usercontent then
    shiftControl.usercontent = nil
  end

  shiftControl.isCancelled = false
end

return shiftControl
