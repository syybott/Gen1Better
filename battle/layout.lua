-- Internal BetterBattle module. Shared frame geometry, meter endpoints, and renderer anchors. Frame themes share these coordinates.
-- Loaded once by better_battle_hud.lua; not a public consumer API.
return function(deps)
  local M = {}
  local Font = require("src.render.Font")
  local betterFrames = deps.betterFrames

  function M.stockWideLevelShift(level)
    local frameInset = betterFrames and betterFrames.active() and 2 or 0
    return 24 - frameInset - Font.width(tostring(level or 1))
  end

  -- Both framed panels use the same meter geometry.
  -- The widened panels leave 15 track tiles with frame padding.
  -- The cap's visible pixel sits immediately after the track.
  M.WIDE_PANEL_TILES = 20

  M.WIDE_METER_SEGMENTS = M.WIDE_PANEL_TILES - 5

  M.WIDE_METER_CAP_TYPE = 0

  function M.framePadding() return betterFrames and betterFrames.active() and 2 or 0 end

  function M.wideEnemyPanelHeight() return M.framePadding() > 0 and 48 or 40 end

  function M.wideHPBarEnd(tx) return (tx + 2 + M.WIDE_METER_SEGMENTS) * 8 + M.framePadding() + 1 end

  function M.wideLevelX(battler, barEnd) return barEnd - 6 - Font.width(tostring(battler.mon.level)) end

  -- The party head and the command, move, or message panel occupy separate frames.
  M.PLAYER_PANEL_BELOW_HEAD_Y = 40

  M.PLAYER_MENU_BELOW_HEAD_Y = 39

  M.PLAYER_PANE_H = 40

  function M.anchorWideHud(battle, x, y, w, h, anchor, placement)
    if not battle:extendedHUD() then return end

    if not M.battleIsTopState(battle) then return end

    local renderer = battle.game and battle.game.renderer
    if not (renderer and renderer.setBattleUIAnchor) then return end

    x = x + (battle.extendedHUDOffsetX or 0)
    y = y + (battle.extendedHUDOffsetY or 0)

    local x2 = math.min(304, x + w)
    local y2 = math.min(144, y + h)

    x = math.max(0, x)
    y = math.max(0, y)
    w = x2 - x
    h = y2 - y

    if w > 0 and h > 0 then renderer:setBattleUIAnchor(x, y, w, h, anchor, placement) end
  end

  function M.battleIsTopState(battle)
    local stack = battle and battle.game and battle.game.stack
    return not (stack and stack.top) or stack:top() == battle
      or M.levelUpStatBox(battle) ~= nil
  end

  function M.levelUpStatBox(battle)
    local stack = battle and battle.game and battle.game.stack
    local top = stack and stack.top and stack:top()
    if top and top.gen1BetterBattleStatBoxOwner == battle then return top end
  end

  M.BETTER_BATTLE_SCALE = 0.50 -- internal only; no options entry
  M.BETTER_BATTLE_SPRITE_SCALE = 0.85

  return M
end
