-- ModernParty presentation for Gen1BetterMenus.
--
-- PartyMenu remains the controller.  This module owns the widescreen
-- presentation, while PartyMenu continues to own selection, actions,
-- callbacks, healing, switching, and Party-owned submenu semantics.
return function(mod, genderExports, compatibility, menuColors,
    useStockOgMenuPalette, menuPaper, rawPaletteCopy)
  compatibility = compatibility or {}
  local crystalSprites = compatibility.crystalSprites
  local crystalAnimatedSprites = compatibility.crystalAnimatedSprites == true

  local Assets = require("src.render.Assets")
  local Font = require("src.render.Font")
  local Growth = require("src.pokemon.Growth")
  local PaletteFX = require("src.render.PaletteFX")
  local Party = require("src.pokemon.Party")
  local PartyMenu = require("src.ui.PartyMenu")
  local Renderer = require("src.render.Renderer")
  local Sound = require("src.core.Sound")
  local Sprites = require("src.pokemon.Sprites")
  local Status = require("src.battle.Status")
  local Stats = require("src.pokemon.Stats")
  local Strings = require("src.core.Strings")
  local Theme = require("src.ui.Theme")
  local TypeChart = require("src.battle.TypeChart")

  local SCREEN_H = 144
  local HEADER_H = 14
  local FOOTER_Y = 135
  local WHITE = 1
  local LIGHT = 170 / 255
  local DARK = 85 / 255
  local BLACK = 0

  -- This is the same type-owned frame palette used by ModernPC.  The values
  -- are presentation data; the active BetterMenus palette still owns the
  -- paper and menu shades through sgbPalettes below.
  local TYPE_BASE = {
    NORMAL = { 184, 185, 171 }, FIGHTING = { 174, 91, 75 },
    FLYING = { 117, 148, 202 }, POISON = { 161, 91, 151 },
    GROUND = { 207, 178, 98 }, ROCK = { 183, 168, 109 },
    BUG = { 175, 186, 66 }, GHOST = { 101, 104, 173 },
    FIRE = { 233, 84, 54 }, WATER = { 99, 145, 205 },
    GRASS = { 141, 194, 102 }, ELECTRIC = { 247, 205, 85 },
    PSYCHIC = { 236, 99, 145 }, PSYCHIC_TYPE = { 236, 99, 145 },
    ICE = { 147, 213, 245 }, DRAGON = { 99, 102, 173 },
    DARK = { 114, 86, 74 }, FAIRY = { 218, 176, 212 },
    STEEL = { 164, 163, 179 },
  }

  local function typeRamp(base)
    local pale = {}
    for i = 1, 3 do
      pale[i] = math.floor(base[i] + (255 - base[i]) * 0.32 + 0.5)
    end
    return {
      { 255, 255, 255 }, pale,
      { base[1], base[2], base[3] }, { 0, 0, 0 },
    }
  end

  local TYPE_PALETTES = {}
  for key, color in pairs(TYPE_BASE) do
    TYPE_PALETTES[key] = typeRamp(color)
  end

  local TYPE_ABBREVIATIONS = {
    NORMAL = "NRM", FIRE = "FIR", FLYING = "FLY", PSYCHIC = "PSY",
    PSYCHIC_TYPE = "PSY", WATER = "WTR", GROUND = "GRD",
    STEEL = "STL", POISON = "PSN", DRAGON = "DRA", FIGHTING = "FGT",
    DARK = "DRK", ICE = "ICE", ELECTRIC = "ELE", ROCK = "RCK",
    GRASS = "GRS", BUG = "BUG", GHOST = "GHO", FAIRY = "FAY",
  }

  local rawTypePalettes = setmetatable({}, { __mode = "k" })
  local battleSpriteCache = {}
  local crystalSpriteRuns = setmetatable({}, { __mode = "k" })
  local inkShader

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
    [" "] = { "000", "000", "000", "000", "000" },
  }

  local function gray(value)
    love.graphics.setColor(value, value, value, 1)
  end

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
    return tostring(text or ""):gsub("%.", ""):upper()
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

  local function drawText(text, x, y, maxWidth, shade)
    text = fitText(text, maxWidth or Font.width(tostring(text or "")))
    love.graphics.push("all")
    local shader = shaderForInk()
    if shader then
      love.graphics.setShader(shader)
      gray(shade == nil and WHITE or shade)
    else
      gray(BLACK)
    end
    Font.draw(text, math.floor(x), math.floor(y))
    love.graphics.pop()
  end

  local function drawFooterArrow(x, y, direction)
    gray(WHITE)
    if direction == "up" then
      love.graphics.polygon("fill",
        x + 4, y, x + 1, y + 3, x + 7, y + 3)
    elseif direction == "down" then
      love.graphics.polygon("fill",
        x + 1, y + 5, x + 7, y + 5, x + 4, y + 8)
    elseif direction == "right" then
      love.graphics.polygon("fill",
        x, y + 4, x + 3, y + 1, x + 3, y + 7)
    end
  end

  local function mediumTextWidth(text)
    local length = #cleanTinyText(text)
    return length > 0 and length * 5 - 1 or 0
  end

  local function mediumTextFit(text, maxWidth)
    text = cleanTinyText(text)
    local count = math.max(0, math.floor((math.floor(maxWidth or 0) + 1) / 5))
    return text:sub(1, count)
  end

  local function drawMediumText(text, x, y, shade)
    text = cleanTinyText(text)
    gray(shade == nil and BLACK or shade)
    local cursor = math.floor(x)
    y = math.floor(y)
    for character in text:gmatch(".") do
      local glyph = TINY_GLYPHS[character]
      if glyph then
        for dy = 0, 5 do
          local sourceRow = math.floor(dy * 5 / 6) + 1
          for dx = 0, 3 do
            local sourceColumn = math.floor(dx * 3 / 4) + 1
            if glyph[sourceRow]:sub(sourceColumn, sourceColumn) == "1" then
              love.graphics.rectangle("fill", cursor + dx, y + dy, 1, 1)
            end
          end
        end
      end
      cursor = cursor + 5
    end
  end

  local function drawMediumCentered(text, centerX, y, maxWidth, shade)
    text = mediumTextFit(text, maxWidth)
    drawMediumText(text, centerX - mediumTextWidth(text) / 2, y, shade)
  end

  local function chamfer(mode, x, y, width, height, cut)
    cut = math.max(1, math.min(cut or 3,
      math.floor(width / 2), math.floor(height / 2)))
    if love.graphics.polygon then
      love.graphics.polygon(mode, {
        x + cut, y, x + width - cut, y,
        x + width, y + cut, x + width, y + height - cut,
        x + width - cut, y + height, x + cut, y + height,
        x, y + height - cut, x, y + cut,
      })
    else
      love.graphics.rectangle(mode, x, y, width, height)
    end
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

  local function roundedPaletteZones(zones, colors, x, y, width, height)
    if width <= 0 or height <= 0 then return end
    zones[#zones + 1] = {
      colors = colors, x = x + 2, y = y,
      w = math.max(1, width - 4), h = height,
    }
    zones[#zones + 1] = {
      colors = colors, x = x + 1, y = y + 1,
      w = math.max(1, width - 2), h = math.max(1, height - 2),
    }
    zones[#zones + 1] = {
      colors = colors, x = x, y = y + 2,
      w = width, h = math.max(1, height - 4),
    }
  end

  local function roundedPaletteFrame(zones, border, face, rect, thickness)
    roundedPaletteZones(zones, border, rect.x, rect.y, rect.w, rect.h)
    thickness = thickness or 1
    roundedPaletteZones(zones, face,
      rect.x + thickness, rect.y + thickness,
      rect.w - thickness * 2, rect.h - thickness * 2)
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

  local function monDef(screen, mon)
    return mon and screen.game.data and screen.game.data.pokemon
      and screen.game.data.pokemon[mon.species] or {}
  end

  local function stripGenderSuffix(text)
    text = tostring(text or "")
    if not genderExports then return text end
    local plain = text:gsub("\226\153[\128\130]%s*$", "")
    if plain == text then plain = text:gsub("[♂♀]%s*$", "") end
    return plain
  end

  local function monName(screen, mon)
    local def = monDef(screen, mon)
    return stripGenderSuffix(mon
      and (mon.nickname or def.name or mon.species) or "")
  end

  local function speciesName(screen, mon)
    local def = monDef(screen, mon)
    return stripGenderSuffix(def.name or mon and mon.species or "")
  end

  local function monPalette(screen, mon)
    local def = monDef(screen, mon)
    local primary = def.types and def.types[1]
    return TYPE_PALETTES[tostring(primary or "NORMAL"):upper()]
      or PaletteFX.monPal(screen.game.data, mon and mon.species)
      or PaletteFX.pal(screen.game.data, "BLUEMON")
  end

  local function paletteForType(value)
    return TYPE_PALETTES[tostring(value or "NORMAL"):upper()]
      or TYPE_PALETTES.NORMAL
  end

  local function ownedPalette(palette)
    if type(rawPaletteCopy) ~= "function" or type(palette) ~= "table" then
      return palette
    end
    local owned = rawTypePalettes[palette]
    if not owned then
      owned = rawPaletteCopy(palette)
      rawTypePalettes[palette] = owned
    end
    return owned
  end

  local function paletteLuminance(color)
    if type(color) ~= "table" then return -math.huge end
    return (tonumber(color[1]) or 0) * 0.2126
      + (tonumber(color[2]) or 0) * 0.7152
      + (tonumber(color[3]) or 0) * 0.0722
  end

  local function lockedDataPaper(game)
    local source = type(menuColors) == "function" and menuColors(game) or nil
    local paper = type(menuPaper) == "function" and menuPaper(game) or nil
    if type(source) ~= "table" then return paper end
    local shades = {}
    for index = 1, 4 do
      if type(source[index]) == "table" then shades[#shades + 1] = source[index] end
    end
    table.sort(shades, function(a, b)
      return paletteLuminance(a) > paletteLuminance(b)
    end)
    if #shades < 4 then return paper or source end
    local locked = {
      paper and paper[1] or shades[1], shades[2], shades[3], shades[4],
    }
    return type(rawPaletteCopy) == "function" and rawPaletteCopy(locked) or locked
  end

  local function colorFromPalette(palette, shade)
    return palette and palette[shade]
  end

  local function fillTrueColorBacking(color, x, y, width, height)
    if not color then return end
    love.graphics.push("all")
    love.graphics.setColor((color[1] or 0) / 255,
      (color[2] or 0) / 255, (color[3] or 0) / 255, 1)
    love.graphics.rectangle("fill", x, y, width, height)
    love.graphics.pop()
  end

  local function animationCounter(screen)
    return tonumber(screen and screen.blink) or 0
  end

  local function selectedPartyMon(screen)
    local party = screen.party
      or (screen.game and screen.game.save and screen.game.save.party)
      or {}
    return party[screen.index]
  end

  local function isOriginalGen1Icon(screen, mon)
    local icons = screen.game.data.icons or {}
    local def = screen.game.data.pokemon[mon.species]
    local entry = (icons.bySpecies and icons.bySpecies[mon.species])
      or (def and def.icon)
    return type(entry) ~= "table"
  end

  local function iconAnimationLimit(mon)
    local maxHP = mon.stats and mon.stats.hp or 1
    local hpPixels = math.floor((mon.hp or 0) * 48 / math.max(1, maxHP))
    local speed = hpPixels >= 27 and 5 or hpPixels >= 10 and 16 or 32
    return speed * 4
  end

  local function syncGen1IconHover(screen)
    local mon = selectedPartyMon(screen)
    local key = table.concat({ tostring(screen.index), tostring(mon) }, ":")
    if screen.gen1IconHoverKey == key then return false, mon end
    screen.gen1IconHoverKey = key
    screen.gen1IconHoverCounter = 0
    screen.gen1IconHoverDone = false
    return true, mon
  end

  local function advanceGen1IconHover(screen)
    if not crystalAnimatedSprites then return end
    local changed, mon = syncGen1IconHover(screen)
    if changed or not mon or not isOriginalGen1Icon(screen, mon)
        or screen.gen1IconHoverDone then
      return
    end
    local limit = iconAnimationLimit(mon)
    screen.gen1IconHoverCounter = math.min(limit,
      (screen.gen1IconHoverCounter or 0) + 1)
    screen.gen1IconHoverDone = screen.gen1IconHoverCounter >= limit
  end

  local function limitedGen1IconAnimation(screen, mon, animate)
    if not crystalAnimatedSprites or not animate then return animate, nil end
    syncGen1IconHover(screen)
    if not isOriginalGen1Icon(screen, mon) then return animate, nil end
    local counter = tonumber(screen.gen1IconHoverCounter) or 0
    return not screen.gen1IconHoverDone, counter
  end

  local SELECTOR_ON_SECONDS = 1.100
  local SELECTOR_OFF_SECONDS = 0.550
  local SELECTOR_PERIOD_SECONDS =
    SELECTOR_ON_SECONDS + SELECTOR_OFF_SECONDS

  local function selectorVisible(screen)
    local elapsed = tonumber(screen and screen.selectorBlinkElapsed) or 0
    return elapsed % SELECTOR_PERIOD_SECONDS < SELECTOR_ON_SECONDS
  end

  local function selectorOutlineRuns(rect)
    local x, y = math.floor(rect.x), math.floor(rect.y)
    local w, h = math.floor(rect.w), math.floor(rect.h)
    return {
      { x = x + 2, y = y,         w = w - 4, h = 1 },
      { x = x + 1, y = y + 1,     w = 2,     h = 1 },
      { x = x + w - 3, y = y + 1, w = 2,     h = 1 },
      { x = x, y = y + 2,         w = 2,     h = 1 },
      { x = x + w - 2, y = y + 2, w = 2,     h = 1 },
      { x = x, y = y + 3,         w = 1,     h = h - 6 },
      { x = x + w - 1, y = y + 3, w = 1,     h = h - 6 },
      { x = x, y = y + h - 3,     w = 2,     h = 1 },
      { x = x + w - 2, y = y + h - 3, w = 2, h = 1 },
      { x = x + 1, y = y + h - 2, w = 2,     h = 1 },
      { x = x + w - 3, y = y + h - 2, w = 2, h = 1 },
      { x = x + 2, y = y + h - 1, w = w - 4, h = 1 },
    }
  end

  local function protectBlackSelector(trueColorRegions, rect)
    for _, run in ipairs(selectorOutlineRuns(rect)) do
      trueColorRegions[#trueColorRegions + 1] = run
    end
  end

  local function drawSharedIcon(screen, mon, x, y, animate, scale,
      trueColorRegions, counter)
    scale = tonumber(scale) or 1
    local originalMark = PaletteFX.markTrueColor
    PaletteFX.markTrueColor = function(rx, ry, rw, rh)
      rx, ry, rw, rh = tonumber(rx), tonumber(ry),
        tonumber(rw), tonumber(rh)
      if not (rx and ry and rw and rh and rw > 0 and rh > 0) then return end
      trueColorRegions[#trueColorRegions + 1] = {
        x = x + (rx - x) * scale,
        y = y + (ry - y) * scale,
        w = rw * scale, h = rh * scale,
      }
    end
    love.graphics.push("all")
    if scale ~= 1 then
      love.graphics.translate(x, y)
      love.graphics.scale(scale, scale)
      love.graphics.translate(-x, -y)
    end
    gray(WHITE)
    local ok, err = pcall(PartyMenu.drawIcon, screen.game, mon, x, y,
      animate, counter ~= nil and counter or animationCounter(screen))
    love.graphics.pop()
    PaletteFX.markTrueColor = originalMark
    if not ok then error(err, 0) end
  end

  local function drawTypeMatchedIcon(screen, mon, x, y, animate, scale,
      trueColorRegions, background, counter)
    local palette = ownedPalette(monPalette(screen, mon))
    local shader = palette and PaletteFX.shader()
    local target = 16 * scale
    fillTrueColorBacking(background, x, y, target, target)
    love.graphics.push("all")
    if shader then
      PaletteFX.sendColors(shader, palette)
      love.graphics.setShader(shader)
    end
    drawSharedIcon(screen, mon, x, y, animate, scale, trueColorRegions,
      counter)
    love.graphics.pop()
    trueColorRegions[#trueColorRegions + 1] = {
      x = x, y = y, w = target, h = target,
    }
  end

  local function opaqueRuns(path)
    if not path then return nil end
    local ok, data = pcall(Assets.imageData, path)
    if not ok or not data then return nil end
    local width, height = data:getDimensions()
    local runs = {}
    for y = 0, height - 1 do
      local start
      for x = 0, width - 1 do
        local _, _, _, alpha = data:getPixel(x, y)
        local opaque = (alpha or 0) > 0.01
        if opaque and not start then start = x end
        if start and (not opaque or x == width - 1) then
          local finish = opaque and x or x - 1
          runs[#runs + 1] = { x = start, y = y, w = finish - start + 1 }
          start = nil
        end
      end
    end
    return runs
  end

  local function battleSpriteFor(screen, mon)
    local path, trueColor = Sprites.path(
      screen.game.data, mon.species,
      "front", { mon = mon, kind = "battle" })
    if not path then return nil, trueColor == true, nil end

    if crystalSprites and type(crystalSprites.current) == "function" then
      local image, framePath, frameTrueColor =
        crystalSprites.current(screen, mon, path, trueColor)
      if image then
        local runs = crystalSpriteRuns[image]
        if runs == nil then
          runs = opaqueRuns(framePath) or false
          crystalSpriteRuns[image] = runs
        end
        return image, frameTrueColor == true, runs or nil
      end
    end

    local cached = battleSpriteCache[path]
    if not cached then
      local ok, image = pcall(Assets.image, path)
      cached = {
        image = ok and image or false,
        runs = opaqueRuns(path),
      }
      battleSpriteCache[path] = cached
    end

    return cached.image or nil, trueColor == true, cached.runs
  end

  local function detailFaceFor(screen, mon)
    local paper = lockedDataPaper(screen.game)
    return colorFromPalette(paper or monPalette(screen, mon), 1)
  end

  local function drawBattleSprite(screen, mon, rect, trueColorRegions)
    local image, trueColor, runs = battleSpriteFor(screen, mon)
    if not image then return end
    local width, height = image:getDimensions()
    local scale = math.min(1, rect.w / width, rect.h / height)
    local drawW, drawH = width * scale, height * scale
    local x = math.floor(rect.x + (rect.w - drawW) / 2)
    local y = math.floor(rect.y + (rect.h - drawH) / 2)
    if not (runs and runs[1]) then
      fillTrueColorBacking(detailFaceFor(screen, mon), x, y, drawW, drawH)
    end
    love.graphics.push("all")
    love.graphics.setColor(1, 1, 1, 1)
    local shader
    if not trueColor then
      local palette = PaletteFX.monPal(screen.game.data, mon.species)
        or monPalette(screen, mon)
      shader = palette and PaletteFX.shader()
      if shader then
        PaletteFX.sendColors(shader, palette)
        love.graphics.setShader(shader)
      end
    end
    love.graphics.draw(image, x, y, 0, scale, scale)
    if shader then love.graphics.setShader() end
    love.graphics.pop()
    if runs and runs[1] then
      for _, run in ipairs(runs) do
        trueColorRegions[#trueColorRegions + 1] = {
          x = x + run.x * scale, y = y + run.y * scale,
          w = math.max(1, run.w * scale), h = math.max(1, scale),
        }
      end
    else
      trueColorRegions[#trueColorRegions + 1] = {
        x = x, y = y, w = drawW, h = drawH,
      }
    end
  end

  local function hpFillColor(screen, ratio)
    if ratio >= 27 / 48 then return { 0, 189 / 255, 0 } end
    local name = ratio >= 10 / 48 and "YELLOWBAR" or "REDBAR"
    local palette = PaletteFX.pal(screen.game.data, name)
    local color = palette and palette[3] or { 0, 189, 0 }
    return { color[1] / 255, color[2] / 255, color[3] / 255 }
  end

  local function drawMeter(x, y, width, ratio, fillColor, trueColorRegions)
    width = math.max(8, math.floor(width))
    gray(BLACK)
    love.graphics.rectangle("fill", x, y, width, 1)
    love.graphics.rectangle("fill", x - 1, y + 1, 1, 3)
    love.graphics.rectangle("fill", x + width, y + 1, 1, 3)
    love.graphics.rectangle("fill", x, y + 4, width, 1)
    local fillWidth = math.floor(width * math.max(0, math.min(1, ratio)))
    if fillWidth > 0 then
      love.graphics.setColor(fillColor[1], fillColor[2], fillColor[3], 1)
      love.graphics.rectangle("fill", x, y + 2, fillWidth, 2)
      trueColorRegions[#trueColorRegions + 1] = {
        x = x, y = y + 2, w = fillWidth, h = 2,
      }
    end
  end

  local XP_FILL_COLOR = { 0.32, 0.68, 0.96 }

  local function drawVerticalMeter(x, y, width, height, ratio,
      fillColor, trueColorRegions)
    x, y = math.floor(x), math.floor(y)
    width, height = math.floor(width), math.floor(height)
    width = math.max(5, width)
    height = math.max(8, height)

    gray(BLACK)
    love.graphics.rectangle("fill", x, y, width, height)
    gray(WHITE)
    love.graphics.rectangle("fill", x + 1, y + 1,
      width - 2, height - 2)

    local clampedRatio = math.max(0, math.min(1, ratio))
    local fillHeight = math.floor((height - 2) * clampedRatio)
    if fillHeight > 0 then
      love.graphics.setColor(fillColor[1], fillColor[2],
        fillColor[3], 1)
      love.graphics.rectangle("fill",
        x + 1,
        y + height - 1 - fillHeight,
        width - 2,
        fillHeight)
      trueColorRegions[#trueColorRegions + 1] = {
        x = x + 1,
        y = y + height - 1 - fillHeight,
        w = width - 2,
        h = fillHeight,
      }
    end
  end

  local function ensurePartyMon(screen, mon)
    if mon then Stats.ensure(monDef(screen, mon), mon) end
    return mon
  end

  local function play(screen, id)
    if screen and screen.game and screen.game.data then
      Sound.play(screen.game.data, id)
    end
  end

  local function displayHP(screen, mon)
    if screen.heal and screen.heal.mon == mon then
      return math.floor(screen.heal.shown or mon.hp or 0), mon.stats.hp
    end
    return mon.hp or 0, mon.stats.hp
  end

  local function moveInfo(screen, mon, slot)
    local move = mon and mon.moves and mon.moves[slot]
    return move, move and screen.game.data.moves[move.id] or nil
  end

  local function maxMovePP(move, def)
    if not (move and def) then return 0 end
    local base = tonumber(def.pp) or 0
    return base + (move.ppUps or 0) * math.floor(base / 5)
  end

  local function moveClass(def)
    if not def then return "---" end
    if tonumber(def.power) == 0 then return "STATUS" end
    return tostring(def.category or TypeChart.category(def.type) or "---"):upper()
  end

  local function xpValues(screen, mon)
    local def = monDef(screen, mon)
    local level = math.max(1, math.min(100, tonumber(mon.level) or 1))
    local rates = screen.game.data.growth_rates
    local current = Growth.expForLevel(def.growthRate, level, rates)
    local following = level < 100
      and Growth.expForLevel(def.growthRate, level + 1, rates) or current
    local exp = tonumber(mon.exp) or current
    local ratio = level >= 100 and 1
      or math.max(0, math.min(1,
        (exp - current) / math.max(1, following - current)))
    return math.max(0, following - exp), ratio
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

  local function drawHeader(screen, layout)
    gray(DARK)
    love.graphics.rectangle("fill", 0, 0, layout.width, layout.headerH)
    local partyLabel = Strings("PARTY")
    local detailsLabel = Strings("DETAILS")
    drawText(partyLabel,
      layout.party.x + layout.party.w / 2
        - Font.width(partyLabel) / 2,
      3, layout.party.w - 8, WHITE)
    drawText(detailsLabel,
      layout.detail.x + layout.detail.w / 2
        - Font.width(detailsLabel) / 2,
      3, layout.detail.w - 8, WHITE)
  end

  local function rowRect(layout, index)
    local innerH = layout.party.h - 6
    local y1 = layout.party.y + 3 + math.floor((index - 1) * innerH / Party.MAX)
    local y2 = layout.party.y + 3 + math.floor(index * innerH / Party.MAX)
    return { x = layout.party.x + 3, y = y1,
      w = layout.party.w - 6, h = y2 - y1 }
  end

  local function drawPartyRow(screen, layout, index, mon, trueColorRegions)
    local rect = rowRect(layout, index)
    local selected = index == screen.index
    local showSelector = selected and selectorVisible(screen)
    local blank = screen.swapAnim and screen.swapAnim.blank
      and screen.swapAnim.blank[index]
    if showSelector then
      gray(BLACK)
      pixelRoundFill(rect.x, rect.y, rect.w, rect.h)
      gray(WHITE)
      pixelRoundFill(rect.x + 1, rect.y + 1, rect.w - 2, rect.h - 2)
      protectBlackSelector(trueColorRegions, rect)
    elseif mon and not blank then
      gray(DARK)
      pixelRoundFill(rect.x, rect.y, rect.w, rect.h)
      gray(WHITE)
      pixelRoundFill(rect.x + 1, rect.y + 1, rect.w - 2, rect.h - 2)
    else
      gray(DARK)
      pixelRoundFill(rect.x + 2, rect.y + 2, rect.w - 4, rect.h - 4)
      gray(WHITE)
      pixelRoundFill(rect.x + 3, rect.y + 3, rect.w - 6, rect.h - 6)
    end
    if not mon or blank then return end
    ensurePartyMon(screen, mon)
    local paper = type(menuPaper) == "function" and menuPaper(screen.game)
      or (type(menuColors) == "function" and menuColors(screen.game))
    local face = colorFromPalette(paper or monPalette(screen, mon), 1)
    local animate, counter = limitedGen1IconAnimation(screen, mon, selected)
    drawTypeMatchedIcon(screen, mon, rect.x + 3, rect.y + 1,
      animate, 1, trueColorRegions, face, counter)

    local right = rect.x + rect.w - 3
    local textX = rect.x + 22
    local level = "L" .. tostring(math.max(1, math.min(100, mon.level or 1)))
    local meterW = 6
    local meterGap = 2
    local xpBarX = right - meterW
    local hpBarX = xpBarX - meterGap - meterW
    local textRight = hpBarX - 3
    local nameW = math.max(8, textRight - textX)
    drawTinyText(tinyTextFit(monName(screen, mon), nameW),
      textX, rect.y + 4, BLACK)
    drawTinyText(level, textX, rect.y + 11, BLACK)

    if screen.tmhm or screen.evoStone then
      local able = false
      local def = monDef(screen, mon)
      if screen.tmhm then
        for _, move in ipairs(def.tmhm or {}) do
          if move == screen.tmhm.move then able = true break end
        end
      else
        for _, evo in ipairs(def.evolutions or {}) do
          if evo.method == "ITEM" and evo.item == screen.evoStone then
            able = true break
          end
        end
      end
      drawTinyRight(able and "ABLE" or "NOT ABLE", right, rect.y + 9, right - textX, BLACK)
      return
    end

    local hp, maxHP = displayHP(screen, mon)
    local hpRatio = hp / math.max(1, maxHP)
    local _, xpRatio = xpValues(screen, mon)
    local meterY = rect.y + 3
    local meterH = math.max(8, rect.h - 6)
    drawVerticalMeter(hpBarX, meterY, meterW, meterH,
      hpRatio, hpFillColor(screen, hpRatio), trueColorRegions)
    drawVerticalMeter(xpBarX, meterY, meterW, meterH,
      xpRatio, XP_FILL_COLOR, trueColorRegions)

    if (screen.swapFrom == index or screen.softboiledFrom == index)
        and Theme.cursorHollow then
      gray(BLACK)
      Font.drawCode(Theme.cursorHollow, rect.x + 1, rect.y + 5)
    end
  end

  local function typeAbbreviation(value)
    local key = tostring(value or ""):upper()
    return TYPE_ABBREVIATIONS[key] or key:sub(1, 3)
  end

  local function drawGenderGlyph(mon, x, y, background, trueColorRegions)
    if not (genderExports
        and type(genderExports.genderOf) == "function"
        and type(genderExports.symbol) == "function") then
      return 0
    end

    local okGender, gender = pcall(genderExports.genderOf, mon)
    if not okGender then
      return 0
    end

    local okSymbol, symbol = pcall(genderExports.symbol, gender)
    if not okSymbol or type(symbol) ~= "string" or symbol == "" then
      return 0
    end

    local color = { 0, 0, 0, 1 }
    if type(genderExports.palette) == "function" then
      local okPalette, exported = pcall(genderExports.palette, gender)
      if okPalette and type(exported) == "table" then
        color = exported
      end
    end

    x, y = math.floor(x), math.floor(y)
    fillTrueColorBacking(background, x, y, 8, 8)

    love.graphics.push("all")
    local shader = shaderForInk()
    if shader then
      love.graphics.setShader(shader)
    end
    love.graphics.setColor(
      color[1] or 0,
      color[2] or 0,
      color[3] or 0,
      color[4] or 1
    )
    Font.draw(symbol, x, y)
    love.graphics.pop()

    trueColorRegions[#trueColorRegions + 1] = {
      x = x,
      y = y,
      w = 8,
      h = 8,
    }

    return 9
  end

  local function genderWidth(mon)
    if not (genderExports
        and type(genderExports.genderOf) == "function"
        and type(genderExports.symbol) == "function") then
      return 0
    end

    local okGender, gender = pcall(genderExports.genderOf, mon)
    if not okGender then
      return 0
    end

    local okSymbol, symbol = pcall(genderExports.symbol, gender)
    return okSymbol
      and type(symbol) == "string"
      and symbol ~= ""
      and 9
      or 0
  end

  local function identityBadges(panel, types, hasGender)
    local split = math.floor(panel.w * 0.52)
    local left = panel.x + 5
    local identityW = math.max(55, split - 8)
    local entries = {}
    local totalW = 0

    for _, value in ipairs(types or {}) do
      local text = typeAbbreviation(value)
      local width = tinyTextWidth(text) + 6
      if width >= 14 then
        entries[#entries + 1] = {
          value = value,
          text = text,
          width = width,
        }
        totalW = totalW + width
      end
    end

    totalW = totalW + math.max(0, #entries - 1)
    local right = left + identityW - 2
    local x = right - totalW
    local badges = {}
    for _, entry in ipairs(entries) do
      badges[#badges + 1] = {
        value = entry.value,
        text = entry.text,
        rect = { x = x, y = panel.y + 3,
          w = entry.width, h = 9 },
        palette = ownedPalette(paletteForType(entry.value)),
      }
      x = x + entry.width + 1
    end

    local genderPosition
    if hasGender then
      local firstRowLeft = right
      for _, badge in ipairs(badges) do
        if badge.rect.y == panel.y + 3 then
          firstRowLeft = math.min(firstRowLeft, badge.rect.x)
        end
      end

      genderPosition = {
        x = firstRowLeft - 9,
        y = panel.y + 3,
      }
    end

    return badges, genderPosition
  end

  local function drawTypeBadges(badges)
    for _, badge in ipairs(badges) do
      local rect = badge.rect
      gray(DARK)
      pixelRoundFill(rect.x, rect.y, rect.w, rect.h)
      gray(WHITE)
      pixelRoundFill(rect.x + 1, rect.y + 1, rect.w - 2, rect.h - 2)
      drawTinyCentered(badge.text, rect.x + rect.w / 2,
        rect.y + math.floor((rect.h - 5) / 2),
        rect.w - 2, BLACK)
    end
  end

  local function drawStats(screen, mon, rect, trueColorRegions)
    local stats = mon.stats or {}
    local rows = {
      { "ATTACK", stats.attack or 0 }, { "DEFENSE", stats.defense or 0 },
      { "SPEED", stats.speed or 0 }, { "SPECIAL", stats.special or 0 },
    }
    for index, row in ipairs(rows) do
      local y = rect.y + (index - 1) * 8
      drawTinyText(row[1], rect.x, y, BLACK)
      drawTinyRight(row[2], rect.x + rect.w, y, tinyTextWidth(row[2]), BLACK)
    end
    local hp, maxHP = displayHP(screen, mon)
    local hpText = tostring(hp) .. "/" .. tostring(maxHP)
    drawTinyText("HP", rect.x, rect.y + 36, BLACK)
    drawTinyRight(hpText, rect.x + rect.w, rect.y + 36,
      tinyTextWidth(hpText), BLACK)
    local xpNext = xpValues(screen, mon)
    drawTinyText("XP TO LVL", rect.x, rect.y + 44, BLACK)
    drawTinyRight(xpNext, rect.x + rect.w, rect.y + 44,
      tinyTextWidth(xpNext), BLACK)
  end

  local function dashboardRight(panel)
    local split = math.floor(panel.w * 0.52)
    return {
      x = panel.x + split + 1,
      y = panel.y + 5,
      w = math.max(55, panel.w - split - 6),
      h = panel.h - 10,
    }
  end

  local function drawDashboardSeparator(panel)
    local split = math.floor(panel.w * 0.52)
    gray(DARK)
    love.graphics.rectangle(
      "fill",
      panel.x + split - 2,
      panel.y + 8,
      1,
      math.max(1, panel.h - 16)
    )
  end

  local function moveRowRect(panel, slot)
    local right = dashboardRight(panel)
    return {
      x = right.x,
      y = right.y + 10 + (slot - 1) * 11,
      w = right.w,
      h = 10,
    }
  end

  local function moveDetailsRect(panel)
    local right = dashboardRight(panel)
    return {
      x = right.x,
      y = right.y + 60,
      w = right.w,
      h = 55,
    }
  end

  local function moveBorderPalette(screen, mon, slot)
    local move, def = moveInfo(screen, mon, slot)
    return def and ownedPalette(paletteForType(def.type)) or nil
  end

  local function drawMoveRow(screen, mon, slot, rect, selected)
    if selected then
      gray(BLACK)
      pixelRoundFill(rect.x, rect.y, rect.w, rect.h)
      gray(WHITE)
      pixelRoundFill(rect.x + 1, rect.y + 1, rect.w - 2, rect.h - 2)
    else
      gray(DARK)
      pixelRoundFill(rect.x, rect.y, rect.w, rect.h)
      gray(WHITE)
      pixelRoundFill(rect.x + 1, rect.y + 1, rect.w - 2, rect.h - 2)
    end
    local move, def = moveInfo(screen, mon, slot)
    local name = move and def and def.name or "NONE"
    local pp = move and def and ((move.pp or 0) .. "/" .. maxMovePP(move, def))
      or "--/--"
    local left = rect.x + (selected and 9 or 5)
    if selected then
      gray(BLACK)
      if love.graphics.polygon then
        love.graphics.polygon("fill", {
          rect.x + 3, rect.y + 3,
          rect.x + 7, rect.y + rect.h / 2,
          rect.x + 3, rect.y + rect.h - 3,
        })
      end
    end
    local ppWidth = tinyTextWidth(pp)
    drawTinyText(tinyTextFit(name,
      rect.w - ppWidth - (left - rect.x) - 8), left, rect.y + 2, BLACK)
    drawTinyRight(pp, rect.x + rect.w - 4, rect.y + 2, ppWidth, BLACK)
  end

  local function drawMoveDetails(screen, mon, slot, rect)
    gray(DARK)
    pixelRoundFill(rect.x, rect.y, rect.w, rect.h)
    gray(WHITE)
    pixelRoundFill(rect.x + 2, rect.y + 2, rect.w - 4, rect.h - 4)
    local move, def = moveInfo(screen, mon, slot)
    if not (move and def) then
      drawTinyCentered("NO MOVE SELECTED", rect.x + rect.w / 2,
        rect.y + 22, rect.w - 8, BLACK)
      return
    end
    drawTinyCentered(
      tinyTextFit(def.name or move.id, rect.w - 8),
      rect.x + rect.w / 2,
      rect.y + 4,
      rect.w - 8,
      BLACK
    )
    local power = tonumber(def.power)
    local accuracy = tonumber(def.accuracy)
    local rows = {
      { "TYPE", tostring(def.type or "---") },
      { "CLASS", moveClass(def) },
      { "POWER", power and power > 0 and tostring(math.floor(power)) or "---" },
      { "ACCURACY", accuracy and tostring(math.floor(accuracy)) .. "%" or "---" },
      { "PP", tostring(move.pp or 0) .. "/" .. maxMovePP(move, def) },
    }
    for index, row in ipairs(rows) do
      local y = rect.y + 14 + (index - 1) * 8
      drawTinyText(row[1], rect.x + 4, y, BLACK)
      drawTinyRight(row[2], rect.x + rect.w - 4, y,
        tinyTextWidth(row[2]), BLACK)
    end
  end

  local function drawDashboard(screen, layout, mon, trueColorRegions)
    local panel = layout.detail
    panelFrame(panel, WHITE)
    if not mon then
      drawTinyCentered("EMPTY", panel.x + panel.w / 2,
        panel.y + 50, panel.w - 8, BLACK)
      return
    end
    ensurePartyMon(screen, mon)
    local split = math.floor(panel.w * 0.52)
    local left = { x = panel.x + 5, y = panel.y + 5,
      w = math.max(55, split - 8), h = panel.h - 10 }
    local right = dashboardRight(panel)

    drawDashboardSeparator(panel)

    local statusLabel = mon.status
      and Status.hudLabelFor(screen.game.data.statuses, mon.status)
      or "OK"
    drawTinyText(statusLabel, panel.x + 4, panel.y + 5, BLACK)

    local identity = { x = left.x, y = left.y + 8,
      w = left.w, h = 56 }
    local spriteW = math.min(56, identity.w)
    drawBattleSprite(screen, mon, {
      x = identity.x + math.floor((identity.w - spriteW) / 2),
      y = identity.y,
      w = spriteW,
      h = 56,
    }, trueColorRegions)
    local badges, genderPosition = identityBadges(
      panel,
      monDef(screen, mon).types or {},
      genderWidth(mon) > 0
    )
    drawTypeBadges(badges)
    if genderPosition then
      drawGenderGlyph(mon, genderPosition.x, genderPosition.y,
        detailFaceFor(screen, mon), trueColorRegions)
    end
    drawStats(screen, mon, { x = left.x, y = panel.y + 71,
      w = left.w - 2, h = 68 }, trueColorRegions)

    drawTinyCentered("MOVES", right.x + right.w / 2, right.y,
      right.w, BLACK)
    for slot = 1, 4 do
      drawMoveRow(screen, mon, slot, moveRowRect(panel, slot),
        screen.modernPartyFocus == "moves"
          and slot == (screen.modernPartyMoveSlot or 1))
    end
    drawMoveDetails(screen, mon, screen.modernPartyMoveSlot or 1,
      moveDetailsRect(panel))
  end

  local SUBMENU_PAGE = 6

  local function submenuScroll(screen)
    local total = #(screen.subItems or {})
    local maxScroll = math.max(0, total - SUBMENU_PAGE)
    return math.max(0, math.min(screen.gen1BetterMenusSubScroll or 0, maxScroll))
  end

  local function drawPartySubmenu(screen, layout)
    if not screen.submenu then return nil end
    local total = #(screen.subItems or {})
    local visible = math.min(total, SUBMENU_PAGE)
    local scroll = submenuScroll(screen)
    local rowH = 12
    local width = math.min(136, math.max(96, math.floor(layout.width * 0.42)))
    local height = visible * rowH + 6
    local x = layout.width - width - 4
    local y = math.max(17, layout.footerY - height - 2)
    panelFrame({ x = x, y = y, w = width, h = height }, WHITE)
    for slot = 1, visible do
      local entry = screen.subItems[scroll + slot]
      if entry then
        local rowY = y + 3 + (slot - 1) * rowH
        local selected = screen.subIndex == scroll + slot
        if selected then
          gray(BLACK)
          chamfer("fill", x + 3, rowY, width - 6, rowH - 1, 2)
        end
        drawText(entry.label or "", x + 12, rowY + 2,
          width - 18, selected and WHITE or BLACK)
        if selected then
          gray(WHITE)
          love.graphics.rectangle("fill", x + 6, rowY + 4, 3, 3)
        end
      end
    end
    return { x = x - 2, y = y - 2, w = width + 4, h = height + 4 }
  end

  local function footerMessage(screen)
    if screen.status then return tostring(screen.status) end
    if screen.submenu then return "UP/DOWN CHOOSE   A OK   B BACK" end
    if screen.modernPartyFocus == "moves" then return nil end
    if screen.itemUse or screen.tmhm or screen.evoStone or screen.forceSwitch then
      local message = type(screen.bottomMessage) == "function"
        and screen:bottomMessage() or nil
      return message and tostring(message) or "UP/DOWN SELECT   A OK   B BACK"
    end
    return nil
  end

  local function drawPartyFooterMarquee(screen, layout)
    local labels = {
      Strings("PARTY"),
      Strings("[A] SELECT"),
      Strings("[B] BACK"),
      Strings("MOVES"),
      Strings("[START] DETAILS"),
    }
    local arrowW = 8
    local gap = 16
    local widths = {
      arrowW + Font.width(labels[1]),
      Font.width(labels[2]),
      Font.width(labels[3]),
      arrowW + Font.width(labels[4]),
      Font.width(labels[5]),
    }
    local stride = gap * 5
    for _, width in ipairs(widths) do stride = stride + width end
    local offset = math.floor((screen.marquee or 0) / 8) % stride
    local sx, sy, sw, sh = love.graphics.getScissor()
    love.graphics.setScissor(4, layout.footerY,
      layout.width - 8, layout.footerH)

    local x = 4 - offset
    while x < layout.width do
      drawFooterArrow(x, layout.footerY + 1, "up")
      drawFooterArrow(x, layout.footerY + 1, "down")
      drawText(labels[1], x + arrowW, layout.footerY + 1,
        Font.width(labels[1]), WHITE)
      x = x + widths[1] + gap
      drawText(labels[2], x, layout.footerY + 1,
        widths[2], WHITE)
      x = x + widths[2] + gap
      drawText(labels[3], x, layout.footerY + 1,
        widths[3], WHITE)
      x = x + widths[3] + gap
      drawFooterArrow(x, layout.footerY + 1, "right")
      drawText(labels[4], x + arrowW, layout.footerY + 1,
        Font.width(labels[4]), WHITE)
      x = x + widths[4] + gap
      drawText(labels[5], x, layout.footerY + 1,
        widths[5], WHITE)
      x = x + widths[5] + gap
    end

    if sx then love.graphics.setScissor(sx, sy, sw, sh)
    else love.graphics.setScissor() end
  end

  local function drawFooterMessageMarquee(screen, layout, message)
    local footerW = layout.width - 8
    local textW = Font.width(message)
    local marqueeEnabled = mod and mod.options
      and mod.options:get("marquee_text") ~= false
    if textW <= footerW or not marqueeEnabled then
      local fitted = fitText(message, footerW)
      drawText(fitted,
        layout.width / 2 - Font.width(fitted) / 2,
        layout.footerY + 1, footerW, WHITE)
      return
    end
    local gap = 24
    local stride = textW + gap
    local offset = math.floor((screen.marquee or 0) / 8) % stride
    local sx, sy, sw, sh = love.graphics.getScissor()
    love.graphics.setScissor(4, layout.footerY, footerW, layout.footerH)
    local x = 4 - offset
    while x < layout.width do
      drawText(message, x, layout.footerY + 1, textW, WHITE)
      x = x + stride
    end
    if sx then love.graphics.setScissor(sx, sy, sw, sh)
    else love.graphics.setScissor() end
  end

  local function drawFooter(screen, layout)
    gray(DARK)
    love.graphics.rectangle("fill", 0, layout.footerY,
      layout.width, layout.footerH)
    local message = footerMessage(screen)
    if message then
      drawFooterMessageMarquee(screen, layout, message)
    else
      drawPartyFooterMarquee(screen, layout)
    end
  end

  local function markTrueColorOutside(rect, cutout)
    if not cutout then
      PaletteFX.markTrueColor(rect.x, rect.y, rect.w, rect.h)
      return
    end
    local x1, y1, x2, y2 = rect.x, rect.y, rect.x + rect.w, rect.y + rect.h
    local cx1, cy1 = cutout.x, cutout.y
    local cx2, cy2 = cx1 + cutout.w, cy1 + cutout.h
    local ix1, iy1 = math.max(x1, cx1), math.max(y1, cy1)
    local ix2, iy2 = math.min(x2, cx2), math.min(y2, cy2)
    if ix1 >= ix2 or iy1 >= iy2 then
      PaletteFX.markTrueColor(x1, y1, rect.w, rect.h)
      return
    end
    if y1 < iy1 then PaletteFX.markTrueColor(x1, y1, rect.w, iy1 - y1) end
    if iy2 < y2 then PaletteFX.markTrueColor(x1, iy2, rect.w, y2 - iy2) end
    if x1 < ix1 then PaletteFX.markTrueColor(x1, iy1, ix1 - x1, iy2 - iy1) end
    if ix2 < x2 then PaletteFX.markTrueColor(ix2, iy1, x2 - ix2, iy2 - iy1) end
  end

  local function draw(screen)
    local layout = layoutFor(screen)
    local trueColorRegions = {}
    drawBackdrop(layout)
    drawHeader(screen, layout)
    panelFrame(layout.party, WHITE)
    local party = screen.party or screen.game.save.party or {}
    for index = 1, Party.MAX do
      drawPartyRow(screen, layout, index, party[index], trueColorRegions)
    end
    drawDashboard(screen, layout, ensurePartyMon(screen, party[screen.index]),
      trueColorRegions)
    local cutout = drawPartySubmenu(screen, layout)
    drawFooter(screen, layout)
    if not (type(useStockOgMenuPalette) == "function"
        and useStockOgMenuPalette(screen.game)) then
      for _, rect in ipairs(trueColorRegions) do
        markTrueColorOutside(rect, cutout)
      end
    end
    gray(WHITE)
  end

  local function sgbPalettes(screen, game)
    local data = game and game.data
    if not data then return nil end
    local layout = layoutFor(screen)
    local base = type(menuColors) == "function" and menuColors(game)
      or PaletteFX.pal(data, "BLUEMON")
    if not base then return nil end
    if type(useStockOgMenuPalette) == "function"
        and useStockOgMenuPalette(game) then
      return {{ colors = base, x = 0, y = 0,
        w = layout.width, h = layout.height }}
    end
    local paper = type(menuPaper) == "function" and menuPaper(game) or base
    local dataPaper = lockedDataPaper(game) or paper
    local zones = {{ colors = base, x = 0, y = 0,
      w = layout.width, h = layout.height }}
    zones[#zones + 1] = { colors = base, x = 0, y = 0,
      w = layout.width, h = layout.headerH }
    zones[#zones + 1] = { colors = base, x = 0, y = layout.footerY,
      w = layout.width, h = layout.footerH }
    roundedPaletteFrame(zones, base, dataPaper, layout.party, 2)
    local party = screen.party or game.save.party or {}
    for index = 1, Party.MAX do
      local mon = party[index]
      local rect = rowRect(layout, index)
      if mon then
        roundedPaletteFrame(zones, ownedPalette(monPalette(screen, mon)),
          dataPaper, rect, 1)
      else
        roundedPaletteFrame(zones, base, dataPaper,
          { x = rect.x + 2, y = rect.y + 2,
            w = rect.w - 4, h = rect.h - 4 }, 1)
      end
    end
    local mon = party[screen.index]
    roundedPaletteFrame(zones, base,
      dataPaper, layout.detail, 2)
    if mon then
      local badges = identityBadges(layout.detail, monDef(screen, mon).types or {})
      for _, badge in ipairs(badges) do
        roundedPaletteFrame(zones, badge.palette, dataPaper, badge.rect, 1)
      end

      for slot = 1, 4 do
        local border = moveBorderPalette(screen, mon, slot)
        if border then
          roundedPaletteFrame(zones, border, dataPaper,
            moveRowRect(layout.detail, slot), 1)
        end
      end

      local detailBorder = moveBorderPalette(
        screen, mon, screen.modernPartyMoveSlot or 1)
      roundedPaletteFrame(zones, detailBorder or base, dataPaper,
        moveDetailsRect(layout.detail), 2)
    end
    if screen.submenu then
      local visible = math.min(#(screen.subItems or {}), SUBMENU_PAGE)
      local width = math.min(136, math.max(96, math.floor(layout.width * 0.42)))
      local height = visible * 12 + 6
      zones[#zones + 1] = { colors = base,
        x = layout.width - width - 6,
        y = math.max(17, layout.footerY - height - 4),
        w = width + 4, h = height + 4 }
    end
    return zones
  end

  local function canFocusMoves(screen)
    return not screen.battle and not screen.itemUse and not screen.tmhm
      and not screen.evoStone and not screen.pickOnly and not screen.forceSwitch
  end

  local function removeStatsAction(screen)
    if not screen.submenu or type(screen.subItems) ~= "table" then
      return
    end

    local filtered = {}
    local changed = false
    for _, item in ipairs(screen.subItems) do
      if item.action == "stats" then
        changed = true
      else
        filtered[#filtered + 1] = item
      end
    end

    if changed then
      screen.subItems = filtered
      screen.subIndex = math.max(1, math.min(
        screen.subIndex or 1, #filtered))
    end
  end

  local function wrapUpdate(screen)
    local original = screen.update
    screen.modernPartyFocus = "party"
    screen.modernPartyMoveSlot = 1
    screen.modernPartyPreviousIndex = screen.index
    screen.gen1IconHoverCounter = 0
    screen.gen1IconHoverDone = false
    screen.update = function(self, dt)
      advanceGen1IconHover(self)
      local elapsed = tonumber(dt) or (1 / 60)
      if crystalSprites and type(crystalSprites.update) == "function" then
        crystalSprites.update(self, elapsed)
      end
      self.selectorBlinkElapsed =
        ((self.selectorBlinkElapsed or 0) + elapsed)
          % SELECTOR_PERIOD_SECONDS
      self.marquee = (self.marquee or 0) + 1
      local input = self.game and self.game.input
      if not input or self.submenu or self.heal or self.swapAnim
          or not canFocusMoves(self) then
        local result = original(self, dt)
        removeStatsAction(self)
        if self.index ~= self.modernPartyPreviousIndex then
          self.modernPartyPreviousIndex = self.index
          self.modernPartyMoveSlot = 1
          self.selectorBlinkElapsed = 0
        end
        return result
      end
      if self.modernPartyFocus == "moves" then
        if input:wasPressed("up") then
          self.modernPartyMoveSlot = self.modernPartyMoveSlot > 1
            and self.modernPartyMoveSlot - 1 or 4
          play(self, "Press_AB")
          return
        elseif input:wasPressed("down") then
          self.modernPartyMoveSlot = self.modernPartyMoveSlot < 4
            and self.modernPartyMoveSlot + 1 or 1
          play(self, "Press_AB")
          return
        elseif input:wasPressed("left") or input:wasPressed("b") then
          self.modernPartyFocus = "party"
          play(self, "Press_AB")
          return
        end
        local result = original(self, dt)
        removeStatsAction(self)
        if self.index ~= self.modernPartyPreviousIndex then
          self.modernPartyPreviousIndex = self.index
          self.modernPartyMoveSlot = 1
          self.selectorBlinkElapsed = 0
        end
        return result
      end
      if input:wasPressed("right") then
        self.modernPartyFocus = "moves"
        play(self, "Press_AB")
        return
      end
      local result = original(self, dt)
      removeStatsAction(self)
      if self.index ~= self.modernPartyPreviousIndex then
        self.modernPartyPreviousIndex = self.index
        self.modernPartyMoveSlot = 1
        self.selectorBlinkElapsed = 0
      end
      return result
    end
  end

  local record = {}
  function record.new(game, opts)
    local state = PartyMenu.new(game, opts or {})
    state.modernPartyUI = true
    state.selectorBlinkElapsed = 0
    state.marquee = 0
    state.uiSize = function() return responsiveSize() end
    state.holdsUIAnchors = true
    state.isOpaque = true
    state.letterboxWhite = true
    state.sgbPalettes = sgbPalettes
    state.draw = draw
    wrapUpdate(state)
    return state
  end

  return record
end
