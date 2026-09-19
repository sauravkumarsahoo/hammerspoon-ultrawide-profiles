-- =============================================================================
-- engine/halves_picker.lua
-- Interactive modal GUI for placing center windows into Left or Right half
-- when switching to Profile 2 (Halves: 1/2 1/2)
-- =============================================================================

local halvesPicker = {
  webview = nil,
  usercontent = nil,
  eventTap = nil
}

-- Escape special HTML characters to prevent XSS / formatting breaks
local function escapeHTML(str)
  if not str then return "" end
  return str:gsub("&", "&amp;")
            :gsub("<", "&lt;")
            :gsub(">", "&gt;")
            :gsub('"', "&quot;")
            :gsub("'", "&#39;")
end

function halvesPicker.isOpen()
  return halvesPicker.webview ~= nil
end

function halvesPicker.chooseNext(direction)
  if halvesPicker.webview then
    halvesPicker.webview:evaluateJavaScript(string.format("chooseNext('%s')", direction))
  end
end

function halvesPicker.dismiss()
  if halvesPicker.webview then
    halvesPicker.webview:evaluateJavaScript("dismissModal()")
  else
    halvesPicker.close()
  end
end

function halvesPicker.close()
  if halvesPicker.eventTap then
    halvesPicker.eventTap:stop()
    halvesPicker.eventTap = nil
  end
  if halvesPicker.webview then
    halvesPicker.webview:delete()
    halvesPicker.webview = nil
  end
  if halvesPicker.usercontent then
    halvesPicker.usercontent = nil
  end
end

function halvesPicker.show(centerWindows, onSelect, onDone)
  halvesPicker.close()

  if not centerWindows or #centerWindows == 0 then
    if onDone then onDone() end
    return
  end

  local screen = hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
  local sFrame = screen:frame()

  local width = 680
  local cardHeight = 124
  local headerFooterHeight = 160
  local height = math.min(620, headerFooterHeight + (#centerWindows * cardHeight))

  local x = math.floor(sFrame.x + (sFrame.w - width) / 2)
  local y = math.floor(sFrame.y + (sFrame.h - height) / 2)

  -- Build usercontent handler
  local uc = hs.webview.usercontent.new("halvesPicker")
  halvesPicker.usercontent = uc

  local winMap = {}
  local entryMap = {}
  local itemsHTML = {}

  for i, entry in ipairs(centerWindows) do
    local win = entry.win or entry
    local id = win:id()
    winMap[id] = win
    winMap[tostring(id)] = win
    entryMap[id] = entry
    entryMap[tostring(id)] = entry

    local app = win:application()
    local appName = (app and app:name()) or "Application"
    local title = win:title() or ""
    if title == "" then title = appName end

    -- Fetch high-res application icon
    local iconUrl = nil
    if app and app:bundleID() then
      local icon = hs.image.imageFromAppBundle(app:bundleID())
      if icon then
        iconUrl = icon:encodeAsURLString()
      end
    end

    -- Fetch live window snapshot if available
    local snapshotUrl = nil
    local ok, snap = pcall(function() return win:snapshot() end)
    if ok and snap then
      snapshotUrl = snap:encodeAsURLString()
    end

    local previewImgHTML = ""
    if snapshotUrl then
      previewImgHTML = string.format([[
        <div class="thumb-container">
          <div class="mac-titlebar">
            <span class="dot dot-close"></span>
            <span class="dot dot-min"></span>
            <span class="dot dot-max"></span>
          </div>
          <div class="preview-body">
            <img class="window-thumb" src="%s" alt="Preview" />
            %s
          </div>
        </div>
      ]], snapshotUrl, iconUrl and string.format('<img class="badge-icon" src="%s" alt="App" />', iconUrl) or "")
    elseif iconUrl then
      previewImgHTML = string.format([[
        <div class="thumb-container">
          <div class="mac-titlebar">
            <span class="dot dot-close"></span>
            <span class="dot dot-min"></span>
            <span class="dot dot-max"></span>
          </div>
          <div class="preview-body fallback-preview">
            <img class="fallback-app-icon" src="%s" alt="%s" />
          </div>
        </div>
      ]], iconUrl, escapeHTML(appName))
    else
      previewImgHTML = [[
        <div class="thumb-container">
          <div class="mac-titlebar">
            <span class="dot dot-close"></span>
            <span class="dot dot-min"></span>
            <span class="dot dot-max"></span>
          </div>
          <div class="preview-body fallback-preview">
            <span class="fallback-glyph">⊞</span>
          </div>
        </div>
      ]]
    end

    local slotText = "Center Stage"
    if entry.slot and entry.slot.row then
      if entry.slot.row == "top" then
        slotText = "Center Stage • Top Half"
      elseif entry.slot.row == "bottom" then
        slotText = "Center Stage • Bottom Half"
      else
        slotText = "Center Stage • Full Height"
      end
    end

    table.insert(itemsHTML, string.format([[
      <div class="window-card" id="card-%s" data-win-id="%s">
        %s
        <div class="window-info">
          <div class="app-name-row">
            <span class="app-name">%s</span>
            <span class="slot-pill">%s</span>
          </div>
          <div class="window-title" title="%s">%s</div>
        </div>
        <div class="action-buttons">
          <button class="btn btn-left" onclick="chooseWindow('%s', 'left')" title="Move to Left Half (1/2)">
            <svg class="arrow-svg" viewBox="0 0 24 24">
              <path d="M19 12H5M12 19l-7-7 7-7" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/>
            </svg>
            <span>Left</span>
          </button>
          <button class="btn btn-right" onclick="chooseWindow('%s', 'right')" title="Move to Right Half (1/2)">
            <span>Right</span>
            <svg class="arrow-svg" viewBox="0 0 24 24">
              <path d="M5 12h14M12 5l7 7-7 7" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/>
            </svg>
          </button>
        </div>
      </div>
    ]], id, id, previewImgHTML, escapeHTML(appName), slotText, escapeHTML(title), escapeHTML(title), id, id))
  end

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
      padding: 18px;
      overflow: hidden;
      display: flex;
      justify-content: center;
      align-items: center;
      height: 100vh;
    }

    .modal-shell {
      background: rgba(24, 24, 37, 0.96);
      backdrop-filter: blur(32px);
      -webkit-backdrop-filter: blur(32px);
      border: 1px solid rgba(137, 180, 250, 0.30);
      border-radius: 22px;
      width: 100%%;
      height: 100%%;
      box-shadow: 0 24px 64px rgba(0, 0, 0, 0.65), 0 0 0 1px rgba(255, 255, 255, 0.08);
      display: flex;
      flex-direction: column;
      animation: modalSlideUp 0.20s cubic-bezier(0.16, 1, 0.3, 1);
      overflow: hidden;
    }

    @keyframes modalSlideUp {
      from {
        opacity: 0;
        transform: translateY(14px) scale(0.98);
      }
      to {
        opacity: 1;
        transform: translateY(0) scale(1);
      }
    }

    /* Header */
    .header {
      padding: 16px 22px 14px;
      border-bottom: 1px solid rgba(255, 255, 255, 0.08);
      display: flex;
      align-items: center;
      justify-content: space-between;
      background: rgba(17, 17, 27, 0.40);
    }

    .header-left {
      display: flex;
      align-items: center;
      gap: 12px;
    }

    .header-title-block {
      display: flex;
      flex-direction: column;
    }

    .header-title {
      font-size: 16px;
      font-weight: 800;
      color: #ffffff;
      letter-spacing: -0.2px;
    }

    .header-subtitle {
      font-size: 12px;
      color: #a6adc8;
      margin-top: 2px;
      letter-spacing: 0.1px;
    }

    .profile-pill {
      background: rgba(137, 180, 250, 0.16);
      border: 1px solid rgba(137, 180, 250, 0.40);
      color: #89b4fa;
      font-size: 11px;
      font-weight: 800;
      padding: 4px 10px;
      border-radius: 9px;
      letter-spacing: 0.4px;
    }

    .close-btn {
      background: rgba(255, 255, 255, 0.06);
      border: 1px solid rgba(255, 255, 255, 0.12);
      color: #a6adc8;
      width: 28px;
      height: 28px;
      border-radius: 8px;
      font-size: 14px;
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
      transition: all 0.15s ease;
    }

    .close-btn:hover {
      background: rgba(255, 255, 255, 0.14);
      color: #ffffff;
      border-color: rgba(255, 255, 255, 0.25);
    }

    /* Windows List */
    .windows-container {
      flex: 1;
      overflow-y: auto;
      padding: 14px 18px;
      display: flex;
      flex-direction: column;
      gap: 12px;
    }

    .windows-container::-webkit-scrollbar {
      width: 6px;
    }
    .windows-container::-webkit-scrollbar-thumb {
      background: rgba(255, 255, 255, 0.18);
      border-radius: 3px;
    }

    /* Window Card */
    .window-card {
      background: rgba(30, 30, 46, 0.65);
      border: 1px solid rgba(255, 255, 255, 0.09);
      border-radius: 16px;
      padding: 12px 16px;
      display: flex;
      align-items: center;
      gap: 16px;
      transition: all 0.20s cubic-bezier(0.16, 1, 0.3, 1);
    }

    .window-card:hover {
      background: rgba(49, 50, 68, 0.70);
      border-color: rgba(137, 180, 250, 0.35);
      transform: translateY(-1px);
      box-shadow: 0 8px 20px rgba(0, 0, 0, 0.30);
    }

    .window-card.slide-left {
      transform: translateX(-40px);
      opacity: 0;
    }

    .window-card.slide-right {
      transform: translateX(40px);
      opacity: 0;
    }

    /* Large Window Preview Container */
    .thumb-container {
      position: relative;
      width: 140px;
      height: 92px;
      border-radius: 10px;
      overflow: hidden;
      border: 1px solid rgba(255, 255, 255, 0.15);
      background: #11111b;
      flex-shrink: 0;
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.40);
      display: flex;
      flex-direction: column;
    }

    .mac-titlebar {
      height: 14px;
      background: rgba(255, 255, 255, 0.06);
      border-bottom: 1px solid rgba(255, 255, 255, 0.08);
      display: flex;
      align-items: center;
      gap: 4px;
      padding-left: 6px;
      flex-shrink: 0;
    }

    .dot {
      width: 6px;
      height: 6px;
      border-radius: 50%%;
    }
    .dot-close { background: #ff5f56; }
    .dot-min   { background: #ffbd2e; }
    .dot-max   { background: #27c93f; }

    .preview-body {
      flex: 1;
      position: relative;
      overflow: hidden;
      display: flex;
      align-items: center;
      justify-content: center;
      background: #181825;
    }

    .window-thumb {
      width: 100%%;
      height: 100%%;
      object-fit: cover;
      display: block;
    }

    .badge-icon {
      position: absolute;
      bottom: 4px;
      right: 4px;
      width: 22px;
      height: 22px;
      border-radius: 5px;
      background: rgba(17, 17, 27, 0.90);
      border: 1px solid rgba(255, 255, 255, 0.20);
      padding: 2px;
      box-shadow: 0 2px 6px rgba(0, 0, 0, 0.5);
    }

    .fallback-preview {
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      gap: 4px;
      width: 100%%;
      height: 100%%;
      background: radial-gradient(circle, rgba(137, 180, 250, 0.12) 0%%, rgba(24, 24, 37, 0.8) 100%%);
    }

    .fallback-app-icon {
      width: 40px;
      height: 40px;
      object-fit: contain;
      filter: drop-shadow(0 2px 6px rgba(0, 0, 0, 0.45));
    }

    .fallback-glyph {
      font-size: 28px;
      color: #89b4fa;
      opacity: 0.6;
    }

    /* Window Info */
    .window-info {
      flex: 1;
      min-width: 0;
      display: flex;
      flex-direction: column;
      gap: 4px;
    }

    .app-name-row {
      display: flex;
      align-items: center;
      gap: 8px;
    }

    .app-name {
      font-size: 15px;
      font-weight: 700;
      color: #ffffff;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }

    .slot-pill {
      font-size: 10.5px;
      font-weight: 600;
      color: #89b4fa;
      background: rgba(137, 180, 250, 0.12);
      border: 1px solid rgba(137, 180, 250, 0.25);
      border-radius: 6px;
      padding: 1px 6px;
      white-space: nowrap;
    }

    .window-title {
      font-size: 13px;
      color: #a6adc8;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
      line-height: 1.35;
    }

    /* Action Buttons */
    .action-buttons {
      display: flex;
      align-items: center;
      gap: 10px;
      flex-shrink: 0;
    }

    .btn {
      display: inline-flex;
      align-items: center;
      gap: 7px;
      padding: 10px 18px;
      border-radius: 12px;
      font-size: 13.5px;
      font-weight: 700;
      cursor: pointer;
      border: 1px solid transparent;
      transition: all 0.15s ease;
    }

    .arrow-svg {
      width: 16px;
      height: 16px;
      fill: none;
    }

    .btn-left {
      background: rgba(137, 180, 250, 0.16);
      color: #89b4fa;
      border-color: rgba(137, 180, 250, 0.35);
    }

    .btn-left:hover {
      background: #89b4fa;
      color: #11111b;
      transform: scale(1.03);
      box-shadow: 0 4px 14px rgba(137, 180, 250, 0.40);
    }

    .btn-right {
      background: rgba(203, 166, 247, 0.16);
      color: #cba6f7;
      border-color: rgba(203, 166, 247, 0.35);
    }

    .btn-right:hover {
      background: #cba6f7;
      color: #11111b;
      transform: scale(1.03);
      box-shadow: 0 4px 14px rgba(203, 166, 247, 0.40);
    }

    .btn:active {
      transform: scale(0.97);
    }

    /* Footer */
    .footer {
      padding: 12px 22px 14px;
      border-top: 1px solid rgba(255, 255, 255, 0.08);
      display: flex;
      align-items: center;
      justify-content: space-between;
      font-size: 11.5px;
      color: #a6adc8;
      background: rgba(17, 17, 27, 0.40);
    }

    .footer-section {
      display: flex;
      align-items: center;
      gap: 5px;
    }

    .key-badge {
      background: rgba(255, 255, 255, 0.08);
      border: 1px solid rgba(255, 255, 255, 0.16);
      border-radius: 5px;
      padding: 2px 7px;
      color: #cdd6f4;
      font-family: ui-monospace, Menlo, monospace;
      font-size: 11px;
      font-weight: 700;
    }
  </style>
</head>
<body>
  <div class="modal-shell">
    <div class="header">
      <div class="header-left">
        <span class="profile-pill">HALVES [ 1/2 ][ 1/2 ]</span>
        <div class="header-title-block">
          <div class="header-title">Assign Center Windows</div>
          <div class="header-subtitle">Choose destination half for each center stage window</div>
        </div>
      </div>
      <button class="close-btn" onclick="dismissModal()" title="Dismiss (Esc)">✕</button>
    </div>

    <div class="windows-container" id="cardsList">
      %s
    </div>

    <div class="footer">
      <div class="footer-section">
        <span>Route:</span>
        <span class="key-badge">←</span>
        <span class="key-badge">A</span>
        <span class="key-badge">1</span>
        <span>Left</span>
        <span style="color: #6c7086; margin: 0 4px;">&bull;</span>
        <span class="key-badge">→</span>
        <span class="key-badge">D</span>
        <span class="key-badge">2</span>
        <span>Right</span>
      </div>
      <div class="footer-section">
        <span>With/Without</span>
        <span class="key-badge">^⌥</span>
        <span style="color: #6c7086; margin: 0 4px;">|</span>
        <span class="key-badge">Esc</span>
        <span>Dismiss</span>
      </div>
    </div>
  </div>

  <script>
    let remaining = document.querySelectorAll('.window-card').length;

    function chooseWindow(winId, direction) {
      const card = document.getElementById('card-' + winId);
      if (!card || card.classList.contains('slide-left') || card.classList.contains('slide-right')) {
        return;
      }
      card.classList.add(direction === 'left' ? 'slide-left' : 'slide-right');
      card.style.pointerEvents = 'none';

      window.webkit.messageHandlers.halvesPicker.postMessage({
        action: 'select',
        windowId: winId,
        direction: direction
      });

      remaining--;
      if (remaining <= 0) {
        setTimeout(function() {
          window.webkit.messageHandlers.halvesPicker.postMessage({ action: 'done' });
        }, 180);
      }
    }

    function chooseNext(direction) {
      const cards = document.querySelectorAll('.window-card:not(.slide-left):not(.slide-right)');
      if (cards.length > 0) {
        const topCard = cards[0];
        const winId = topCard.getAttribute('data-win-id');
        chooseWindow(winId, direction);
      }
    }

    function dismissModal() {
      window.webkit.messageHandlers.halvesPicker.postMessage({ action: 'close' });
    }

    // Keyboard navigation within webview DOM
    document.addEventListener('keydown', function(e) {
      const key = e.key.toLowerCase();
      if (key === 'escape') {
        dismissModal();
        return;
      }

      if (key === 'arrowleft' || key === '1' || key === 'a') {
        chooseNext('left');
      } else if (key === 'arrowright' || key === '2' || key === 'd') {
        chooseNext('right');
      }
    });
  </script>
</body>
</html>
]], table.concat(itemsHTML, "\n"))

  uc:setCallback(function(msg)
    local body = msg.body
    if not body then return end

    if body.action == "select" then
      local win = winMap[body.windowId] or winMap[tonumber(body.windowId)] or winMap[tostring(body.windowId)]
      local entry = entryMap[body.windowId] or entryMap[tonumber(body.windowId)] or entryMap[tostring(body.windowId)]
      local slot = entry and entry.slot
      if win and onSelect then
        onSelect(win, body.direction, slot)
      end
    elseif body.action == "done" or body.action == "close" then
      halvesPicker.close()
      if onDone then onDone() end
    end
  end)

  local wv = hs.webview.new({x = x, y = y, w = width, h = height}, {developerExtras = false}, uc)
  halvesPicker.webview = wv

  wv:windowStyle("borderless")
  wv:transparent(true)
  wv:shadow(false) -- False to remove outer square window border artifact!
  wv:level(hs.canvas.windowLevels.modalPanel)
  wv:html(html)
  wv:show()

  -- OS-level keyboard event tap (intercepts keys globally with or without hotkey combo)
  local function chooseDirection(direction)
    if halvesPicker.webview then
      halvesPicker.webview:evaluateJavaScript(string.format("chooseNext('%s')", direction))
    end
  end

  local function dismiss()
    if halvesPicker.webview then
      halvesPicker.webview:evaluateJavaScript("dismissModal()")
    else
      halvesPicker.close()
      if onDone then onDone() end
    end
  end

  local leftCodes = {
    [123] = true, -- Left Arrow
    [18]  = true, -- '1'
    [83]  = true, -- Numpad '1'
    [0]   = true  -- 'a' / 'A'
  }

  local rightCodes = {
    [124] = true, -- Right Arrow
    [19]  = true, -- '2'
    [84]  = true, -- Numpad '2'
    [2]   = true  -- 'd' / 'D'
  }

  local dismissCodes = {
    [53] = true, -- Escape
    [36] = true  -- Return
  }

  halvesPicker.eventTap = hs.eventtap.new({hs.eventtap.event.types.keyDown}, function(event)
    local code = event:getKeyCode()
    local flags = event:getFlags()

    -- Do not intercept system command combinations (e.g. Cmd+Tab, Cmd+Space)
    if flags.cmd and code ~= 53 then
      return false
    end

    if leftCodes[code] then
      chooseDirection("left")
      return true
    elseif rightCodes[code] then
      chooseDirection("right")
      return true
    elseif dismissCodes[code] then
      dismiss()
      return true
    end

    return false
  end)

  halvesPicker.eventTap:start()
end

return halvesPicker
