-- BetterOptions presentation built from BetterModManager geometry.
return function(mod, menuColors)
  local Font = require("src.render.Font")
  local ManagerState = require("src.mods.ManagerState")
  local OptionsMenu = require("src.ui.OptionsMenu")
  local PaletteFX = require("src.render.PaletteFX")
  local Renderer = require("src.render.Renderer")
  local Runtime = require("src.mods.Runtime")
  local Screens = require("src.ui.Screens")
  local Strings = require("src.core.Strings")
  local ownerSource = assert(mod:read("better_option_row_owners.lua"))
  local RowOwners = assert(load(ownerSource,
    "@" .. mod.path .. "/better_option_row_owners.lua"))()

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
    gray(LIGHT)
    for x = -layout.height, layout.width, 16 do
      love.graphics.line(x, layout.headerH, x + layout.height, layout.footerY)
      love.graphics.line(x + layout.height, layout.headerH, x, layout.footerY)
    end
  end

  local TABS = {
    { id = "speed", label = "SPEED" },
    { id = "video", label = "VIDEO" },
    { id = "graphics", label = "GRAPHICS" },
    { id = "audio", label = "AUDIO" },
    { id = "battle", label = "BATTLE OPTIONS" },
    { id = "controls", label = "CONTROLS" },
    { id = "extras", label = "EXTRAS" },
    { id = "mods", label = "MODS" },
  }
  local CATEGORY = {}
  for _, id in ipairs({ "textSpeed", "speedOverworld", "speedMenu" }) do
    CATEGORY[id] = "speed"
  end
  for _, id in ipairs({ "uiLayout", "videoMode", "orientation",
      "faithfulRes", "screenPos", "fpsCap", "vsync", "logicClock",
      "tilt", "zoom", "voidFill" }) do
    CATEGORY[id] = "video"
  end
  for _, id in ipairs({ "colors", "uiLetterbox", "shaderfx",
      "shaderfx2", "performance" }) do
    CATEGORY[id] = "graphics"
  end
  for _, id in ipairs({ "musicVol", "sfxVol", "pikaVol",
      "musicFilter" }) do
    CATEGORY[id] = "audio"
  end
  for _, id in ipairs({ "animations", "battleStyle", "battleLayout",
      "battleFit", "battleHud", "battleBg", "ruleset" }) do
    CATEGORY[id] = "battle"
  end
  for _, id in ipairs({ "controls", "touchControls", "haptics",
      "hotbar" }) do
    CATEGORY[id] = "controls"
  end
  CATEGORY.dateFormat, CATEGORY.timeFormat = "time", "time"
  CATEGORY.mods = "mods"

  local function clamp(value, low, high)
    return math.max(low, math.min(high, value))
  end

  local function rowOwner(game, row, owners)
    local owner = owners[row]
    if owner then return owner end
    local pipelineId = type(row.id) == "string"
      and row.id:match("^pipeline:(.+)$")
    local registry = game.data and game.data.render_pipelines
    return pipelineId and registry and registry._owners
      and registry._owners[pipelineId] or nil
  end

  local function decorateEntry(screen, entry)
    local stack = screen.game.stack
    local decorate = stack and stack.gen1BetterMenusDecorateOptionRows
    if type(decorate) ~= "function" or not entry.schema then return end
    local gate = {
      rows = entry.rows, update = function() end, game = screen.game,
    }
    decorate(gate)
    entry.gate = gate
  end

  local function isModOptionsScreen(state)
    if type(state) ~= "table" or type(state.rows) ~= "table" then
      return false
    end
    if state.isModOptions or getmetatable(state) == OptionsMenu then
      return true
    end
    local id = state.screenId
    return type(id) == "string"
      and (id:match("Options$") or id:match("Settings$")) ~= nil
  end

  local function openExtraEntry(screen, entry)
    if entry.inlineChecked or entry.schema or #entry.rows ~= 1
        or type(entry.rows[1].activate) ~= "function"
        or entry.rows[1].step then return end
    entry.inlineChecked = true
    local stack = screen.game.stack
    local push = stack.push
    local opened
    stack.push = function(self, state, ...)
      if self == stack then
        if not opened and isModOptionsScreen(state) then opened = state end
        return state -- probing must not open an unrelated linked screen
      end
      return push(self, state, ...)
    end
    local ok, err = pcall(entry.rows[1].activate, screen.game)
    stack.push = push
    if not ok then error(err, 0) end
    if opened then
      entry.rows = opened.rows
      entry.inlineScreen = opened
      screen.extraRow, screen.extraRowScroll = 1, 1
    end
  end

  local BetterOptions = {}

  local function buildEntries(screen)
    local game = screen.game
    local source, owners = RowOwners.collect(Runtime.hooks, function()
      return OptionsMenu.new(game)
    end)
    local groups, byOwner, loose = {}, {}, {}
    for _, tab in ipairs(TABS) do groups[tab.id] = {} end
    groups.time = {}
    for _, row in ipairs(source.rows) do
      if row.id == "colors" then
        row.activate = function()
          if BetterOptions.openColors then
            BetterOptions.openColors(screen)
          end
        end
      end
      local category = CATEGORY[row.id]
      if category == "time" then
        groups.time[#groups.time + 1] = row
      elseif category and category ~= "mods" then
        local rows = groups[category]
        rows[#rows + 1] = row
      elseif category ~= "mods" then
        local owner = rowOwner(game, row, owners)
        if owner then
          byOwner[owner] = byOwner[owner] or {}
          byOwner[owner][#byOwner[owner] + 1] = row
        else
          loose[#loose + 1] = row
        end
      end
    end
    local extras = { { id = "time", label = "TIME", rows = groups.time } }
    local status = game.mods and game.mods.status and game.mods:status()
      or game.modStatus or {}
    local available = {}
    for _, candidate in ipairs(status.available or {}) do
      available[#available + 1] = candidate
    end
    table.sort(available, function(a, b)
      return tostring(a.name or a.id):upper()
        < tostring(b.name or b.id):upper()
    end)
    local seen = {}
    for _, candidate in ipairs(available) do
      local id = candidate.id
      seen[id] = true
      local schema = screen.manager:schemaFor(candidate)
      if type(schema) ~= "table" or #schema == 0 then schema = nil end
      local rows = {}
      if schema then
        rows = screen.manager:buildOptionRows(candidate, schema)
      end
      local schemaCount = #rows
      for _, row in ipairs(byOwner[id] or {}) do
        rows[#rows + 1] = row
      end
      if #rows > 0 then
        local entry = {
          id = id, label = candidate.name or id, rows = rows,
          schema = schema, candidate = candidate,
          hookRows = byOwner[id] or {}, schemaCount = schemaCount,
        }
        decorateEntry(screen, entry)
        extras[#extras + 1] = entry
      end
    end
    local missingOwners = {}
    for id in pairs(byOwner) do
      if not seen[id] then missingOwners[#missingOwners + 1] = id end
    end
    table.sort(missingOwners)
    for _, id in ipairs(missingOwners) do
      extras[#extras + 1] = {
        id = id, label = id, rows = byOwner[id],
      }
    end
    if #loose > 0 then
      extras[#extras + 1] = {
        id = "additional", label = "ADDITIONAL", rows = loose,
      }
    end
    screen.groups, screen.extras = groups, extras
  end

  local function capsule(rect, selected)
    gray(selected and BLACK or DARK)
    pixelRoundFill(rect.x, rect.y, rect.w, rect.h)
    gray(selected and WHITE or LIGHT)
    pixelRoundFill(rect.x + 1, rect.y + 1, rect.w - 2, rect.h - 2)
  end

  local function drawArrow(x, y, shade)
    gray(shade)
    love.graphics.polygon("fill", x, y, x + 5, y + 4, x, y + 8)
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

  local function drawHeader(screen, layout)
    gray(DARK)
    love.graphics.rectangle("fill", 0, 0, layout.width, layout.headerH)
    drawTinyText("OPTIONS", 5, 5, WHITE)
    local firstX, right = 39, layout.width - 4
    local widths, positions, total = {}, {}, 0
    for index, tab in ipairs(TABS) do
      widths[index] = math.max(32, tinyTextWidth(tab.label) + 12)
      positions[index] = total
      total = total + widths[index] + 3
    end
    local available = right - firstX
    local selectedX = positions[screen.tab]
    local selectedRight = selectedX + widths[screen.tab]
    screen.tabScroll = clamp(screen.tabScroll or 0,
      math.max(0, selectedRight - available), selectedX)
    screen.tabScroll = clamp(screen.tabScroll, 0,
      math.max(0, total - available))
    local sx, sy, sw, sh = love.graphics.getScissor()
    love.graphics.setScissor(firstX, 0, available, layout.headerH)
    for index, tab in ipairs(TABS) do
      local x = firstX + positions[index] - screen.tabScroll
      local selected = index == screen.tab
      local rect = { x = x, y = 2, w = widths[index], h = 10 }
      capsule(rect, selected)
      drawTinyCentered(tab.label, x + rect.w / 2, 5,
        rect.w - 8, selected and BLACK or DARK)
    end
    if sx then love.graphics.setScissor(sx, sy, sw, sh)
    else love.graphics.setScissor() end
  end

  local function drawRule(x, y, width)
    gray(LIGHT)
    love.graphics.rectangle("fill", x, y, width, 1)
  end

  local function rowValue(row, game)
    local value = row and row.value
    if type(value) == "function" then return value(game) end
    return value
  end

  local function drawRows(screen, panel, title, rows, selected, scroll)
    panelFrame(panel, WHITE)
    local x, width = panel.x + 8, panel.w - 16
    drawTinyText(tinyTextFit(title, width), x, panel.y + 7, BLACK)
    drawRule(x, panel.y + 17, width)
    local listY = panel.y + 24
    local visible = math.max(1,
      math.floor((panel.y + panel.h - listY - 5) / 10))
    if selected < scroll then scroll = selected end
    if selected >= scroll + visible then scroll = selected - visible + 1 end
    scroll = clamp(scroll, 1, math.max(1, #rows - visible + 1))
    for slot = 1, visible do
      local row = rows[scroll + slot - 1]
      if not row then break end
      local y = listY + (slot - 1) * 10
      local value = rowValue(row, screen.game)
      local valueWidth = value ~= nil and math.floor(width * 0.35) or 0
      if scroll + slot - 1 == selected then drawArrow(x, y, BLACK) end
      drawTinyText(tinyTextFit(row.label, width - valueWidth - 12),
        x + 10, y + 1, row.inert and LIGHT or BLACK)
      if value ~= nil then
        drawTinyRight(tostring(value), x + width, y + 1,
          valueWidth, BLACK)
      end
    end
    return scroll
  end

  local function drawExtras(screen, layout)
    local entry = screen.extras[screen.extraIndex]
    local names = {}
    for _, item in ipairs(screen.extras) do
      names[#names + 1] = { label = item.label }
    end
    local leftIndex = screen.extraFocus == "left" and screen.extraIndex or 0
    screen.extraScroll = drawRows(screen, layout.party, "EXTRAS", names,
      leftIndex, screen.extraScroll)
    local rightIndex = screen.extraFocus == "right" and screen.extraRow or 0
    screen.extraRowScroll = drawRows(screen, layout.detail,
      entry and entry.label or "OPTIONS", entry and entry.rows or {},
      rightIndex, screen.extraRowScroll)
  end

  local function drawFooter(screen, layout)
    gray(DARK)
    love.graphics.rectangle("fill", 0, layout.footerY,
      layout.width, layout.footerH)
    local inExtraOption = screen.tab == 7 and screen.extraFocus == "right"
    local entry = inExtraOption and screen.extras[screen.extraIndex]
    local row = entry and entry.rows[screen.extraRow]
    local canStep = row and type(row.step) == "function"
    local arrows = not inExtraOption or canStep
    local direction = inExtraOption and "CHANGE OPTION" or "CHANGE TAB"
    local action = screen.tab == 8 and "[A] OPEN"
      or screen.tab == 7 and "[A] SELECT" or "[A] CHANGE"
    if not arrows then action = row and row.activate and "[A] OPEN" or "[A] SELECT" end
    local labels = arrows and { direction, action, "[B] BACK" }
      or { action, "[B] BACK" }
    local gap, arrowW = 16, arrows and 16 or 0
    local stride = arrowW + (arrows and gap or 0)
    for _, label in ipairs(labels) do stride = stride + Font.width(label) + gap end
    local offset = math.floor((screen.marquee or 0) / 8) % stride
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

  local function draw(screen)
    local layout = layoutFor(screen)
    drawBackdrop(layout)
    drawHeader(screen, layout)
    if screen.tab == 7 then
      drawExtras(screen, layout)
    else
      local panel = {
        x = layout.party.x, y = layout.party.y,
        w = layout.detail.x + layout.detail.w - layout.party.x,
        h = layout.party.h,
      }
      local tab = TABS[screen.tab]
      local rows = screen.groups[tab.id]
      if screen.tab == 8 then
        rows = { { label = "OPEN MOD MANAGER" } }
      end
      screen.scroll[screen.tab] = drawRows(screen, panel, tab.label,
        rows, screen.index[screen.tab], screen.scroll[screen.tab])
    end
    drawFooter(screen, layout)
    gray(WHITE)
  end

  local function rebuildEntry(screen, entry, schemaRows)
    local rebuilt = schemaRows or screen.manager:buildOptionRows(
      entry.candidate, entry.schema)
    entry.schemaCount = #rebuilt
    for _, candidate in ipairs(entry.hookRows) do
      rebuilt[#rebuilt + 1] = candidate
    end
    entry.rows = rebuilt
    decorateEntry(screen, entry)
    screen.extraRow = clamp(screen.extraRow, 1, #rebuilt)
    screen.manager.optionRows = nil
  end

  local function activateRow(screen, row, direction)
    if not row or row.inert or (direction and not row.step) then return end
    local game = screen.game
    local entry = screen.tab == 7 and screen.extras[screen.extraIndex]
    if entry and entry.schema then
      screen.manager.cursor = screen.extraRow
      screen.manager.optionRows = nil
    end
    if entry and entry.gate then
      entry.gate.index = screen.extraRow
      if entry.gate:update() then return end
    end
    if not direction and row.activate then
      row.activate(game)
    elseif row.step then
      local changed = row.step(game, direction or 1)
      local managerRow = entry and entry.schema
        and screen.extraRow <= entry.schemaCount
      if changed and not managerRow and game.writeOptions then
        game:writeOptions()
      end
    end
    if entry and entry.schema and entry.candidate then
      rebuildEntry(screen, entry, screen.manager.optionRows)
    end
  end

  local function close(screen)
    screen.game.stack:pop()
    if screen.onCancel then screen.onCancel() end
  end

  local function update(screen)
    screen.marquee = (screen.marquee or 0) + 1
    local input = screen.game and screen.game.input
    if not input then return end
    if screen.tab == 7 and screen.manager.optionRows then
      local entry = screen.extras[screen.extraIndex]
      if entry and entry.schema then
        rebuildEntry(screen, entry, screen.manager.optionRows)
      end
    end
    if (input:wasPressed("left") or input:wasPressed("right"))
        and not (screen.tab == 7 and screen.extraFocus == "right") then
      local direction = input:wasPressed("left") and -1 or 1
      screen.tab = (screen.tab - 1 + direction + #TABS) % #TABS + 1
      screen.extraFocus = "left"
      return
    end
    if input:wasPressed("b") or input:wasPressed("start") then
      if screen.tab == 7 and screen.extraFocus == "right" then
        screen.extraFocus = "left"
      else
        close(screen)
      end
      return
    end
    if screen.tab == 7 then
      if screen.extraFocus == "left" then
        if input:wasPressed("up") then
          screen.extraIndex = screen.extraIndex > 1
            and screen.extraIndex - 1 or #screen.extras
          screen.extraRow, screen.extraRowScroll = 1, 1
          openExtraEntry(screen, screen.extras[screen.extraIndex])
        elseif input:wasPressed("down") then
          screen.extraIndex = screen.extraIndex < #screen.extras
            and screen.extraIndex + 1 or 1
          screen.extraRow, screen.extraRowScroll = 1, 1
          openExtraEntry(screen, screen.extras[screen.extraIndex])
        elseif input:wasPressed("a") then
          screen.extraFocus = "right"
        end
      else
        local rows = screen.extras[screen.extraIndex].rows
        if input:wasPressed("left") or input:wasPressed("right") then
          activateRow(screen, rows[screen.extraRow],
            input:wasPressed("left") and -1 or 1)
        elseif input:wasPressed("up") then
          screen.extraRow = screen.extraRow > 1
            and screen.extraRow - 1 or math.max(1, #rows)
        elseif input:wasPressed("down") then
          screen.extraRow = screen.extraRow < #rows
            and screen.extraRow + 1 or 1
        elseif input:wasPressed("a") then
          activateRow(screen, rows[screen.extraRow])
        end
      end
      return
    end
    if screen.tab == 8 then
      if input:wasPressed("a") then Screens.push(screen.game, "ManagerState") end
      return
    end
    local tab = TABS[screen.tab]
    local rows = screen.groups[tab.id]
    if input:wasPressed("up") then
      screen.index[screen.tab] = screen.index[screen.tab] > 1
        and screen.index[screen.tab] - 1 or math.max(1, #rows)
    elseif input:wasPressed("down") then
      screen.index[screen.tab] = screen.index[screen.tab] < #rows
        and screen.index[screen.tab] + 1 or 1
    elseif input:wasPressed("a") then
      activateRow(screen, rows[screen.index[screen.tab]])
    end
  end

  function BetterOptions.new(game, opts)
    opts = opts or {}
    local screen = {
      game = game, onCancel = opts.onCancel,
      tab = 1, tabScroll = 0, index = {}, scroll = {},
      extraIndex = 1, extraRow = 1, extraScroll = 1,
      extraRowScroll = 1, extraFocus = "left",
      manager = ManagerState.new(game),
      betterOptionsUI = true,
      isOpaque = true, holdsUIAnchors = true,
      letterboxWhite = true, BetterMenusScaleEligible = false,
    }
    for index = 1, #TABS do
      screen.index[index], screen.scroll[index] = 1, 1
    end
    buildEntries(screen)
    screen.uiSize = function() return responsiveSize() end
    screen.isWideBattleLayout = function() return false end
    screen.sgbPalettes = function(self, g)
      local layout = layoutFor(self)
      local base = type(menuColors) == "function" and menuColors(g)
        or g and g.data and PaletteFX.pal(g.data, "BLUEMON")
      if not base then return nil end
      return { { colors = base, x = 0, y = 0,
        w = layout.width, h = layout.height } }
    end
    screen.draw, screen.update = draw, update
    return screen
  end

  function BetterOptions.wrapStartItem(game, items, enabled, onError)
    for _, item in ipairs(items) do
      if tostring(item.label) == tostring(Strings("OPTION")) then
        local originalOnSelect = item.onSelect
        item.onSelect = function()
          if not enabled() then return originalOnSelect() end
          local ok, screen = pcall(BetterOptions.new, game, {
            onCancel = function() Screens.push(game, "StartMenu") end,
          })
          if ok and screen then
            game.stack:push(screen)
          else
            if onError then onError(screen) end
            originalOnSelect()
          end
        end
        break
      end
    end
  end

  BetterOptions.CATEGORY = CATEGORY
  BetterOptions.TABS = TABS
  return BetterOptions
end
