-- Internal BetterBattle module. Inverse cleanup, isolated provider HUD palettes, and battle palette-zone integration.
-- Loaded once by better_battle_hud.lua; not a public consumer API.
return function(deps)
  local M = {}
  local Meters = assert(deps.meters)
  local NativePanels = assert(deps.native_panels)
  local Policy = assert(deps.policy)
  local BattleState = require("src.battle.BattleState")
  local PaletteFX = require("src.render.PaletteFX")
  local menuColors = deps.menuColors
  local mod = deps.mod

  local function clearInverseArtifacts(rects)
    if not Policy.inversePalette() then return end
    local colors = PaletteFX.effectiveColors(menuColors())
    local c = colors and colors[1] or { 28, 51, 79 }
    local r, g, b, a = love.graphics.getColor()
    local shader = love.graphics.getShader()
    love.graphics.setShader()
    love.graphics.setColor(c[1] / 255, c[2] / 255, c[3] / 255, 1)
    for _, rect in ipairs(rects) do
      love.graphics.rectangle("fill", rect[1], rect[2], rect[3], rect[4])
      PaletteFX.markTrueColor(rect[1], rect[2], rect[3], rect[4])
    end
    love.graphics.setShader(shader)
    love.graphics.setColor(r, g, b, a)
  end

  -- Staged battle providers publish their HUD as a separate transparent
  -- texture. Palette that texture in isolation so BetterMenus can cover the
  -- provider's panels without ever sending the battle scene or its sprites
  -- through the menu shader. Re-seat native HP fills afterward so their
  -- semantic green/yellow/red colors remain intact.
  local providerPaletteLayers = setmetatable({}, { __mode = "k" })

  local providerPaletteFailures = {}

  function M.paletteProviderHudTexture(battle, layer, companionId)
    if not (layer and menuColors) then return layer end
    local g = love.graphics
    if
      type(g.newCanvas) ~= "function"
      or type(g.getCanvas) ~= "function"
      or type(g.setCanvas) ~= "function"
      or type(g.clear) ~= "function"
      or type(g.draw) ~= "function"
      or type(layer.getDimensions) ~= "function"
    then
      return layer
    end

    local shader = PaletteFX.shader()
    if not shader then return layer end
    local okSize, width, height = pcall(layer.getDimensions, layer)
    if
      not okSize
      or type(width) ~= "number"
      or type(height) ~= "number"
      or width <= 0
      or height <= 0
    then
      return layer
    end

    local record = providerPaletteLayers[layer]
    if not record or record.width ~= width or record.height ~= height then
      local okCanvas, canvas = pcall(g.newCanvas, width, height)
      if not okCanvas or not canvas then return layer end
      if type(canvas.setFilter) == "function" then canvas:setFilter("nearest", "nearest") end
      record = { canvas = canvas, width = width, height = height }
      providerPaletteLayers[layer] = record
    end

    local previous = g.getCanvas()
    local pushed = false
    local ok, err = xpcall(function()
      g.push("all")
      pushed = true
      g.setCanvas(record.canvas)
      g.clear(0, 0, 0, 0)
      if type(g.setBlendMode) == "function" then g.setBlendMode("replace", "premultiplied") end
      g.setColor(1, 1, 1, 1)
      PaletteFX.sendColors(shader, menuColors())
      g.setShader(shader)
      g.draw(layer, 0, 0)
      g.setShader()
      if type(g.setBlendMode) == "function" then g.setBlendMode("alpha") end
      NativePanels.drawStagedSemanticHpFills(battle)
      g.pop()
      pushed = false
      if previous then
        g.setCanvas(previous)
      else
        g.setCanvas()
      end
    end, function(message) return tostring(message) end)

    if pushed then pcall(g.pop) end
    if previous then
      g.setCanvas(previous)
    else
      g.setCanvas()
    end
    if not ok then
      local id = tostring(companionId or "battle provider")
      if not providerPaletteFailures[id] then
        providerPaletteFailures[id] = true
        mod.log:warn("could not palette %s HUD texture: %s", id, err)
      end
      return layer
    end
    return record.canvas
  end

  function M.install()
    local originalBattlePalettes = BattleState.sgbPalettes

    BattleState.sgbPalettes = function(battle, ...)
      local zones = originalBattlePalettes(battle, ...) or {}
      -- BetterBattle supplies its palette directly to its HUD-canvas blit.
      -- Its atlas rectangles must never recolor the main Pokémon canvas.
      if Policy.setting(battle) then return zones end

      if not (battle and battle:wideLayout() and menuColors) then return zones end

      local palette = menuColors()
      local battleMode = Policy.effectiveBattleMode(battle)
      local betterBattle = Policy.setting(battle)

      -- BetterBattle owns five detached regions in the extended HUD canvas. The
      -- stock/provider regions remain untouched here; their palette coverage is
      -- supplied by the renderer hook below.
      if betterBattle and battle:extendedHUD() then
        zones[#zones + 1] = PaletteFX.zone(palette, 0, 0, 15, 3)
        zones[#zones + 1] = PaletteFX.zone(palette, 22, 0, 37, 3)
        zones[#zones + 1] = PaletteFX.zone(palette, 0, 4, 16, 9)
        zones[#zones + 1] = PaletteFX.zone(palette, 21, 4, 37, 7)
        zones[#zones + 1] = PaletteFX.zone(palette, 0, 10, 37, 17)
      elseif not battle:extendedHUD() then
        if Policy.enemyVisible(battle) then
          zones[#zones + 1] = PaletteFX.zone(palette, 0, 0, 15, 3)
        end
        if Policy.playerVisible(battle) then
          zones[#zones + 1] = PaletteFX.zone(palette, 23, 7, 37, 12)
        end
      end

      -- The HUD panels use the menu palette, but HP and EXP fills are semantic
      -- colors. Re-blit only those two-pixel fills without the shade shader so
      -- inverse mode cannot turn green/blue into a menu shade. Keeping the
      -- opt-out this narrow also lets the custom XP X follow the menu palette.
      local function trueColorFill(battler, x, y, segments, pixels)
        local hp = Policy.shownHP(battler)
        local maxHp = battler.mon.stats.hp
        local shownPixels = tonumber(pixels)
        local px
        if shownPixels ~= nil then
          px = math.floor(math.max(0, shownPixels) * segments / 6)
        else
          px = maxHp > 0 and math.floor(hp * segments * 8 / maxHp) or 0
        end
        px = math.min(segments * 8, math.max(0, px))
        if hp > 0 then px = math.max(1, px) end
        if px > 0 then zones[#zones + 1] = { colors = false, x = x, y = y, w = px, h = 2 } end
      end

      if betterBattle then
        if Policy.enemyVisible(battle) then trueColorFill(battle.enemy, 208, 51, 11) end
        if Policy.playerVisible(battle) then
          trueColorFill(battle.player, 24, 51, 11)
          local state = Meters.getBattleXpState(battle)
          local px = state.shown or 0
          if px > 0 then
            zones[#zones + 1] = {
              colors = false,
              x = 24,
              y = 67,
              w = px,
              h = 2,
            }
          end
        end
      elseif battleMode == "off" then
        -- Stock WIDE uses a 48-pixel animated HP value. Exempt only its
        -- two-pixel semantic fill from the BetterMenus palette.
        if Policy.enemyVisible(battle) then
          trueColorFill(battle.enemy, 24, 19, 11, battle.enemy.shownPx)
        end
        if Policy.playerVisible(battle) then
          trueColorFill(battle.player, 208, 75, 10, battle.player.shownPx)
        end
      else
        -- MOD provider HUDs retain their existing provider-owned exemption.
        if Policy.enemyVisible(battle) then
          zones[#zones + 1] = { colors = false, x = 8, y = 16, w = 112, h = 8 }
        end
        if Policy.playerVisible(battle) then
          zones[#zones + 1] = { colors = false, x = 192, y = 72, w = 112, h = 8 }
        end
      end

      if Policy.levelUpStatBoxVisible(battle) then
        zones[#zones + 1] = PaletteFX.zone(palette, 27, 2, 37, 11)
      end

      return zones
    end
  end

  return M
end
