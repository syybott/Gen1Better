-- Internal BetterBattle module. Gender Mod bridge and capture coordination state shared with staged providers.
-- Loaded once by better_battle_hud.lua; not a public consumer API.
return function(deps)
  local M = {}
  local Layout = assert(deps.layout)
  local Policy = assert(deps.policy)
  local Presentation = assert(deps.presentation)
  local PaletteFX = require("src.render.PaletteFX")
  local menuColors = deps.menuColors
  local mod = deps.mod
  local unpack = table.unpack or unpack

  M.STAGED_GENDER_SCRATCH_X = 0

  M.STAGED_GENDER_SCRATCH_Y = 87

  M.STAGED_GENDER_CAPTURE_SIZE = 9

  local NATIVE_STAGED_GENDER_X_NUDGE = 1

  local stagedGenderCaptureDepth = 0

  local nativeStagedHudDepth = 0

  local nativeStagedOverlayDepth = 0

  local nativeStagedHudOwner = false

  local stockWideGenderOverlayDepth = 0

  -- These scopes are owned here because the coordinate and overlay wrappers
  -- read them. Staged providers enter a scope rather than mutating counters.
  function M.withStagedCapture(draw)
    stagedGenderCaptureDepth = stagedGenderCaptureDepth + 1
    local result
    local ok, err = xpcall(function() result = draw() end, function(err) return tostring(err) end)
    stagedGenderCaptureDepth = math.max(0, stagedGenderCaptureDepth - 1)
    if not ok then error(err, 0) end
    return result
  end

  function M.withNativeHud(draw)
    nativeStagedHudDepth = nativeStagedHudDepth + 1
    local result
    local ok, err = xpcall(function() result = draw() end, function(err) return tostring(err) end)
    nativeStagedHudDepth = math.max(0, nativeStagedHudDepth - 1)
    if not ok then error(err, 0) end
    return result
  end

  function M.useNativeHud() nativeStagedHudOwner = true end

  local function drawStockGenderBackplates(battle)
    local _, hud = Presentation.genderCompatibility(battle and battle.game)
    if not (hud and type(hud.wideGenderXY) == "function") then return end

    local colors = PaletteFX.effectiveColors(menuColors()) or menuColors()
    local paper = colors and colors[1] or { 255, 255, 255 }

    local function draw(side, battler)
      if not battler or battler.shownStatus then return end
      local _, symbol = Presentation.battlerGenderInfo(battle, battler)
      if not symbol then return end

      local level = battler.mon and battler.mon.level or 1
      local ok, x, y = pcall(hud.wideGenderXY, side, level)
      if not ok or type(x) ~= "number" or type(y) ~= "number" then return end

      x, y = math.floor(x), math.floor(y)
      x = x + Layout.stockWideLevelShift(level)
      y = y + 1
      love.graphics.setShader()
      love.graphics.setColor(paper[1] / 255, paper[2] / 255, paper[3] / 255, 1)
      love.graphics.rectangle("fill", x - 1, y - 1, 10, 10)
    end

    if Policy.enemyVisible(battle) then draw("enemy", battle.enemy) end
    if Policy.playerVisible(battle) then draw("player", battle.player) end
  end

  -- Gender Mod 0.3.5 anchors the player glyph to the stock level row at
  -- y=64. Our player panel moves that level row to y=56, so teach its public
  -- BattleHUD contract the new coordinate while this HUD is enabled. Its
  -- overlay also normally hides the glyph whenever a status is present;
  -- expose the level slot just for that draw because our layout shows both.
  function M.installGenderBridge(game)
    local _, hud = Presentation.genderCompatibility(game)
    if not hud or hud.betterBattleHudCoordinatesV10 then return end

    if type(hud.classicGenderXY) == "function" then
      local originalClassicXY = hud.classicGenderXY
      hud.classicGenderXY = function(side, level)
        local x, y = originalClassicXY(side, level)
        if Policy.setting() and (nativeStagedHudDepth > 0 or nativeStagedOverlayDepth > 0) then
          -- The authored gender art ends two transparent pixels before the
          -- level glyph. At Battle Art's large integer scale that reads as a
          -- loose gap, so close it by one native pixel without resampling.
          x = x + NATIVE_STAGED_GENDER_X_NUDGE
          if side == "player" then
            -- Force the stock level row even if this bridge was hot-reloaded
            -- on top of an older Battle Info HUD coordinate wrapper.
            y = 64
          end
          return x, y
        end
        if Policy.setting() and side == "player" then
          -- Battle Art 1.8+ captures the stock HUD unchanged. Its player
          -- name is still on y=56 and its level is still on y=64, so moving
          -- the gender tile to our enhanced y=56 row would split the name.
          if stagedGenderCaptureDepth > 0 then
            return M.STAGED_GENDER_SCRATCH_X, M.STAGED_GENDER_SCRATCH_Y
          end
          y = 56
        end
        return x, y
      end
    end

    if type(hud.wideGenderXY) == "function" then
      local originalWideXY = hud.wideGenderXY
      hud.wideGenderXY = function(side, level)
        local x, y = originalWideXY(side, level)
        if Policy.setting() and side == "player" then y = 64 end
        if stockWideGenderOverlayDepth > 0 then
          x = x + Layout.stockWideLevelShift(level)
          y = y + 1
        end
        return x, y
      end
    end

    if type(hud.drawOverlay) == "function" then
      local originalOverlay = hud.drawOverlay
      hud.drawOverlay = function(battle, ...)
        local betterBattle = Policy.setting(battle)
        local redirectStock = Policy.stockWideExtended(battle)
        if not betterBattle and not redirectStock then return originalOverlay(battle, ...) end
        if betterBattle and Policy.layoutFor(battle) == "wide" then return end
        local args = { ... }
        local saved = {}
        local renderer = battle and battle.game and battle.game.renderer
        local targetCanvas = redirectStock and renderer and renderer.battleHUDCanvas or nil
        local previousRendererCanvas = renderer and renderer.canvas
        if targetCanvas then renderer.canvas = targetCanvas end

        if targetCanvas then
          local g = love.graphics
          local previousCanvas = g.getCanvas and g.getCanvas() or nil
          g.push("all")
          g.setCanvas(targetCanvas)
          if g.origin then g.origin() end
          drawStockGenderBackplates(battle)
          g.pop()
          if previousCanvas then
            g.setCanvas(previousCanvas)
          else
            g.setCanvas()
          end
        end

        local nativeStagedOverlay = betterBattle
          and nativeStagedHudOwner
          and Policy.stagedLayout(battle)
        if betterBattle then
          for _, battler in pairs({ battle and battle.enemy, battle and battle.player }) do
            if battler and battler.shownStatus then
              saved[#saved + 1] = {
                battler = battler,
                status = battler.shownStatus,
              }
              battler.shownStatus = nil
            end
          end
        end
        local result
        if nativeStagedOverlay then
          -- Gender Mod draws a second coloured glyph after Battle Art has
          -- captured the HUD. Keep that pass on the same stock level row as
          -- the captured glyph instead of repainting it through the name.
          nativeStagedOverlayDepth = nativeStagedOverlayDepth + 1
        end
        if redirectStock then stockWideGenderOverlayDepth = stockWideGenderOverlayDepth + 1 end
        local ok, err = xpcall(
          function() result = originalOverlay(battle, unpack(args)) end,
          function(err) return tostring(err) end
        )
        if targetCanvas then renderer.canvas = previousRendererCanvas end
        if nativeStagedOverlay then
          nativeStagedOverlayDepth = math.max(0, nativeStagedOverlayDepth - 1)
        end
        if redirectStock then stockWideGenderOverlayDepth = stockWideGenderOverlayDepth - 1 end
        for i = #saved, 1, -1 do
          saved[i].battler.shownStatus = saved[i].status
        end
        if not ok then error(err, 0) end
        return result
      end
    end

    hud.betterBattleHudCoordinatesV10 = true
    mod.log:info("attached HUD coordinates to Gender Mod")
  end

  return M
end
