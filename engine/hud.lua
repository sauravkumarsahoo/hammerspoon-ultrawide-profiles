-- =============================================================================
-- engine/hud.lua
-- Glassmorphic on-screen HUD with SVG Ultrawide Split Previews
-- =============================================================================

local hud = {
  webview = nil,
  dismissTimer = nil,
  isNotice = false
}

-- Generate dynamic SVG of ultrawide monitor and column split arrangement
local function generateSplitSVG(profile)
  local denom = profile.denominator or 4
  local svgW = 310
  local svgH = 86
  local screenX = 10
  local screenY = 8
  local screenW = 290
  local screenH = 68
  local gap = 3

  -- Column proportions
  local cols = {}
  if denom == 2 then
    cols = {
      { col = "left",  pct = 0.50, label = "1/2", sub = "50%", fill = "rgba(137, 180, 250, 0.24)", stroke = "rgba(137, 180, 250, 0.65)", text = "#89b4fa" },
      { col = "right", pct = 0.50, label = "1/2", sub = "50%", fill = "rgba(203, 166, 247, 0.24)", stroke = "rgba(203, 166, 247, 0.65)", text = "#cba6f7" }
    }
  else
    local leftPct = profile.left or (1 / denom)
    local centerPct = profile.center or (1 - 2 * leftPct)
    local rightPct = profile.right or leftPct

    local centerFraction = string.format("%d/%d", denom - 2, denom)
    if denom == 4 then centerFraction = "1/2" end
    if denom == 6 then centerFraction = "2/3" end

    cols = {
      { col = "left",   pct = leftPct,   label = string.format("1/%d", denom), sub = string.format("%d%%", math.floor(leftPct * 100 + 0.5)),   fill = "rgba(255, 255, 255, 0.08)", stroke = "rgba(255, 255, 255, 0.20)", text = "#a6adc8" },
      { col = "center", pct = centerPct, label = centerFraction,               sub = string.format("%d%%", math.floor(centerPct * 100 + 0.5)), fill = "rgba(137, 180, 250, 0.32)", stroke = "rgba(137, 180, 250, 0.80)", text = "#89b4fa" },
      { col = "right",  pct = rightPct,  label = string.format("1/%d", denom), sub = string.format("%d%%", math.floor(rightPct * 100 + 0.5)),  fill = "rgba(255, 255, 255, 0.08)", stroke = "rgba(255, 255, 255, 0.20)", text = "#a6adc8" }
    }
  end

  -- Calculate rect widths accounting for inter-column gaps
  local totalGaps = (#cols - 1) * gap
  local usableWidth = screenW - totalGaps
  local curX = screenX

  local rectsHTML = {}
  for _, c in ipairs(cols) do
    local colW = math.floor(usableWidth * c.pct)
    local midX = math.floor(curX + (colW / 2))
    local midY = math.floor(screenY + (screenH / 2))

    table.insert(rectsHTML, string.format([[
      <g>
        <rect x="%d" y="%d" width="%d" height="%d" rx="6" fill="%s" stroke="%s" stroke-width="1.5" />
        <text x="%d" y="%d" fill="%s" font-size="13" font-weight="700" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif">%s</text>
        <text x="%d" y="%d" fill="%s" font-size="9.5" font-weight="500" opacity="0.8" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif">%s</text>
      </g>
    ]], curX, screenY, colW, screenH, c.fill, c.stroke, midX, midY - 2, c.text, c.label, midX, midY + 13, c.text, c.sub))

    curX = curX + colW + gap
  end

  return string.format([[
    <svg class="monitor-svg" viewBox="0 0 %d %d" xmlns="http://www.w3.org/2000/svg">
      <!-- Monitor Outer Bezel -->
      <rect x="6" y="4" width="298" height="76" rx="10" fill="#11111b" stroke="rgba(255, 255, 255, 0.16)" stroke-width="1.5"/>
      <!-- Screen Inner Viewport -->
      %s
      <!-- Monitor Stand Accent -->
      <path d="M 135 80 L 142 85 L 168 85 L 175 80 Z" fill="rgba(255, 255, 255, 0.25)"/>
      <rect x="125" y="84" width="60" height="2" rx="1" fill="rgba(255, 255, 255, 0.35)"/>
    </svg>
  ]], svgW, svgH, table.concat(rectsHTML, "\n"))
end

-- Close active HUD
function hud.close()
  if hud.dismissTimer then
    hud.dismissTimer:stop()
    hud.dismissTimer = nil
  end
  if hud.webview then
    hud.webview:delete()
    hud.webview = nil
  end
  hud.isNotice = false
end

-- Show or smoothly update Profile Switching HUD
function hud.showHUD(profile, alert_style, duration)
  duration = duration or 1.4

  local denom = profile.denominator or 4
  local profileNames = {
    [2] = "HALVES",
    [3] = "THIRDS",
    [4] = "FOURTHS",
    [5] = "FIFTHS",
    [6] = "SIXTHS"
  }
  local name = profileNames[denom] or string.format("PROFILE %d", denom)

  local subDescriptions = {
    [2] = "Dual Split: 50% Left &bull; 50% Right",
    [3] = "Equidistant Split: 33.3% Each Column",
    [4] = "Center Stage: 50% &bull; Side Columns: 25%",
    [5] = "Ultra Center: 60% &bull; Side Columns: 20%",
    [6] = "Maximum Focus: 66.7% &bull; Side Columns: 16.7%"
  }
  local subDesc = subDescriptions[denom] or profile.label

  local svgHTML = generateSplitSVG(profile)

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

    .hud-shell {
      background: rgba(24, 24, 37, 0.94);
      backdrop-filter: blur(28px);
      -webkit-backdrop-filter: blur(28px);
      border: 1px solid rgba(137, 180, 250, 0.32);
      border-radius: 20px;
      padding: 18px 22px 16px;
      width: 100%%;
      height: 100%%;
      box-shadow: 0 20px 50px rgba(0, 0, 0, 0.65), 0 0 0 1px rgba(255, 255, 255, 0.08);
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: space-between;
      animation: popIn 0.16s cubic-bezier(0.16, 1, 0.3, 1);
      transition: opacity 0.2s ease, transform 0.2s ease;
    }

    .hud-shell.fade-out {
      opacity: 0;
      transform: scale(0.96) translateY(4px);
    }

    @keyframes popIn {
      from {
        opacity: 0;
        transform: scale(0.95) translateY(8px);
      }
      to {
        opacity: 1;
        transform: scale(1.0) translateY(0);
      }
    }

    /* Header */
    .header {
      width: 100%%;
      display: flex;
      align-items: center;
      justify-content: space-between;
    }

    .title-group {
      display: flex;
      align-items: center;
      gap: 10px;
    }

    .profile-title {
      font-size: 16px;
      font-weight: 800;
      letter-spacing: 0.5px;
      color: #ffffff;
    }

    .denom-badge {
      background: rgba(137, 180, 250, 0.18);
      border: 1px solid rgba(137, 180, 250, 0.40);
      color: #89b4fa;
      font-size: 11px;
      font-weight: 700;
      padding: 3px 8px;
      border-radius: 8px;
      letter-spacing: 0.3px;
    }

    .key-badge {
      background: rgba(255, 255, 255, 0.08);
      border: 1px solid rgba(255, 255, 255, 0.15);
      border-radius: 6px;
      padding: 3px 8px;
      color: #bac2de;
      font-family: ui-monospace, Menlo, monospace;
      font-size: 11px;
      font-weight: 600;
    }

    /* SVG Container */
    .svg-container {
      width: 100%%;
      display: flex;
      justify-content: center;
      align-items: center;
      margin: 10px 0 8px;
    }

    .monitor-svg {
      width: 100%%;
      max-width: 320px;
      height: auto;
      filter: drop-shadow(0 6px 14px rgba(0, 0, 0, 0.45));
    }

    /* Footer Info */
    .footer-desc {
      font-size: 12px;
      font-weight: 500;
      color: #a6adc8;
      text-align: center;
      letter-spacing: 0.2px;
    }
  </style>
</head>
<body>
  <div class="hud-shell" id="hudShell">
    <div class="header">
      <div class="title-group">
        <span class="profile-title">%s</span>
        <span class="denom-badge">Profile %d</span>
      </div>
      <div class="key-badge">^⌥%d / ^⌥`</div>
    </div>

    <div class="svg-container">
      %s
    </div>

    <div class="footer-desc">
      %s
    </div>
  </div>

  <script>
    function triggerFadeOut() {
      const shell = document.getElementById('hudShell');
      if (shell) shell.classList.add('fade-out');
    }
  </script>
</body>
</html>
  ]], name, denom, denom, svgHTML, subDesc)

  local screen = hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
  local sFrame = screen:frame()

  local width = 390
  local height = 230
  local x = math.floor(sFrame.x + (sFrame.w - width) / 2)
  local y = math.floor(sFrame.y + (sFrame.h - height) / 2)

  -- If webview already exists and was not a notice, update content smoothly
  if hud.webview and not hud.isNotice then
    hud.webview:html(html)
  else
    hud.close()
    local wv = hs.webview.new({x = x, y = y, w = width, h = height}, {developerExtras = false})
    hud.webview = wv
    wv:windowStyle("borderless")
    wv:transparent(true)
    wv:shadow(false) -- False to prevent rectangular macOS window borders
    wv:level(hs.canvas.windowLevels.modalPanel)
    wv:html(html)
    wv:show()
  end

  hud.isNotice = false

  -- Reset auto-dismiss timer
  if hud.dismissTimer then
    hud.dismissTimer:stop()
  end
  hud.dismissTimer = hs.timer.doAfter(duration, function()
    if hud.webview then
      hud.webview:evaluateJavaScript("triggerFadeOut()")
      hs.timer.doAfter(0.2, function()
        hud.close()
      end)
    else
      hud.close()
    end
  end)
end

-- Show quick notice pill (e.g. DYNAMIC REFIT: ENABLED)
function hud.showNotice(message, alert_style, duration)
  duration = duration or 0.9
  hud.close()

  local screen = hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
  local sFrame = screen:frame()

  local width = 360
  local height = 100
  local x = math.floor(sFrame.x + (sFrame.w - width) / 2)
  local y = math.floor(sFrame.y + (sFrame.h - height) / 2)

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
    }
    body {
      background: transparent;
      font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", "Inter", sans-serif;
      padding: 16px;
      height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      overflow: hidden;
    }
    .notice-shell {
      background: rgba(24, 24, 37, 0.94);
      backdrop-filter: blur(28px);
      -webkit-backdrop-filter: blur(28px);
      border: 1px solid rgba(137, 180, 250, 0.35);
      border-radius: 16px;
      padding: 12px 20px;
      box-shadow: 0 16px 40px rgba(0, 0, 0, 0.6), 0 0 0 1px rgba(255, 255, 255, 0.08);
      display: flex;
      align-items: center;
      gap: 12px;
      animation: noticePop 0.16s cubic-bezier(0.16, 1, 0.3, 1);
    }
    @keyframes noticePop {
      from { opacity: 0; transform: scale(0.94); }
      to   { opacity: 1; transform: scale(1.0); }
    }
    .icon-badge {
      width: 32px;
      height: 32px;
      border-radius: 9px;
      background: rgba(137, 180, 250, 0.18);
      border: 1px solid rgba(137, 180, 250, 0.35);
      display: flex;
      align-items: center;
      justify-content: center;
      color: #89b4fa;
      font-size: 16px;
      flex-shrink: 0;
    }
    .notice-text {
      color: #ffffff;
      font-size: 14px;
      font-weight: 700;
      letter-spacing: 0.3px;
    }
  </style>
</head>
<body>
  <div class="notice-shell">
    <div class="icon-badge">⚡</div>
    <div class="notice-text">%s</div>
  </div>
</body>
</html>
  ]], message)

  local wv = hs.webview.new({x = x, y = y, w = width, h = height}, {developerExtras = false})
  hud.webview = wv
  hud.isNotice = true

  wv:windowStyle("borderless")
  wv:transparent(true)
  wv:shadow(false)
  wv:level(hs.canvas.windowLevels.modalPanel)
  wv:html(html)
  wv:show()

  if hud.dismissTimer then
    hud.dismissTimer:stop()
  end
  hud.dismissTimer = hs.timer.doAfter(duration, function()
    hud.close()
  end)
end

return hud
