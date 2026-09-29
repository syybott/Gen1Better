-- Internal BetterBattle module. Native-coordinate HUD content shared by classic and staged adapters.
-- Loaded once by better_battle_hud.lua; not a public consumer API.
return function(deps)
  local M = {}
  local Meters = assert(deps.meters)
  local Policy = assert(deps.policy)
  local Presentation = assert(deps.presentation)
  local Font = require("src.render.Font")
  local HudTiles = require("src.render.HudTiles")

  function M.drawStagedSemanticHpFills(battle)
    if Policy.enemyVisible(battle) then Meters.drawSemanticHpFill(battle, battle.enemy, 2, 2, 6) end
    if Policy.playerVisible(battle) then
      Meters.drawSemanticHpFill(battle, battle.player, 10, 8, 6)
    end
  end

  local function drawPlayerUnderline(y)
    HudTiles.tile(0x73, 144, y - 16)
    HudTiles.tile(0x73, 144, y - 8)
    HudTiles.tile(0x77, 144, y)
    for i = 8, 17 do
      HudTiles.tile(0x76, i * 8, y)
    end
    HudTiles.tile(0x6F, 56, y)
  end

  -- The stock player HUD uses five 8px rows and spends its last row on the
  -- curve. Grow that same shape upward by one tile and leftward by two,
  -- leaving its
  -- lower and right edges fixed so it still meets Dramatic Shape's anchors.
  -- The extra row creates genuine EXP space; the extra width lets the native
  -- font keep a gap between the EXP label and current/required readout.
  local function drawStagedPlayerHud(battle, markColor, grayFill)
    local battler = battle.player
    love.graphics.setColor(0, 0, 0, 1)
    Font.draw(Presentation.fitName(battler.name, 64), 80, 48)
    Presentation.drawStatusAt(battle, battler, 80, 56)
    Presentation.drawLevel(battler, 112, 56)
    Meters.drawNativeHP(battle, battler, 10, 8, 1, 6, markColor, grayFill)
    Font.draw(("%3d/%3d"):format(Policy.shownHP(battler), battler.mon.stats.hp), 88, 72)
    drawPlayerUnderline(88)
    Meters.drawExpProgress(battle, battler, 64, 80, 80, 90, markColor)
  end

  function M.clearStagedPlayerHud()
    local g = love.graphics
    if type(g.setBlendMode) == "function" then g.setBlendMode("replace", "premultiplied") end
    g.setColor(0, 0, 0, 0)
    g.rectangle("fill", 56, 48, 104, 48)
    if type(g.setBlendMode) == "function" then g.setBlendMode("alpha") end
  end

  -- These coordinates are the engine's original 160x144 HUD coordinates.
  -- This function is called while Dramatic Shape's native HUD texture is the
  -- active canvas, before that texture is snapped to the window edges.
  function M.drawStagedHudContent(battle, alreadyCleared, markColor, grayFill)
    if Policy.enemyVisible(battle) then
      Presentation.drawStatusAfterLevel(battle, battle.enemy, 40, 8, 88)
      Meters.drawNativeHP(battle, battle.enemy, 2, 2, nil, 6, markColor, grayFill)
      if Presentation.isCaught(battle, battle.enemy) then
        local x = Presentation.nameX(1, battle.enemy.name)
        Presentation.drawCaughtBall(battle, Presentation.caughtBallX(battle.enemy.name, x), 0)
      end
    end
    if Policy.playerVisible(battle) then
      if not alreadyCleared then M.clearStagedPlayerHud() end
      drawStagedPlayerHud(battle, markColor, grayFill)
    end
  end

  return M
end
