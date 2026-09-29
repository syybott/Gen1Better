-- Internal BetterBattle module. Staged-provider texture capture, placement bridges, and private scratch canvas.
-- Loaded once by better_battle_hud.lua; not a public consumer API.
return function(deps)
  local M = {}
  local Gender = assert(deps.gender)
  local NativePanels = assert(deps.native_panels)
  local Palette = assert(deps.palette)
  local Policy = assert(deps.policy)
  local Presentation = assert(deps.presentation)
  local mod = deps.mod
  local unpack = table.unpack or unpack

  local genderCellLayer

  local function captureStagedGenderCell(battle, layer)
    local _, hud = Presentation.genderCompatibility(battle and battle.game)
    if
      not (
        hud
        and type(hud.classicGenderXY) == "function"
        and hud.betterBattleHudCoordinatesV10
        and Policy.playerVisible(battle)
      )
    then
      return nil
    end
    local level = battle.player.mon and battle.player.mon.level or 1
    local okXY, targetX, targetY = pcall(hud.classicGenderXY, "player", level)
    if not okXY or type(targetX) ~= "number" or type(targetY) ~= "number" then return nil end

    local g = love.graphics
    if
      type(g.newCanvas) ~= "function"
      or type(g.clear) ~= "function"
      or type(g.draw) ~= "function"
      or type(g.getCanvas) ~= "function"
      or type(g.setCanvas) ~= "function"
    then
      return nil
    end
    if not genderCellLayer then
      -- The authored icon is 8x8. Dramatic Shape can add a one-pixel shadow
      -- down/right while baking the HUD, so retain that ninth edge too.
      local okCanvas, canvas =
        pcall(g.newCanvas, Gender.STAGED_GENDER_CAPTURE_SIZE, Gender.STAGED_GENDER_CAPTURE_SIZE)
      if not okCanvas or not canvas then return nil end
      if type(canvas.setFilter) == "function" then canvas:setFilter("nearest", "nearest") end
      genderCellLayer = canvas
    end

    local previous = g.getCanvas()
    g.push("all")
    g.setCanvas(genderCellLayer)
    g.clear(0, 0, 0, 0)
    g.setColor(1, 1, 1, 1)
    g.draw(layer, -Gender.STAGED_GENDER_SCRATCH_X, -Gender.STAGED_GENDER_SCRATCH_Y)
    g.pop()
    if previous then
      g.setCanvas(previous)
    else
      g.setCanvas()
    end
    return genderCellLayer, targetX, targetY
  end

  local function composeStagedTexture(battle, layer, inkPass)
    if not layer then return end
    local g = love.graphics
    if type(g.getCanvas) ~= "function" or type(g.setCanvas) ~= "function" then return end
    local previous = g.getCanvas()
    local genderCell, genderX, genderY = captureStagedGenderCell(battle, layer)
    g.push("all")
    g.setCanvas(layer)
    if genderCell then
      -- Gender Mod originally paints into a clean scratch cell so rebuilding
      -- the player HUD cannot copy name, underline or panel pixels along with
      -- its authored icon. Remove that staging cell before the band is moved.
      if type(g.setBlendMode) == "function" then g.setBlendMode("replace", "premultiplied") end
      g.setColor(0, 0, 0, 0)
      g.rectangle(
        "fill",
        Gender.STAGED_GENDER_SCRATCH_X,
        Gender.STAGED_GENDER_SCRATCH_Y,
        Gender.STAGED_GENDER_CAPTURE_SIZE,
        Gender.STAGED_GENDER_CAPTURE_SIZE
      )
    end
    if type(g.setBlendMode) == "function" then g.setBlendMode("alpha") end
    if inkPass then
      -- Some Dramatic Shape forks bake white-on-dark HUD ink through a
      -- shader while creating the texture. Clear the original player block
      -- on the finished layer, then send our replacement glyphs through that
      -- same pass so they inherit the fork's current contrast treatment.
      if Policy.playerVisible(battle) then NativePanels.clearStagedPlayerHud() end
      inkPass(function() NativePanels.drawStagedHudContent(battle, true, false) end)
      NativePanels.drawStagedSemanticHpFills(battle)
    else
      NativePanels.drawStagedHudContent(battle, false, false)
    end
    if genderCell then
      g.setColor(1, 1, 1, 1)
      g.draw(genderCell, genderX, genderY)
    end
    g.pop()
    if previous then
      g.setCanvas(previous)
    else
      g.setCanvas()
    end
  end

  -- Dramatic Shape snapshots the original classic HUD into a 160x144 texture
  -- and then moves that texture to the window edges. Edit that texture before
  -- it is placed; staged battles never draw these additions afterward.
  local function installDramaticBridge(game, companionId)
    local exports = game and game.mods and game.mods.exports
    local api = exports and exports[companionId]
    local lib = api and api.lib
    if not (lib and type(lib.require) == "function") then return end
    local ok, overworld = pcall(lib.require, "OverworldBattle")
    if not ok or type(overworld) ~= "table" or type(overworld.hudTexture) ~= "function" then
      return
    end
    local innerHudTexture = overworld.hudTexture
    local innerSnapRects = overworld.snapRects
    local companionApi = exports and exports[companionId]
    local companionVersion = tostring(companionApi and companionApi.version or "0")
    local companionMajor, companionMinor = companionVersion:match("^(%d+)%.(%d+)")
    local usesNativeStagedHud = companionId == "BATTLE_ART_VOXEL_FORK"
      and (
        (tonumber(companionMajor) or 0) > 1
        or ((tonumber(companionMajor) or 0) == 1 and (tonumber(companionMinor) or 0) >= 8)
      )
    if usesNativeStagedHud then Gender.useNativeHud() end
    if overworld.betterBattleHudTextureEditorV6 then return end

    -- Battle Art 1.8+ publishes and owns a complete snapped HUD pipeline.
    -- Repainting its private 160x144 capture through the older 1.7 bridge
    -- changes the block dimensions after the fork has already calculated its
    -- window-edge placement; in move selection that pulls names and HP bars
    -- back into the arena. Leave the fork's HUD capture and placement intact.
    -- The classic and engine-WIDE renderers remain enhanced below.
    if usesNativeStagedHud then
      overworld.hudTexture = function(liveBattle, ...)
        local args = { ... }
        local layer = Gender.withNativeHud(
          function() return innerHudTexture(liveBattle, unpack(args)) end
        )
        if not Policy.setting(liveBattle) then
          return Palette.paletteProviderHudTexture(liveBattle, layer, companionId)
        end
        return layer
      end
      overworld.betterBattleHudTextureEditorV6 = true
      mod.log:info("preserving %s %s native staged HUD coordinates", companionId, companionVersion)
      return
    end

    -- Dramatic Shape normally frosts the stock 40px-tall player HUD. Our
    -- texture keeps the same bottom/right edges but grows upward by one tile
    -- and leftward by two, so extend only the matching panel rect while it is
    -- enabled. OFF immediately restores Dramatic Shape's untouched geometry.
    if type(innerSnapRects) == "function" then
      overworld.snapRects = function(shot)
        local rects, bandPlacement = innerSnapRects(shot)
        if Policy.setting() and rects and rects.player and shot then
          local placement = bandPlacement and bandPlacement.player
          if type(placement) == "table" then
            -- BATTLE_ART_VOXEL_FORK can scale the snapped HUD separately
            -- from the battle letterbox and reports that exact placement.
            local scale = placement.scale or shot.scale or 1
            rects.player[1] = (placement.x or 0) + 56 * scale
            rects.player[2] = placement.y or ((shot.ly or 0) + 48 * scale)
            rects.player[3] = 104 * scale
            rects.player[4] = 48 * scale
          else
            -- Upstream Dramatic Shape keeps the band at shot.scale. Grow the
            -- returned native panel left/up without assuming its absolute x.
            local scale = shot.scale or 1
            rects.player[1] = rects.player[1] - 16 * scale
            rects.player[2] = rects.player[2] - 8 * scale
            rects.player[3] = rects.player[3] + 16 * scale
            rects.player[4] = rects.player[4] + 8 * scale
          end
        end
        return rects, bandPlacement
      end
    end

    overworld.hudTexture = function(liveBattle, ...)
      local args = { ... }
      if not Policy.setting(liveBattle) then
        local layer = innerHudTexture(liveBattle, unpack(args))
        return Palette.paletteProviderHudTexture(liveBattle, layer, companionId)
      end
      Gender.installGenderBridge(liveBattle.game)
      local layer = Gender.withStagedCapture(function()
        return Presentation.withNativeLevels(
          liveBattle,
          false,
          function() return innerHudTexture(liveBattle, unpack(args)) end
        )
      end)
      local inkPass
      if args[2] == true then
        local okHud, battleHud = pcall(lib.require, "BattleHud")
        if okHud and battleHud and type(battleHud.flipGlyphs) == "function" then
          inkPass = function(draw)
            return battleHud.flipGlyphs(160, 144, draw, args[3], nil, args[4])
          end
        end
      end
      composeStagedTexture(liveBattle, layer, inkPass)
      return layer
    end
    overworld.betterBattleHudTextureEditorV6 = true
    mod.log:info("attached staged HUD to %s", companionId)
  end

  function M.installDramaticBridges(game)
    local attempted = {}
    for _, companionId in ipairs(Policy.STAGED_COMPANIONS) do
      attempted[companionId] = true
      installDramaticBridge(game, companionId)
    end
    local exports = game and game.mods and game.mods.exports or {}
    for companionId, api in pairs(exports) do
      if
        not attempted[companionId]
        and type(api) == "table"
        and api.lib
        and type(api.lib.require) == "function"
      then
        installDramaticBridge(game, companionId)
      end
    end
  end

  return M
end
