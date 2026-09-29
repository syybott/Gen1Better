-- Internal BetterBattle module. Battler text, status exposure, caught/gender/shiny/storage indicators, and their private caches.
-- Loaded once by better_battle_hud.lua; not a public consumer API.
return function(deps)
  local M = {}
  local Policy = assert(deps.policy)
  local Font = require("src.render.Font")
  local PaletteFX = require("src.render.PaletteFX")
  local Runtime = require("src.mods.Runtime")
  local crystalSprites = deps.compatibility.crystalSprites
  local indicators = deps.indicators
  local menuColors = deps.menuColors
  local mod = deps.mod
  local tinyFont = deps.compatibility.tinyFont or {}
  local rareEncounter

  local exposedStatuses = setmetatable({}, { __mode = "k" })

  local CAUGHT_ROW = { { hp = 1 } }

  local RED_CAUGHT_BALL = {
    "..kkk..",
    ".krrrk.",
    "krrrrrk",
    "kkkwkkk",
    "kwwwwwk",
    ".kwwwk.",
    "..kkk..",
  }

  local RED_CAUGHT_COLORS = {
    k = { 0, 0, 0 },
    r = { 224, 48, 48 },
    w = { 255, 255, 255 },
  }

  local GENDER_MOD_ID = "gender_mod"

  function M.fitName(value, pixels)
    local text = tostring(value or "")
    if Font.width(text) <= pixels then return text end
    while #text > 0 and Font.width(text .. ".") > pixels do
      text = text:sub(1, -2)
    end
    return text .. "."
  end

  local function statusText(battle, battler)
    local status = battler and (battler.shownStatus or exposedStatuses[battler])
    if not status then return nil end
    if type(battle.statusLabel) == "function" then
      local ok, label = pcall(battle.statusLabel, battle, { status = status })
      if ok and label then return tostring(label) end
    end
    return tostring(status)
  end

  function M.isCaught(battle, battler)
    if Policy.caughtIndicatorStyle() == "off" then return false end
    if battle.kind ~= "wild" then return false end
    local owned = battle.game
      and battle.game.save
      and battle.game.save.pokedex
      and battle.game.save.pokedex.owned
    local species = battler and battler.mon and battler.mon.species
    return species ~= nil and owned and owned[species] == true or false
  end

  local function drawDefaultCaughtBall(battle, x, y)
    if crystalSprites and type(crystalSprites.caughtBall) == "function" then
      local ok, image, trueColor = pcall(crystalSprites.caughtBall, battle)
      if ok and image then
        local palette = PaletteFX.effectiveColors(menuColors())
        local background = palette and palette[1] or { 255, 255, 255 }

        local shader = love.graphics.getShader()
        love.graphics.setShader()
        love.graphics.setColor(background[1] / 255, background[2] / 255, background[3] / 255, 1)
        love.graphics.rectangle("fill", x, y, 8, 8)
        love.graphics.setShader(shader)

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(image, x, y)
        if trueColor then PaletteFX.markTrueColor(x, y, 8, 8) end
        return true
      end
    end

    if type(battle.drawCaughtBall) == "function" then
      love.graphics.setColor(1, 1, 1, 1)
      battle:drawCaughtBall(x, y)
      return true
    end

    if type(battle.drawBallRow) == "function" then
      love.graphics.setColor(1, 1, 1, 1)
      battle:drawBallRow(CAUGHT_ROW, x, y, 8)
      return true
    end

    return false
  end

  function M.drawCaughtBall(battle, x, y, exact)
    if not exact then
      x = x + 54
      y = y - 1
    end
    local g = love.graphics
    local sx, sy, sw, sh = g.getScissor()
    g.setScissor(x, y, 8, 8)
    if Policy.caughtIndicatorStyle() == "red" then
      local shader = g.getShader()
      g.setShader()
      local palette = PaletteFX.effectiveColors(menuColors())
      local background = palette and palette[1] or { 255, 255, 255 }
      g.setColor(background[1] / 255, background[2] / 255, background[3] / 255, 1)
      g.rectangle("fill", x, y, 8, 8)
      for py, row in ipairs(RED_CAUGHT_BALL) do
        for px = 1, #row do
          local color = RED_CAUGHT_COLORS[row:sub(px, px)]
          if color then
            local dotX, dotY = x + px, y + py - 1
            g.setColor(color[1] / 255, color[2] / 255, color[3] / 255, 1)
            g.rectangle("fill", dotX, dotY, 1, 1)
          end
        end
      end
      g.setShader(shader)
      PaletteFX.markTrueColor(x, y, 8, 8)
    else
      drawDefaultCaughtBall(battle, x, y)
    end
    if sx then
      g.setScissor(sx, sy, sw, sh)
    else
      g.setScissor()
    end
    g.setColor(1, 1, 1, 1)
  end

  function M.drawStatus(battle, battler, levelX, y)
    local text = statusText(battle, battler)
    if not text then return end
    love.graphics.setColor(0, 0, 0, 1)
    Font.draw(text, levelX - Font.width(text) - 4, y)
  end

  function M.drawStatusAt(battle, battler, x, y)
    local text = statusText(battle, battler)
    if not text then return end
    love.graphics.setColor(0, 0, 0, 1)
    Font.draw(text, x, y)
  end

  function M.drawStatusAfterLevel(battle, battler, levelValueX, y, rightEdge)
    local text = statusText(battle, battler)
    if not text then return end
    local x = levelValueX + Font.width(tostring(battler.mon.level)) + 4
    if rightEdge then x = math.min(x, rightEdge - Font.width(text)) end
    love.graphics.setColor(0, 0, 0, 1)
    Font.draw(text, x, y)
  end

  local function drawSmallLevelL(x, y)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", x, y + 2, 2, 5)
    love.graphics.rectangle("fill", x + 2, y + 6, 2, 1)
    return 6
  end

  function M.drawLevel(battler, x, y)
    local labelWidth = drawSmallLevelL(x, y)
    love.graphics.setColor(0, 0, 0, 1)
    Font.draw(tostring(battler.mon.level), x + labelWidth, y)
  end

  function M.nameX(tx, name)
    local count = #Font.split(name or "")
    return tx * 8 + (count <= 2 and 16 or count <= 4 and 8 or 0)
  end

  function M.caughtBallX(name, x, maxNamePixels)
    local label = maxNamePixels and M.fitName(name, maxNamePixels) or tostring(name or "")
    return x + Font.width(label) + 2
  end

  local inkShader

  local function shaderForInk()
    if inkShader ~= nil then return inkShader end
    if not love.graphics.newShader then return nil end
    local ok, shader = pcall(
      love.graphics.newShader,
      [[
      vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
        vec4 pixel = Texel(tex, tc);
        return vec4(color.rgb, pixel.a * color.a);
      }
    ]]
    )
    inkShader = ok and shader or false
    return ok and shader or nil
  end

  function M.genderCompatibility(game)
    local exports = (game and game.mods and game.mods.exports)
      or (Runtime and Runtime.mods and Runtime.mods.exports)
    local api = exports and exports[GENDER_MOD_ID]
    local hud = api and api.BattleHUD
    if type(hud) ~= "table" then return nil, nil end
    return api, hud
  end

  function M.battlerGenderInfo(battle, battler)
    local api = M.genderCompatibility(battle and battle.game)
    if not (api and type(api.genderOf) == "function") then return nil, nil end
    local mon = battler and battler.mon
    if not (mon and type(mon) == "table" and mon.species) then return nil, nil end
    local okGender, gender = pcall(api.genderOf, mon)
    if not okGender then return nil, nil end
    local okSymbol, symbol = pcall(
      api.symbol or function(g) return g == "M" and "♂" or g == "F" and "♀" or "⚲" end,
      gender
    )
    if not okSymbol or type(symbol) ~= "string" or symbol == "" then return nil, nil end
    return gender, symbol, api
  end

  do
    local Stats = require("src.pokemon.Stats")
    local function drawGenderGlyph(gender, symbol, api, x, y)
      if not symbol then return end

      local state = api.state and api.state(gender)
        or (type(gender) == "table" and gender.state or gender)
      x, y = math.floor(x), math.floor(y)

      local pal = PaletteFX.effectiveColors(menuColors()) or menuColors()
      local bg = pal and pal[1] and { pal[1][1] / 255, pal[1][2] / 255, pal[1][3] / 255, 1 }
        or { 1, 1, 1, 1 }

      local color = state == "M" and { 32 / 255, 104 / 255, 224 / 255, 1 }
        or state == "F" and { 248 / 255, 72 / 255, 152 / 255, 1 }
        or { 0, 0, 0, 1 }
      if (state == "M" or state == "F") and type(api.palette) == "function" then
        local okPalette, exported = pcall(api.palette, gender)
        if okPalette and type(exported) == "table" then color = exported end
      end

      -- Fill the background with a 1-pixel bleed so the
      -- subpixel scissor expansion of the trueColor pass samples the menu
      -- paper color instead of the raw unshaded canvas white.
      love.graphics.setColor(bg[1], bg[2], bg[3], 1)
      love.graphics.rectangle("fill", x - 1, y - 1, 10, 10)

      love.graphics.push("all")
      local shader = shaderForInk()
      if shader then love.graphics.setShader(shader) end
      love.graphics.setColor(color[1] or 0, color[2] or 0, color[3] or 0, color[4] or 1)
      Font.draw(symbol, x, y)
      love.graphics.pop()

      local okP, PaletteFX = pcall(require, "src.render.PaletteFX")
      if okP and PaletteFX and PaletteFX.markTrueColor then PaletteFX.markTrueColor(x, y, 8, 8) end
    end

    M.drawBattleGender = function(battle, battler, x, y)
      local gender, symbol, api = M.battlerGenderInfo(battle, battler)
      drawGenderGlyph(gender, symbol, api, x, y)
    end

    local storedGenders = setmetatable({}, { __mode = "k" })
    local function storedGenderIcons(battle)
      local boxes = battle.game.save.boxes
      local species = battle.enemy.mon.species
      local api = M.genderCompatibility(battle.game)
      local cached = storedGenders[battle]
      if cached and cached.boxes == boxes and cached.species == species and cached.api == api then
        return cached.icons
      end
      local icons = {}
      for _, box in ipairs(boxes or {}) do
        for _, mon in ipairs(box) do
          if mon.species == species then
            local gender, symbol, owner = M.battlerGenderInfo(battle, { mon = mon })
            if symbol then
              local state = owner.state and owner.state(gender) or gender or "N"
              icons[state] = { gender = gender, symbol = symbol, api = owner }
            end
          end
        end
      end
      storedGenders[battle] = {
        boxes = boxes,
        species = species,
        api = api,
        icons = icons,
      }
      return icons
    end

    local SHINY_ICON = {
      "..g.....",
      "..g..g..",
      "ggggg.g.",
      "..g..g..",
      "..g.....",
      "......g.",
      ".....ggg",
      "......g.",
    }
    local function drawShinyIcon(x, y)
      love.graphics.push("all")
      love.graphics.setShader()
      local colors = PaletteFX.effectiveColors(menuColors()) or menuColors()
      local paper = colors and colors[1] or { 255, 255, 255 }
      love.graphics.setColor(paper[1] / 255, paper[2] / 255, paper[3] / 255, 1)
      love.graphics.rectangle("fill", x - 1, y - 1, 10, 10)
      love.graphics.setColor(1, 0.68, 0, 1)
      for row, pixels in ipairs(SHINY_ICON) do
        for column = 1, 8 do
          if pixels:sub(column, column) == "g" then
            love.graphics.rectangle("fill", x + column - 1, y + row - 1, 1, 1)
          end
        end
      end
      love.graphics.pop()
      PaletteFX.markTrueColor(x, y, 8, 8)
    end

    M.drawEnemyIndicators = function(battle, x, y, right)
      local battler = battle.enemy
      local condition = statusText(battle, battler)
      if condition then
        love.graphics.setColor(0, 0, 0, 1)
        Font.draw(condition, x, y)
        x = x + Font.width(condition) + 2
      end
      if battler.mon.shiny == true or Stats.isShiny(battler.mon.dvs) then
        drawShinyIcon(x, y)
        x = x + 10
      end
      local icons = storedGenderIcons(battle)
      for _, state in ipairs({ "M", "F", "N" }) do
        local icon = icons[state]
        if icon then
          drawGenderGlyph(icon.gender, icon.symbol, icon.api, x, y)
          x = x + 10
        end
      end
      love.graphics.setColor(0, 0, 0, 1)
      if rareEncounter(battle) then
        if type(tinyFont.draw) == "function" then
          tinyFont.draw("RARE", x, y + 1, 0)
        else
          Font.draw("RARE", x, y)
        end
      end
      if M.isCaught(battle, battler) then M.drawCaughtBall(battle, right - 8, y, true) end
    end
  end

  -- Draw-time presentation shim: while the engine paints its own HUD, expose
  -- the native level instead of the mutually-exclusive status label. The
  -- matching renderer then adds that saved status just to the left. No panel
  -- pixels are cleared or replaced, preserving the frosted background.
  function M.withNativeLevels(battle, shortenNames, draw)
    local restores = {}
    local result
    local function expose(battler, nameWidth)
      if not (battler and battler.shownStatus) then return end
      restores[#restores + 1] = {
        battler = battler,
        status = battler.shownStatus,
        name = battler.name,
      }
      exposedStatuses[battler] = battler.shownStatus
      battler.shownStatus = nil
      if nameWidth then battler.name = M.fitName(battler.name, nameWidth) end
    end

    expose(battle.enemy, shortenNames and 48 or nil)
    expose(battle.player, shortenNames and 40 or nil)

    local ok, err = pcall(function() result = draw() end)
    for i = #restores, 1, -1 do
      local item = restores[i]
      item.battler.shownStatus = item.status
      item.battler.name = item.name
      exposedStatuses[item.battler] = nil
    end
    if not ok then error(err, 0) end
    return result
  end

  function M.install() rareEncounter = indicators.install(mod, Policy.uiSetting) end

  return M
end
