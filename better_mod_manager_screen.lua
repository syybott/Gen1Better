-- BetterModManager presentation for Gen1BetterMenus.
--
-- The responsive layout and drawing primitives originated in BetterParty.
-- ManagerState owns loader data and actions.
return function(mod, genderExports, compatibility, menuColors,
    useStockOgMenuPalette, menuPaper, rawPaletteCopy)
  local Font = require("src.render.Font")
  local ManagerState = require("src.mods.ManagerState")
  local PaletteFX = require("src.render.PaletteFX")
  local Renderer = require("src.render.Renderer")
  local Strings = require("src.core.Strings")

  local SCREEN_H = 144
  local HEADER_H = 14
  local WHITE = 1
  local LIGHT = 170 / 255
  local DARK = 85 / 255
  local BLACK = 0
  local TINY_GLYPHS = {
    A = { "010", "101", "111", "101", "101" },
    B = { "110", "101", "110", "101", "110" },
    C = { "011", "100", "100", "100", "011" },
    D = { "110", "101", "101", "101", "110" },
    E = { "111", "100", "110", "100", "111" },
    F = { "111", "100", "110", "100", "100" },
    G = { "011", "100", "101", "101", "011" },
    H = { "101", "101", "111", "101", "101" },
    I = { "111", "010", "010", "010", "111" },
    J = { "001", "001", "001", "101", "010" },
    K = { "101", "101", "110", "101", "101" },
    L = { "100", "100", "100", "100", "111" },
    M = { "101", "111", "111", "101", "101" },
    N = { "101", "111", "111", "111", "101" },
    O = { "010", "101", "101", "101", "010" },
    P = { "110", "101", "110", "100", "100" },
    Q = { "010", "101", "101", "111", "011" },
    R = { "110", "101", "110", "101", "101" },
    S = { "011", "100", "010", "001", "110" },
    T = { "111", "010", "010", "010", "010" },
    U = { "101", "101", "101", "101", "111" },
    V = { "101", "101", "101", "101", "010" },
    W = { "101", "101", "111", "111", "101" },
    X = { "101", "101", "010", "101", "101" },
    Y = { "101", "101", "010", "010", "010" },
    Z = { "111", "001", "010", "100", "111" },
    ["0"] = { "111", "101", "101", "101", "111" },
    ["1"] = { "010", "110", "010", "010", "111" },
    ["2"] = { "111", "001", "111", "100", "111" },
    ["3"] = { "111", "001", "111", "001", "111" },
    ["4"] = { "101", "101", "111", "001", "001" },
    ["5"] = { "111", "100", "111", "001", "111" },
    ["6"] = { "111", "100", "111", "101", "111" },
    ["7"] = { "111", "001", "010", "010", "010" },
    ["8"] = { "111", "101", "111", "101", "111" },
    ["9"] = { "111", "101", "111", "001", "111" },
    ["-"] = { "000", "000", "111", "000", "000" },
    ["/"] = { "001", "001", "010", "100", "100" },
    ["%"] = { "101", "001", "010", "100", "101" },
    ["("] = { "011", "100", "100", "100", "011" },
    [")"] = { "110", "001", "001", "001", "110" },
    [":"] = { "000", "010", "000", "010", "000" },
    ["'"] = { "010", "010", "000", "000", "000" },
    ["."] = { "000", "000", "000", "000", "010" },
    [" "] = { "000", "000", "000", "000", "000" },
  }

  local function gray(value)
    love.graphics.setColor(value, value, value, 1)
  end

  local inkShader
  local function shaderForInk()
    if inkShader == nil then
      if not love.graphics.newShader then
        inkShader = false
      else
        local ok, shader = pcall(love.graphics.newShader, [[
          vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
            vec4 pixel = Texel(tex, tc);
            return vec4(color.rgb, pixel.a * color.a);
          }
        ]])
        inkShader = ok and shader or false
      end
    end
    return inkShader or nil
  end

  local function cleanTinyText(text)
    return tostring(text or ""):upper()
  end

  local function tinyTextWidth(text)
    local length = #cleanTinyText(text)
    return length > 0 and length * 4 - 1 or 0
  end

  local function tinyTextFit(text, maxWidth)
    text = cleanTinyText(text)
    local count = math.max(0, math.floor((math.floor(maxWidth or 0) + 1) / 4))
    return text:sub(1, count)
  end

  local function wrapTinyText(text, columns)
    columns = math.max(1, math.floor(tonumber(columns) or 1))
    local lines = {}
    for paragraph in tostring(text or ""):gmatch("[^\n]+") do
      local line = ""
      for word in paragraph:gmatch("%S+") do
        local candidate = line == "" and word or line .. " " .. word
        if #cleanTinyText(candidate) > columns and line ~= "" then
          lines[#lines + 1] = cleanTinyText(line):sub(1, columns)
          line = word
        else
          line = candidate
        end
      end
      lines[#lines + 1] = cleanTinyText(line):sub(1, columns)
    end
    if #lines == 0 then lines[1] = "" end
    return lines
  end

  local function drawTinyText(text, x, y, shade)
    text = cleanTinyText(text)
    gray(shade == nil and BLACK or shade)
    local cursor = math.floor(x)
    y = math.floor(y)
    for character in text:gmatch(".") do
      local glyph = TINY_GLYPHS[character]
      if glyph then
        for row = 1, 5 do
          for column = 1, 3 do
            if glyph[row]:sub(column, column) == "1" then
              love.graphics.rectangle("fill", cursor + column - 1,
                y + row - 1, 1, 1)
            end
          end
        end
      end
      cursor = cursor + 4
    end
  end

  local function drawTinyCentered(text, centerX, y, maxWidth, shade)
    text = tinyTextFit(text, maxWidth)
    drawTinyText(text, centerX - tinyTextWidth(text) / 2, y, shade)
  end

  local function drawTinyRight(text, right, y, maxWidth, shade)
    text = tinyTextFit(text, maxWidth)
    drawTinyText(text, right - tinyTextWidth(text), y, shade)
  end

  local function fitText(text, maxWidth)
    text = tostring(text or "")
    maxWidth = math.max(0, math.floor(maxWidth or Font.width(text)))
    if Font.width(text) <= maxWidth then return text end
    local spans = Font.split(text)
    local count = Font.spansFitting(spans, math.max(0, maxWidth - 8))
    if count < 1 then return "" end
    return text:sub(1, spans[count].to) .. "."
  end

  local function drawCentered(text, centerX, y, maxWidth, shade)
    text = fitText(text, maxWidth)
    love.graphics.push("all")
    gray(shade == nil and BLACK or shade)
    Font.draw(text, math.floor(centerX - Font.width(text) / 2), math.floor(y))
    love.graphics.pop()
  end

  local function pixelRoundFill(x, y, width, height)
    x, y, width, height = math.floor(x), math.floor(y),
      math.floor(width), math.floor(height)
    if width < 5 or height < 5 then
      love.graphics.rectangle("fill", x, y, width, height)
      return
    end
    love.graphics.rectangle("fill", x + 2, y, width - 4, height)
    love.graphics.rectangle("fill", x + 1, y + 1, width - 2, height - 2)
    love.graphics.rectangle("fill", x, y + 2, width, height - 4)
  end

  local function panelFrame(panel, faceShade)
    gray(DARK)
    pixelRoundFill(panel.x, panel.y, panel.w, panel.h)
    gray(faceShade or WHITE)
    pixelRoundFill(panel.x + 2, panel.y + 2,
      panel.w - 4, panel.h - 4)
  end

  local function displayPixels()
    local width, height
    if love.graphics.getPixelDimensions then
      width, height = love.graphics.getPixelDimensions()
    else
      width, height = love.graphics.getDimensions()
    end
    width, height = tonumber(width) or 160, tonumber(height) or SCREEN_H
    return width, height
  end

  local function responsiveSize()
    local width, height = displayPixels()
    local scale = math.max(1, math.floor(math.min(
      width / (Renderer.WIDTH or 160), height / SCREEN_H)))
    return math.max(160, math.min(400, math.floor(width / scale))),
      math.max(SCREEN_H, math.floor(height / scale))
  end

  local function layoutFor(screen)
    local width, height = responsiveSize()
    local renderer = screen and screen.game and screen.game.renderer
    if renderer and renderer.uiSize then
      local rendererW, rendererH = renderer:uiSize()
      width, height = rendererW or width, rendererH or height
    end
    width = math.max(160, math.floor(width))
    height = math.max(SCREEN_H, math.floor(height))
    local headerH = HEADER_H
    local footerH = 9
    local footerY = height - footerH
    local rosterW = math.min(118,
      math.max(94, math.floor(width * 0.31) + 6))
    local detailX = rosterW + 7
    local panelY = headerH + 3
    local panelH = footerY - panelY - 3
    return {
      width = width, height = height, headerH = headerH,
      footerY = footerY, footerH = footerH,
      party = { x = 3, y = panelY, w = rosterW, h = panelH },
      detail = { x = detailX, y = panelY,
        w = math.max(80, width - detailX - 3), h = panelH },
    }
  end

  local function drawBackdrop(layout)
    gray(WHITE)
    love.graphics.rectangle("fill", 0, 0, layout.width, layout.height)
    if not (mod.options and mod.options:get("menu_wallpaper") == true) then return end
    gray(LIGHT)
    for x = -layout.height, layout.width, 16 do
      love.graphics.line(x, layout.headerH, x + layout.height, layout.footerY)
      love.graphics.line(x + layout.height, layout.headerH, x, layout.footerY)
    end
  end
  -- BetterModManager ----------------------------------------------------------
  --
  -- ManagerState remains the controller for loader state, dependencies,
  -- profiles, options, permissions, errors, persistence, and restart flow.
  -- The code below adapts that controller to the BetterParty-derived layout.

  local FILTER_H = 17
  local MANAGER_TABS = { "MODS", "PROFILES", "ERRORS" }
  local registeredOptionsHeaders = {}

  local function managerOptionsHeaderHook(screen)
    if screen.screen ~= "options" or not screen.currentMod then
      return nil
    end
    local cur = screen.currentMod
    local id = tostring(cur.id or cur.name or "")
    local hook = registeredOptionsHeaders[id]
    if hook then return hook end

    hook = cur.optionsHeader or cur.drawOptionsHeader or cur.optionsBanner
    if hook then return hook end

    local loader = screen.game and screen.game.mods
    local loadedMod = loader and loader.mods and loader.mods[id]
    if loadedMod then
      hook = loadedMod.optionsHeader or loadedMod.drawOptionsHeader
        or (loadedMod.exports and (loadedMod.exports.optionsHeader or loadedMod.exports.drawOptionsHeader))
      if hook then return hook end
    end

    local schema = screen.schema or (screen.schemaFor and screen:schemaFor(cur))
    if type(schema) == "table" then
      hook = schema.optionsHeader or schema.drawOptionsHeader or schema.header
      if hook then return hook end
    end

    local hooks = (mod and mod.hooks) or (loader and loader.hooks)
    if hooks and hooks.chains and (hooks.chains["bettermodmanager.options_header"] or hooks.chains["modmanager.options.header"]) then
      local chainName = hooks.chains["bettermodmanager.options_header"] and "bettermodmanager.options_header" or "modmanager.options.header"
      return function(s, r, m)
        return hooks:call(chainName, function() end, s, r, m)
      end
    end
    return nil
  end

  local function managerHasSubheader(screen)
    if screen.screen == "list" and screen.tab == 1 then
      return true
    elseif screen.screen == "options" then
      return managerOptionsHeaderHook(screen) ~= nil
    end
    return false
  end

  local function managerClamp(value, minimum, maximum)
    if maximum < minimum then return minimum end
    return math.max(minimum, math.min(maximum, value))
  end

  local function managerWrap(value, count)
    if count <= 0 then return 1 end
    if value < 1 then return count end
    if value > count then return 1 end
    return value
  end

  local function managerLayoutFor(screen)
    local layout = layoutFor(screen)
    local hasSubheader = managerHasSubheader(screen)
    local subheaderH = hasSubheader and FILTER_H or 0
    local panelY = layout.headerH + subheaderH + 3
    local panelH = layout.footerY - panelY - 3
    layout.hasSubheader = hasSubheader
    layout.filter = {
      x = 0, y = layout.headerH,
      w = layout.width, h = subheaderH,
    }
    layout.party.y, layout.party.h = panelY, panelH
    layout.detail.y, layout.detail.h = panelY, panelH
    layout.full = {
      x = layout.party.x,
      y = panelY,
      w = layout.detail.x + layout.detail.w - layout.party.x,
      h = panelH,
    }
    return layout
  end

  local function capsule(rect, selected, outerInset, innerInset)
    outerInset = outerInset or 0
    innerInset = innerInset or (outerInset + 1)
    gray(selected and BLACK or DARK)
    pixelRoundFill(rect.x + outerInset, rect.y + outerInset,
      rect.w - outerInset * 2, rect.h - outerInset * 2)
    gray(selected and WHITE or LIGHT)
    pixelRoundFill(rect.x + innerInset, rect.y + innerInset,
      rect.w - innerInset * 2, rect.h - innerInset * 2)
  end

  local function managerArrow(x, y, direction, shade)
    gray(shade == nil and BLACK or shade)
    if direction == "left" then
      love.graphics.polygon("fill",
        x + 5, y, x, y + 4, x + 5, y + 8)
    elseif direction == "right" then
      love.graphics.polygon("fill",
        x, y, x + 5, y + 4, x, y + 8)
    elseif direction == "down" then
      love.graphics.polygon("fill",
        x, y, x + 8, y, x + 4, y + 5)
    end
  end

  local SELECTOR_ON_SECONDS = 1.100
  local SELECTOR_PERIOD_SECONDS = SELECTOR_ON_SECONDS + 0.550
  local SELECTOR_ENTRY_ELAPSED = SELECTOR_ON_SECONDS - 0.350

  local function upperSelectionVisible(screen, focus)
    if not screen.betterUpperFlash or screen.betterFocus ~= focus then
      return true
    end
    return (screen.betterUpperBlinkElapsed or 0)
      % SELECTOR_PERIOD_SECONDS < SELECTOR_ON_SECONDS
  end

  local function enterUpperRow(screen, focus)
    screen.betterFocus = focus
    screen.betterUpperFlash = true
    screen.betterUpperBlinkElapsed = SELECTOR_ENTRY_ELAPSED
  end

  local function drawManagerHeader(screen, layout)
    gray(DARK)
    love.graphics.rectangle("fill", 0, 0, layout.width, layout.headerH)
    drawTinyText("MOD MANAGER", 5, 5, WHITE)

    local widths = { 39, 55, 43 }
    local gap = 3
    local total = widths[1] + widths[2] + widths[3] + gap * 2
    local x = layout.width - total - 4
    for index, label in ipairs(MANAGER_TABS) do
      local rect = { x = x, y = 2, w = widths[index], h = 10 }
      local selected = index == screen.tab
      local showSelection = selected and upperSelectionVisible(screen, "tabs")
      capsule(rect, showSelection, 0, 1)
      drawTinyCentered(label, rect.x + rect.w / 2,
        rect.y + 3, rect.w - 12, showSelection and BLACK or DARK)
      x = x + rect.w + gap
    end
  end

  local function managerCategories(screen)
    local seen, categories = {}, { "ALL" }
    for _, candidate in ipairs(screen.status and screen.status.available or {}) do
      seen[tostring(candidate.category or "OTHER"):upper()] = true
    end
    local sorted = {}
    for category in pairs(seen) do sorted[#sorted + 1] = category end
    table.sort(sorted)
    for _, category in ipairs(sorted) do categories[#categories + 1] = category end
    return categories
  end

  local function managerMods(screen)
    local rows = {}
    local category = screen.betterCategory or "ALL"
    for _, candidate in ipairs(screen.status and screen.status.available or {}) do
      local ownCategory = tostring(candidate.category or "OTHER"):upper()
      if category == "ALL" or category == ownCategory then
        rows[#rows + 1] = candidate
      end
    end
    table.sort(rows, function(a, b)
      local an = tostring(a.name or a.id):upper()
      local bn = tostring(b.name or b.id):upper()
      if an == bn then return tostring(a.id) < tostring(b.id) end
      return an < bn
    end)
    screen.betterModIndex = managerClamp(screen.betterModIndex or 1,
      1, math.max(1, #rows))
    return rows
  end

  local function managerProfiles(screen)
    local rows = { { adhoc = true, label = "AD-HOC" } }
    for _, profile in ipairs(screen:optionsTable().modProfiles or {}) do
      rows[#rows + 1] = { profile = profile, label = profile.name }
    end
    screen.betterProfileIndex = managerClamp(screen.betterProfileIndex or 1,
      1, math.max(1, #rows))
    return rows
  end

  local function managerModActions(screen, selected)
    if not selected then return {} end
    local rows = {}
    for _, row in ipairs(screen:detailRows(selected)) do
      local label = tostring(row.label or "")
      if label ~= "ENABLE" and label ~= "DISABLE" and label ~= "BACK" then
        rows[#rows + 1] = row
      end
    end
    return rows
  end

  local function managerProfileActions(screen, selected)
    return {
      { label = Strings("SAVE CURRENT AS.."),
        action = function() screen:saveCurrentAs() end },
      { label = Strings("EXPORT.."),
        inert = not (selected and selected.profile),
        action = function()
          if not (selected and selected.profile) then return end
          local ok = require("src.mods.ModProfile").export(selected.profile)
          screen:notify(ok and ("SAVED " .. selected.profile.name)
            or "EXPORT FAILED")
        end },
      { label = Strings("IMPORT.."),
        action = function() screen:importProfiles() end },
    }
  end

  local function drawManagerFilter(screen, layout)
    if not layout.hasSubheader then return end

    gray(WHITE)
    love.graphics.rectangle("fill", layout.filter.x, layout.filter.y,
      layout.filter.w, layout.filter.h)
    gray(DARK)
    love.graphics.rectangle("fill", 0,
      layout.filter.y + layout.filter.h - 1, layout.width, 1)

    if screen.screen == "options" then
      local hook = managerOptionsHeaderHook(screen)
      if type(hook) == "function" then
        local ok, err = pcall(hook, screen, layout.filter, screen.currentMod)
        if not ok and mod and mod.log then
          mod.log:error("Options header hook failed for %s: %s",
            tostring(screen.currentMod and screen.currentMod.id or "?"), tostring(err))
        end
      elseif type(hook) == "string" then
        drawTinyCentered(hook, layout.filter.x + layout.filter.w / 2,
          layout.filter.y + 4, layout.filter.w - 8, DARK)
      end
      return
    end

    if screen.screen ~= "list" or screen.tab ~= 1 then return end
    local categories = managerCategories(screen)
    local available = layout.width - 8
    local gap = 3
    local widths, total = {}, gap * (#categories - 1)
    for index, category in ipairs(categories) do
      widths[index] = math.max(35, tinyTextWidth(category) + 16)
      total = total + widths[index]
    end
    local scale = math.min(1, available / total)
    local x = 4
    for index, category in ipairs(categories) do
      local width = math.floor(widths[index] * scale)
      local selected = category == screen.betterCategory
      local rect = { x = x, y = layout.filter.y + 2,
        w = width, h = layout.filter.h - 4 }
      local showSelection = selected
        and upperSelectionVisible(screen, "categories")
      capsule(rect, showSelection, 1, 2)
      local shade = showSelection and screen.betterFocus == "categories"
        and BLACK or DARK
      drawTinyCentered(category, rect.x + rect.w / 2,
        rect.y + 4, rect.w - 8, shade)
      x = x + width + gap
    end
  end

  local function managerRowRect(panel, index, count)
    local innerY = panel.y + 4
    local rowH = 10
    return { x = panel.x + 4, y = innerY + (index - 1) * rowH,
      w = panel.w - 8, h = rowH }
  end

  local function drawModRoster(screen, layout)
    panelFrame(layout.party, WHITE)
    local rows = managerMods(screen)
    if #rows == 0 then
      drawCentered("NO MODS", layout.party.x + layout.party.w / 2,
        layout.party.y + 12, layout.party.w - 12, BLACK)
      return nil
    end
    local visible = math.max(1, math.floor((layout.party.h - 8) / 10))
    local scroll = screen.betterModScroll or 1
    if screen.betterModIndex < scroll then scroll = screen.betterModIndex end
    if screen.betterModIndex >= scroll + visible then
      scroll = screen.betterModIndex - visible + 1
    end
    scroll = managerClamp(scroll, 1, math.max(1, #rows - visible + 1))
    screen.betterModScroll = scroll
    for slot = 1, visible do
      local index = scroll + slot - 1
      local row = rows[index]
      if not row then break end
      local rect = managerRowRect(layout.party, slot, visible)
      local selected = index == screen.betterModIndex
      if selected then
        gray(screen.betterFocus == "left" and DARK or LIGHT)
        pixelRoundFill(rect.x, rect.y, rect.w, rect.h)
      else
        gray(LIGHT)
        love.graphics.rectangle("fill", rect.x + 2,
          rect.y + rect.h - 1, rect.w - 4, 1)
      end
      if selected then
        managerArrow(rect.x + 4, rect.y + math.floor((rect.h - 8) / 2),
          "right", screen.betterFocus == "left" and WHITE or BLACK)
      end
      local shade = selected and screen.betterFocus == "left" and WHITE or BLACK
      drawTinyText(tinyTextFit(row.name or row.id, rect.w - 18),
        rect.x + 14, rect.y + 3, shade)
    end
    return rows[screen.betterModIndex]
  end

  local function drawRule(x, y, width)
    gray(LIGHT)
    love.graphics.rectangle("fill", x, y, width, 1)
  end

  local function drawModDetailPreview(screen, layout, selected)
    panelFrame(layout.detail, WHITE)
    if not selected then return end
    local panel = layout.detail
    local x, width = panel.x + 7, panel.w - 14
    local title = tostring(selected.name or selected.id or "MOD")
    if selected.version and tostring(selected.version) ~= "" then
      title = title .. " " .. tostring(selected.version)
    end
    drawTinyText(tinyTextFit(title, width), x, panel.y + 6, BLACK)
    local status = selected.enabled and "ENABLED" or "DISABLED"
    if screen:isStaged(selected) then status = status .. " (STAGED)" end
    if selected.state == "wrong_generation" or not screen:runsHere(selected) then
      status = status .. " (NOT THIS GAME)"
    elseif selected.state == "blocked_dependency" then
      status = status .. " BLOCKED"
    elseif selected.error then
      status = status .. " ERROR"
    end
    drawTinyText(status, x, panel.y + 15, BLACK)
    drawTinyText(tostring(selected.category or "OTHER") .. " / "
      .. tostring(selected.profile or "content"),
      x, panel.y + 23, BLACK)
    drawRule(x, panel.y + 30, width)

    local description = selected.error and ("FAILED: " .. selected.error)
      or selected.note and ("SKIPPED: " .. selected.note)
      or selected.description
    local lines = wrapTinyText(description or
      "Select a mod to view its description.",
      math.max(10, math.floor(width / 4)))
    for index = 1, math.min(4, #lines) do
      drawTinyText(lines[index], x, panel.y + 34 + (index - 1) * 7, BLACK)
    end
    local actionY = panel.y + 66
    drawRule(x, actionY - 5, width)
    local actions = managerModActions(screen, selected)
    if #actions == 0 then actions[1] = { label = "NO ACTIONS", inert = true } end
    screen.betterActionIndex = managerClamp(screen.betterActionIndex or 1,
      1, #actions)
    local marqueeEnabled = mod and mod.options
      and mod.options:get("marquee_text") ~= false
    local maxWidth = width - 14
    for index, row in ipairs(actions) do
      local y = actionY + (index - 1) * 9
      local isFocused = index == screen.betterActionIndex and screen.betterFocus == "right"
      if isFocused then
        managerArrow(x, y, "right", BLACK)
      end
      local label = tostring(row.label or "")
      local shade = row.inert and LIGHT or BLACK
      local textX = x + 10
      local textW = tinyTextWidth(label)
      if isFocused and textW > maxWidth and marqueeEnabled then
        local gap = 24
        local stride = textW + gap
        local offset = math.floor((screen.marquee or 0) / 8) % stride
        local sx, sy, sw, sh = love.graphics.getScissor()
        love.graphics.setScissor(textX, y, maxWidth, 9)
        local drawX = textX - offset
        while drawX < textX + maxWidth do
          drawTinyText(label, drawX, y + 1, shade)
          drawX = drawX + stride
        end
        if sx then love.graphics.setScissor(sx, sy, sw, sh) else love.graphics.setScissor() end
      else
        drawTinyText(tinyTextFit(label, maxWidth), textX, y + 1, shade)
      end
    end
  end

  local function drawProfileRoster(screen, layout)
    panelFrame(layout.party, WHITE)
    local rows = managerProfiles(screen)
    local heading = { x = layout.party.x + 4, y = layout.party.y + 4,
      w = layout.party.w - 8, h = 14 }
    gray(LIGHT)
    pixelRoundFill(heading.x, heading.y, heading.w, heading.h)
    managerArrow(heading.x + 5, heading.y + 4, "down", BLACK)
    drawTinyText("PROFILES", heading.x + 20, heading.y + 5, BLACK)
    for index, row in ipairs(rows) do
      local rect = { x = layout.party.x + 4,
        y = heading.y + heading.h + (index - 1) * 16,
        w = layout.party.w - 8, h = 15 }
      local selected = index == screen.betterProfileIndex
      if selected then
        gray(screen.betterFocus == "left" and DARK or LIGHT)
        pixelRoundFill(rect.x, rect.y, rect.w, rect.h)
        managerArrow(rect.x + 5, rect.y + 3, "right",
          screen.betterFocus == "left" and WHITE or BLACK)
      else
        drawRule(rect.x + 2, rect.y + rect.h - 1, rect.w - 4)
      end
      drawTinyText(row.label, rect.x + 18, rect.y + 5,
        selected and screen.betterFocus == "left" and WHITE or BLACK)
    end
    return rows[screen.betterProfileIndex]
  end

  local function drawProfileDetailPreview(screen, layout, selected)
    panelFrame(layout.detail, WHITE)
    local panel = layout.detail
    local profile = selected and selected.profile
    local name = profile and profile.name or "AD-HOC"
    local activeName = screen:optionsTable().activeProfile
    local active = profile and activeName == profile.name
      or selected and selected.adhoc and activeName == nil
    local centerX = panel.x + panel.w / 2
    local iconY = panel.y + 11
    gray(DARK)
    pixelRoundFill(centerX - 17, iconY + 4, 34, 23)
    pixelRoundFill(centerX - 13, iconY, 14, 8)
    gray(LIGHT)
    pixelRoundFill(centerX - 14, iconY + 7, 28, 17)
    gray(WHITE)
    love.graphics.rectangle("fill", centerX - 6, iconY + 9, 12, 9)
    gray(DARK)
    love.graphics.rectangle("fill", centerX - 3, iconY + 11, 6, 4)
    drawTinyCentered(name, centerX, iconY + 33,
      panel.w - 16, BLACK)
    local x, width, y = panel.x + 7, panel.w - 14, iconY + 45
    drawRule(x, y, width)
    drawTinyText("TYPE   : " .. (profile and "SAVED PROFILE" or "AD-HOC"),
      x, y + 6, BLACK)
    drawTinyText("STATUS : " .. (active and "ACTIVE" or "INACTIVE"),
      x, y + 14, BLACK)
    drawRule(x, y + 24, width)
    local actions = managerProfileActions(screen, selected)
    screen.betterActionIndex = managerClamp(screen.betterActionIndex or 1,
      1, #actions)
    for index, row in ipairs(actions) do
      local actionY = y + 31 + (index - 1) * 10
      if index == screen.betterActionIndex and screen.betterFocus == "right" then
        managerArrow(x, actionY, "right", BLACK)
      end
      drawTinyText(row.label, x + 10, actionY + 1,
        row.inert and LIGHT or BLACK)
    end
  end

  local function drawFullPane(screen, layout, title, rows, values)
    panelFrame(layout.full, WHITE)
    local x, width = layout.full.x + 8, layout.full.w - 16
    drawTinyText(title, x, layout.full.y + 7, BLACK)
    drawRule(x, layout.full.y + 17, width)
    local listY = layout.full.y + 24
    local visible = math.max(1,
      math.floor((layout.full.y + layout.full.h - listY - 5) / 10))
    local scroll = screen.betterFullScroll or 1
    if screen.cursor < scroll then scroll = screen.cursor end
    if screen.cursor >= scroll + visible then
      scroll = screen.cursor - visible + 1
    end
    scroll = managerClamp(scroll, 1, math.max(1, #rows - visible + 1))
    screen.betterFullScroll = scroll
    for slot = 1, visible do
      local index = scroll + slot - 1
      local row = rows[index]
      if not row then break end
      local y = listY + (slot - 1) * 10
      local label = type(row) == "table" and row.label or row
      local value = type(row) == "table" and row.value or nil
      if index == screen.cursor and not row.inert then
        managerArrow(x, y, "right", BLACK)
      end
      drawTinyText(label, x + 10, y + 1, row.inert and LIGHT or BLACK)
      if values and value then
        local rendered = type(value) == "function" and value(screen.game)
          or value
        drawTinyRight(tostring(rendered or ""), x + width, y + 1,
          math.floor(width * 0.35), BLACK)
      end
    end
  end

  local function drawFooterArrows(x, y)
    gray(WHITE)
    love.graphics.polygon("fill", x, y + 4, x + 3, y + 1, x + 3, y + 7)
    love.graphics.polygon("fill", x + 12, y + 4, x + 9, y + 1,
      x + 9, y + 7)
  end

  local function drawFooterText(text, x, y)
    love.graphics.push("all")
    local shader = shaderForInk()
    if shader then
      love.graphics.setShader(shader)
      gray(WHITE)
    else
      gray(BLACK)
    end
    Font.draw(text, math.floor(x), math.floor(y))
    love.graphics.pop()
  end

  local function drawFooterGroups(screen, layout, labels, arrows)
    local gap, arrowW = 16, arrows and 16 or 0
    local stride = arrowW + (arrows and gap or 0)
    for _, label in ipairs(labels) do stride = stride + Font.width(label) + gap end
    local offset = math.floor((screen.footerMarquee or 0) / 8) % stride
    local sx, sy, sw, sh = love.graphics.getScissor()
    love.graphics.setScissor(0, layout.footerY, layout.width, layout.footerH)
    local x = 4 - offset
    while x < layout.width do
      if arrows then
        drawFooterArrows(x, layout.footerY + 1)
        x = x + arrowW
      end
      for _, label in ipairs(labels) do
        drawFooterText(label, x, layout.footerY + 1)
        x = x + Font.width(label) + gap
      end
      if arrows then x = x + gap end
    end
    if sx then love.graphics.setScissor(sx, sy, sw, sh)
    else love.graphics.setScissor() end
  end

  local function drawManagerFooter(screen, layout)
    gray(DARK)
    love.graphics.rectangle("fill", 0, layout.footerY,
      layout.width, layout.footerH)
    if screen.notice then
      drawFooterGroups(screen, layout, { tostring(screen.notice) })
    elseif screen.screen == "options" then
      local row = screen.optionRows and screen.optionRows[screen.cursor]
      if row and row.step then
        drawFooterGroups(screen, layout,
          { "CHANGE OPTION", "[A] SELECT", "[B] BACK" }, true)
      else
        drawFooterGroups(screen, layout,
          { row and row.activate and "[A] OPEN" or "[A] SELECT", "[B] BACK" })
      end
    elseif screen.screen == "permissions" or screen.screen == "errors"
        or screen.screen == "apply" then
      drawFooterGroups(screen, layout, { "[B] BACK" })
    elseif screen.betterFocus == "tabs"
        or screen.betterFocus == "categories" then
      drawFooterGroups(screen, layout,
        { screen.betterFocus == "tabs" and "CHANGE TAB"
          or "CHANGE CATEGORY", "[B] EXIT" }, true)
    elseif screen.tab == 3 then
      drawFooterGroups(screen, layout, { "[B] BACK" })
    elseif screen.tab == 1 then
      drawFooterGroups(screen, layout,
        { "[A] OPEN", "[SELECT] TOGGLE", "[START] APPLY", "[B] EXIT" })
    elseif screen.tab == 2 then
      drawFooterGroups(screen, layout,
        { "[A] APPLY", "[SELECT] RENAME", "[START] DELETE", "[B] EXIT" })
    end
  end

  local function drawManagerOverlay(screen, layout)
    local overlay = screen.overlay
    if not overlay then return end
    local lines = overlay.lines or {}
    local width = math.min(layout.full.w - 20, 160)
    local height = math.max(34, 19 + #lines * 7)
    if overlay.kind == "confirm" then height = height + 10 end
    local x = math.floor((layout.width - width) / 2)
    local y = math.floor((layout.height - height) / 2)
    gray(BLACK)
    pixelRoundFill(x, y, width, height)
    gray(WHITE)
    pixelRoundFill(x + 2, y + 2, width - 4, height - 4)
    for index, line in ipairs(lines) do
      drawTinyCentered(line, x + width / 2, y + 7 + (index - 1) * 7,
        width - 12, BLACK)
    end
    local optionY = y + height - 12
    if overlay.kind == "confirm" then
      drawTinyText("YES", x + 42, optionY, BLACK)
      drawTinyText("NO", x + width - 54, optionY, BLACK)
      managerArrow(overlay.index == 1 and x + 32 or x + width - 64,
        optionY - 2, "right", BLACK)
    else
      drawTinyCentered("[A] OK", x + width / 2, optionY,
        width - 12, BLACK)
    end
  end

  local function drawManagerCandidate(screen)
    local layout = managerLayoutFor(screen)
    drawBackdrop(layout)
    drawManagerHeader(screen, layout)
    drawManagerFilter(screen, layout)
    if screen.screen == "options" then
      local title = screen.currentMod
        and ((screen.currentMod.name or screen.currentMod.id) .. " OPTIONS")
        or "OPTIONS"
      drawFullPane(screen, layout, title, screen.optionRows or {}, true)
    elseif screen.screen == "permissions" then
      drawFullPane(screen, layout, "PERMISSIONS", screen:rowsForScreen(), false)
    elseif screen.screen == "errors" then
      drawFullPane(screen, layout, "ERRORS", screen:rowsForScreen(), false)
    elseif screen.screen == "apply" then
      drawFullPane(screen, layout, "APPLY CHANGES", screen:rowsForScreen(), false)
    elseif screen.tab == 3 then
      drawFullPane(screen, layout, "ERRORS", screen:errorRows(nil), false)
    elseif screen.tab == 2 then
      local profile = drawProfileRoster(screen, layout)
      drawProfileDetailPreview(screen, layout, profile)
    else
      local selected = drawModRoster(screen, layout)
      drawModDetailPreview(screen, layout, selected)
    end
    drawManagerFooter(screen, layout)
    drawManagerOverlay(screen, layout)
    gray(WHITE)
  end

  local function managerCandidatePalettes(screen, game)
    local layout = managerLayoutFor(screen)
    local base = type(menuColors) == "function" and menuColors(game)
      or game and game.data and PaletteFX.pal(game.data, "BLUEMON")
    if not base then return nil end
    return { { colors = base, x = 0, y = 0,
      w = layout.width, h = layout.height } }
  end

  local function selectedManagerMod(screen)
    local rows = managerMods(screen)
    return rows[screen.betterModIndex], rows
  end

  local function selectedManagerProfile(screen)
    local rows = managerProfiles(screen)
    return rows[screen.betterProfileIndex], rows
  end

  local function setManagerTab(screen, tab)
    screen.tab = managerWrap(tab, #MANAGER_TABS)
    screen.betterFocus = "tabs"
    if screen.betterUpperFlash then
      screen.betterUpperBlinkElapsed = SELECTOR_ENTRY_ELAPSED
    end
    screen.betterActionIndex = 1
    screen.cursor, screen.scroll, screen.betterFullScroll = 1, 1, 1
    screen:snapCursor()
  end

  local function moveManagerCategory(screen, direction)
    local rows = managerCategories(screen)
    local index = 1
    for candidate, category in ipairs(rows) do
      if category == screen.betterCategory then index = candidate break end
    end
    screen.betterCategory = rows[managerWrap(index + direction, #rows)]
    if screen.betterUpperFlash then
      screen.betterUpperBlinkElapsed = SELECTOR_ENTRY_ELAPSED
    end
    screen.betterModIndex, screen.betterModScroll = 1, 1
    screen.betterActionIndex = 1
  end

  local function currentManagerActions(screen)
    if screen.tab == 1 then
      return managerModActions(screen, selectedManagerMod(screen))
    elseif screen.tab == 2 then
      return managerProfileActions(screen, selectedManagerProfile(screen))
    end
    return {}
  end

  local function activateManagerRight(screen)
    local rows = currentManagerActions(screen)
    local row = rows[screen.betterActionIndex or 1]
    if not row or row.inert or not row.action then return end
    if screen.tab == 1 then screen.currentMod = selectedManagerMod(screen) end
    screen:confirmSound()
    row.action()
    screen.betterFullScroll = 1
  end

  local function activateManagerLeft(screen)
    if screen.tab == 1 then
      local selected = selectedManagerMod(screen)
      if not selected then return end
      screen.currentMod = selected
      screen.betterFocus, screen.betterActionIndex = "right", 1
      screen.marquee = 0
      screen:confirmSound()
    elseif screen.tab == 2 then
      local selected = selectedManagerProfile(screen)
      if selected and selected.profile then
        screen:confirmSound()
        screen:applyProfile(selected.profile)
      elseif selected and selected.adhoc then
        screen:optionsTable().activeProfile = nil
        screen:persistOptions()
        screen:refresh()
        screen:notify("AD-HOC SET ACTIVE")
      end
    end
  end

  local function updateManagerList(screen, input)
    if input:wasPressed("b") then
      if screen.betterFocus == "right" then
        screen.betterFocus = "left"
      else
        screen:goBack()
      end
      return
    end
    if input:wasPressed("start") then
      screen:pressStart()
      screen.betterFullScroll = 1
      return
    end
    if input:wasPressed("select") then
      if screen.tab == 1 then
        local selected = selectedManagerMod(screen)
        if selected then screen:beginToggle(selected) end
      elseif screen.tab == 2 then
        local selected = selectedManagerProfile(screen)
        if selected and selected.profile then
          screen:renameProfile(selected.profile)
        end
      end
      return
    end
    if screen.betterFocus == "tabs" then
      if input:wasPressed("left") then setManagerTab(screen, screen.tab - 1)
      elseif input:wasPressed("right") then setManagerTab(screen, screen.tab + 1)
      elseif input:wasPressed("down") then
        if screen.tab == 1 then
          enterUpperRow(screen, "categories")
        else
          screen.betterFocus = screen.tab == 3 and "full" or "left"
          screen.betterUpperFlash = false
        end
      end
      return
    end
    if screen.betterFocus == "categories" then
      if input:wasPressed("left") then moveManagerCategory(screen, -1)
      elseif input:wasPressed("right") then moveManagerCategory(screen, 1)
      elseif input:wasPressed("up") then enterUpperRow(screen, "tabs")
      elseif input:wasPressed("down") then
        screen.betterFocus = "left"
        screen.betterUpperFlash = false
      end
      return
    end
    if screen.betterFocus == "full" then
      if input:wasPressed("up") then screen:moveCursor(-1)
      elseif input:wasPressed("down") then screen:moveCursor(1)
      elseif input:wasPressed("a") then screen:activate() end
      return
    end
    if screen.betterFocus == "right" then
      local actions = currentManagerActions(screen)
      if input:wasPressed("up") then
        screen.betterActionIndex = managerWrap(
          (screen.betterActionIndex or 1) - 1, #actions)
        screen.marquee = 0
      elseif input:wasPressed("down") then
        screen.betterActionIndex = managerWrap(
          (screen.betterActionIndex or 1) + 1, #actions)
        screen.marquee = 0
      elseif input:wasPressed("left") then
        screen.betterFocus = "left"
      elseif input:wasPressed("a") then
        activateManagerRight(screen)
      end
      return
    end
    if input:wasPressed("up") then
      if screen.tab == 1 then
        if screen.betterModIndex <= 1 then
          enterUpperRow(screen, "categories")
        else screen.betterModIndex = screen.betterModIndex - 1 end
      elseif screen.tab == 2 then
        if screen.betterProfileIndex <= 1 then
          enterUpperRow(screen, "tabs")
        else screen.betterProfileIndex = screen.betterProfileIndex - 1 end
      end
      screen.betterActionIndex = 1
      screen.marquee = 0
    elseif input:wasPressed("down") then
      if screen.tab == 1 then
        local rows = managerMods(screen)
        screen.betterModIndex = math.min(#rows, screen.betterModIndex + 1)
      elseif screen.tab == 2 then
        local rows = managerProfiles(screen)
        screen.betterProfileIndex = math.min(#rows,
          screen.betterProfileIndex + 1)
      end
      screen.betterActionIndex = 1
      screen.marquee = 0
    elseif input:wasPressed("right") or input:wasPressed("a") then
      activateManagerLeft(screen)
    end
  end

  local function updateManagerFullPane(screen, input)
    if input:wasPressed("b") then
      screen:goBack()
    elseif input:wasPressed("up") then
      screen:moveCursor(-1)
    elseif input:wasPressed("down") then
      screen:moveCursor(1)
    elseif input:wasPressed("a") then
      screen:activate()
    end
  end

  local function updateManagerCandidate(screen, dt)
    screen.marquee = (screen.marquee or 0) + 1
    screen.footerMarquee = (screen.footerMarquee or 0) + 1
    if screen.screen ~= "list" then screen.betterUpperFlash = false end
    if screen.betterUpperFlash then
      screen.betterUpperBlinkElapsed =
        ((screen.betterUpperBlinkElapsed or 0) + (tonumber(dt) or 1 / 60))
        % SELECTOR_PERIOD_SECONDS
    end
    if screen.notice then
      screen.noticeTimer = (screen.noticeTimer or 0) - 1
      if screen.noticeTimer <= 0 then screen.notice = nil end
    end
    local input = screen.game and screen.game.input
    if not input then return end
    if screen.overlay then return screen:updateOverlay(input) end
    if screen.screen == "options" then
      -- Run any registered option-row gate (e.g. the QoL BetterBattle warning
      -- interceptor) before updateOptions processes the input. The gate proxy
      -- is built by the openOptions override below; it shares the same rows
      -- table as screen.optionRows so decorated value functions are live.
      local gate = screen.betterOptionsGate
      if gate then
        gate.index = screen.cursor
        local blocked = gate:update()
        if blocked then return end
      end
      return screen:updateOptions(input)
    end
    if screen.screen == "permissions" or screen.screen == "errors"
        or screen.screen == "apply" then
      return updateManagerFullPane(screen, input)
    end
    return updateManagerList(screen, input)
  end

  local BetterModManagerCandidate = {}
  function BetterModManagerCandidate.new(game, ...)
    local state = ManagerState.new(game, ...)
    local originalEnter = state.enter
    state.betterModManagerCandidate = true
    state.betterModManagerUI = true
    state.betterFocus = "left"
    state.betterCategory = "ALL"
    state.betterModIndex, state.betterModScroll = 1, 1
    state.betterProfileIndex = 1
    state.betterActionIndex = 1
    state.betterUpperFlash = false
    state.betterUpperBlinkElapsed = 0
    state.betterFullScroll = 1
    state.holdsUIAnchors = true
    state.isOpaque = true
    state.letterboxWhite = true
    state.BetterMenusScaleEligible = false
    state.uiSize = function() return responsiveSize() end
    state.isWideBattleLayout = function() return false end
    state.sgbPalettes = managerCandidatePalettes
    state.draw = drawManagerCandidate
    state.update = updateManagerCandidate
    -- Wrap openOptions so that any stack-registered gate decorator is applied
    -- to optionRows after they are built. This preserves custom annotations
    -- (e.g. "OFF (BetterBattle)" value labels) and warning interception that
    -- the decorator normally injects when option screens are pushed via stack.push.
    local baseOpenOptions = state.openOptions
    state.openOptions = function(self, m)
      baseOpenOptions(self, m)
      local rows = self.optionRows
      if not rows or #rows == 0 then return end
      local stack = self.game and self.game.stack
      local decorate = stack and stack.gen1BetterMenusDecorateOptionRows
      if type(decorate) ~= "function" then return end
      -- A proxy exposes optionRows as "rows" and carries a no-op update stub
      -- to satisfy the decorator's guard. After decoration, proxy.update
      -- contains the gate's interception logic (warnings, blocked actions).
      local proxy = { rows = rows, update = function() end, game = self.game }
      decorate(proxy)
      self.betterOptionsGate = proxy
    end
    state.enter = function(self)
      originalEnter(self)
      self.betterFocus = "left"
      self.betterCategory = "ALL"
      self.betterModIndex, self.betterModScroll = 1, 1
      self.betterProfileIndex = 1
      self.betterActionIndex = 1
      self.betterFullScroll = 1
      self.betterOptionsGate = nil
      self.betterUpperFlash = false
      self.betterUpperBlinkElapsed = 0
      self.marquee = 0
      self.footerMarquee = 0
    end
    return state
  end

  BetterModManagerCandidate.registerOptionsHeader = function(modId, hook)
    registeredOptionsHeaders[tostring(modId)] = hook
  end

  return BetterModManagerCandidate
end
