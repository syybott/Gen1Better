-- Internal BetterBattle module. BetterBattle player/enemy panel composition using the shared layout.
-- Loaded once by better_battle_hud.lua; not a public consumer API.
return function(deps)
  local M = {}
  local Layout = assert(deps.layout)
  local Meters = assert(deps.meters)
  local Policy = assert(deps.policy)
  local Presentation = assert(deps.presentation)
  local Font = require("src.render.Font")
  local tinyFont = deps.compatibility.tinyFont or {}

  function M.renderWideEnemy(battle, alternateSource)
    if not Policy.enemyVisible(battle) then return false end
    local battler = battle.enemy
    local name = tostring(battler.name or "")
    local _, hasGender = Presentation.battlerGenderInfo(battle, battler)
    love.graphics.setColor(0, 0, 0, 1)
    local pad = Layout.framePadding()
    local sourceX, sourceY = alternateSource and 0 or 144, alternateSource and 96 or 32
    local dx, dy = sourceX - 168, sourceY - 32
    Font.drawBox(
      21 + dx / 8,
      4 + dy / 8,
      Layout.WIDE_PANEL_TILES,
      Layout.wideEnemyPanelHeight() / 8
    )
    Font.draw(name, 176 + dx + pad, 40 + dy + pad)
    local hpBarRight = Layout.wideHPBarEnd(22 + dx / 8)
    local levelX = Layout.wideLevelX(battler, hpBarRight)
    if hasGender then Presentation.drawBattleGender(battle, battler, levelX - 10, 40 + dy + pad) end
    Presentation.drawLevel(battler, levelX, 40 + dy + pad)
    Meters.drawWideHP(battle, battler, 22 + dx / 8, 6 + dy / 8)
    Presentation.drawEnemyIndicators(
      battle,
      sourceX + 8 + pad,
      sourceY + (pad > 0 and 30 or 22),
      hpBarRight
    )
    return true, sourceX, sourceY
  end

  function M.renderWidePlayer(battle, sourceOffsetY)
    if not Policy.playerVisible(battle) then return false end
    local battler = battle.player
    local _, hasGender = Presentation.battlerGenderInfo(battle, battler)
    love.graphics.setColor(0, 0, 0, 1)
    local pad = Layout.framePadding()
    sourceOffsetY = sourceOffsetY or 0
    Font.drawBox(0, 4 + sourceOffsetY / 8, Layout.WIDE_PANEL_TILES, pad > 0 and 7 or 6)
    local hpBarRight = Layout.wideHPBarEnd(1)
    local levelX = Layout.wideLevelX(battler, hpBarRight)
    Font.draw(tostring(battler.name or ""), 8 + pad, 40 + pad + sourceOffsetY)
    if hasGender then
      Presentation.drawBattleGender(battle, battler, levelX - 10, 40 + pad + sourceOffsetY)
    end
    Presentation.drawLevel(battler, levelX, 40 + pad + sourceOffsetY)
    Meters.drawWideHP(battle, battler, 1, 6 + sourceOffsetY / 8)
    local hpText = ("%d/%d"):format(Policy.shownHP(battler), battler.mon.stats.hp)
    local hpWidth = type(tinyFont.width) == "function" and tinyFont.width(hpText)
      or Font.width(hpText)
    local hpTextY = (pad > 0 and 63 or 56) + sourceOffsetY
    Presentation.drawStatusAt(battle, battler, 8 + pad, hpTextY)
    if type(tinyFont.draw) == "function" then
      tinyFont.draw(hpText, hpBarRight - hpWidth, hpTextY, 0)
    else
      Font.draw(hpText, hpBarRight - hpWidth, hpTextY)
    end
    if pad > 0 then
      love.graphics.push()
      love.graphics.translate(pad, 6)
    end
    Meters.drawExpProgress(
      battle,
      battler,
      8,
      64 + sourceOffsetY,
      Layout.WIDE_METER_SEGMENTS * 8,
      74 + sourceOffsetY,
      nil,
      Layout.WIDE_METER_SEGMENTS,
      Layout.WIDE_METER_CAP_TYPE,
      pad > 0 and pad or 0,
      pad > 0 and 6 or 0
    )
    if pad > 0 then love.graphics.pop() end
    return true
  end

  return M
end
