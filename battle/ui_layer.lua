-- Internal BetterBattle module. Detached HUD composition, palette-mark transfer, and anchor placement.
-- Loaded once by better_battle_hud.lua; not a public consumer API.
return function(deps)
  local M = {}
  local Geometry = assert(deps.geometry)
  local Layout = assert(deps.layout)
  local Menus = assert(deps.menus)
  local Messages = assert(deps.messages)
  local Panels = assert(deps.panels)
  local Policy = assert(deps.policy)
  local Portraits = assert(deps.portraits)
  local PaletteFX = require("src.render.PaletteFX")
  local menuColors = deps.menuColors

  function M.renderStatBox(state, draw)
    local battle = state and state.gen1BetterBattleStatBoxOwner
    if not battle or not Policy.uiSetting(battle)
        or Layout.levelUpStatBox(battle) ~= state then return false end
    local renderer = battle.game and battle.game.renderer
    if not (renderer and renderer.setBattleUIAnchor) then return false end
    local canvas = renderer.gen1BetterBattleStatBoxCanvas
    if not canvas then
      canvas = love.graphics.newCanvas(304, 144)
      canvas:setFilter("nearest", "nearest")
      renderer.gen1BetterBattleStatBoxCanvas = canvas
    end
    local previousCanvas = love.graphics.getCanvas()
    local marks = PaletteFX.trueColorRects("ui")
    local firstMark = #marks + 1
    local frameMarks = PaletteFX.gen1BetterMenusFrameMarks
    local frameUi = frameMarks and frameMarks.ui
    local firstFrameMark = frameUi and #frameUi + 1
    local zones = { PaletteFX.zone(menuColors(), 0, 0, 37, 17) }
    love.graphics.push("all")
    local ok, err = pcall(function()
      love.graphics.setCanvas(canvas)
      love.graphics.origin()
      love.graphics.setScissor()
      love.graphics.clear(0, 0, 0, 0)
      draw(state)
    end)
    love.graphics.setCanvas(previousCanvas)
    love.graphics.pop()
    for i = firstMark, #marks do
      if PaletteFX.honorsTrueColor() then zones[#zones + 1] = marks[i] end
    end
    for i = #marks, firstMark, -1 do marks[i] = nil end
    if frameUi and frameUi ~= marks then
      for i = #frameUi, firstFrameMark, -1 do frameUi[i] = nil end
    end
    if not ok then error(err, 0) end
    renderer.gen1BetterBattleStatBoxZones = zones
    local before = #(renderer.uiAnchors or {})
    renderer:setBattleUIAnchor(72, 16, 88, 80, "topright",
      Geometry.betterBattlePlacement("top-right", 4, 42))
    local anchors = renderer.uiAnchors
    if anchors and #anchors > before then
      anchors[#anchors].canvas = canvas
      anchors[#anchors].extract = false
    end
    return true
  end

  local function renderBetterBattleBottom(battle, visible)
    if not visible then return nil end
    if battle.phase == "menu" then return Menus.drawBetterCommandMenu(battle) end
    if battle.phase == "messages" then
      local destination = Messages.displayedMessagePane(battle)
      if not destination or not (battle.current or battle.animPlaying or battle.msgHold) then
        return nil
      end
      if destination == "wild-intro" then
        if not battle.current then return nil end
        return Messages.drawCenteredMessageBox(battle)
      elseif destination == "center" then
        return Messages.drawCenteredMessageBox(battle)
      elseif destination == "player" then
        return Messages.drawPlayerMessageBox(battle)
      end
      return Messages.drawCenteredMessageBox(battle)
    end
    if battle.phase == "moveSelect" then
      return Menus.drawBetterMoveMenu(
        battle,
        battle.player and battle.player.curMoves,
        battle.moveIndex
      )
    end
    if battle.phase == "mimicSelect" then
      return Menus.drawBetterMoveMenu(battle, battle.mimicMoves, battle.mimicIndex)
    end
    return nil
  end

  function M.renderBetterBattleLayer(battle, bottomVisible, nativeRow)
    if not Policy.setting(battle) or not Layout.battleIsTopState(battle) then return false end
    if Layout.levelUpStatBox(battle) then bottomVisible = false end
    local renderer = battle.game.renderer
    local geometry = Geometry.resolveBattleGeometry(battle)
    local marks = PaletteFX.trueColorRects("ui")
    local firstMark = #marks + 1
    local zones = { PaletteFX.zone(menuColors(), 0, 0, 37, 17) }
    local enemyZones
    local function takeMarks(target)
      for i = firstMark, #marks do
        if PaletteFX.honorsTrueColor() then target[#target + 1] = marks[i] end
      end
      for i = #marks, firstMark, -1 do
        marks[i] = nil
      end
    end
    local playerHeadDrawn, enemyHeadDrawn
    local enemyStatusDrawn, enemyStatusX, enemyStatusY, playerStatusDrawn
    local bottomX, bottomY, bottomW, bottomH, bottomAnchor
    local enemyCanvas
    local escapeOnly = Messages.escapeMessageVisible(battle)
    love.graphics.push("all")
    local ok, err = pcall(function()
      if not escapeOnly then
        playerHeadDrawn, enemyHeadDrawn = Portraits.renderHeadPanels(battle, nativeRow)
        playerStatusDrawn = Panels.renderWidePlayer(battle, 8)
      end
      bottomX, bottomY, bottomW, bottomH, bottomAnchor =
        renderBetterBattleBottom(battle, bottomVisible)
      local enemyHeight = Layout.wideEnemyPanelHeight()
      local bottomOverlapsEnemy = bottomX
        and bottomY
        and bottomX < 304
        and bottomX + bottomW > 144
        and bottomY < 32 + enemyHeight
        and bottomY + bottomH > 32
      if battle:extendedHUD() and not escapeOnly then
        takeMarks(zones)
        enemyZones = { PaletteFX.zone(menuColors(), 0, 0, 37, 17) }
        enemyCanvas = renderer.gen1BetterBattleEnemyCanvas
        if not enemyCanvas then
          enemyCanvas = love.graphics.newCanvas(304, 144)
          enemyCanvas:setFilter("nearest", "nearest")
          renderer.gen1BetterBattleEnemyCanvas = enemyCanvas
        end
        local previousCanvas = love.graphics.getCanvas()
        love.graphics.setCanvas(enemyCanvas)
        love.graphics.clear(0, 0, 0, 0)
        enemyStatusDrawn, enemyStatusX, enemyStatusY =
          Panels.renderWideEnemy(battle, bottomOverlapsEnemy)
        love.graphics.setCanvas(previousCanvas)
        takeMarks(enemyZones)
      elseif not escapeOnly then
        enemyStatusDrawn, enemyStatusX, enemyStatusY =
          Panels.renderWideEnemy(battle, bottomOverlapsEnemy)
      end
    end)
    love.graphics.pop()
    -- Semantic fills/icons mark canvas-local bounds. Move just this draw's
    -- marks into the HUD list, including on an error, never onto the field.
    takeMarks(zones)
    if not ok then error(err, 0) end
    renderer.gen1BetterBattleZones = zones
    renderer.gen1BetterBattleEnemyZones = enemyZones
    renderer.battleHUDCanvas:setFilter("nearest", "nearest")

    if playerHeadDrawn then
      Layout.anchorWideHud(
        battle,
        0,
        0,
        128,
        40,
        "top",
        Geometry.betterBattlePlacement("top-left", 4, 0)
      )
    end
    if enemyHeadDrawn then
      Layout.anchorWideHud(
        battle,
        176,
        0,
        128,
        40,
        "topright",
        Geometry.betterBattlePlacement("top-right", 4, 0)
      )
    end
    if playerStatusDrawn then
      Layout.anchorWideHud(
        battle,
        0,
        40,
        Layout.WIDE_PANEL_TILES * 8,
        Layout.framePadding() > 0 and 56 or 48,
        "bottom",
        Geometry.betterBattlePlacement("field-bottom", 0, 0, geometry.playerX)
      )
    end
    if enemyStatusDrawn then
      local before = #(renderer.uiAnchors or {})
      Layout.anchorWideHud(
        battle,
        enemyStatusX,
        enemyStatusY,
        Layout.WIDE_PANEL_TILES * 8,
        Layout.wideEnemyPanelHeight(),
        "bottom",
        Geometry.betterBattlePlacement("field", 0, 2, geometry.enemyX, geometry.enemyGround)
      )
      local anchors = renderer.uiAnchors
      if enemyCanvas and anchors and #anchors > before then
        anchors[#anchors].canvas = enemyCanvas
      end
    end
    if bottomX then
      local destination = Messages.displayedMessagePane(battle)
      local placement
      if destination == "wild-intro" or destination == "center" then
        placement = Geometry.betterBattlePlacement("center", 0, 0)
      elseif bottomAnchor == "bottom" then
        placement = Geometry.betterBattlePlacement("center-bottom", 0, 0)
      elseif Messages.playerPaneBelowHead(battle) then
        placement = Geometry.betterBattlePlacement(
          "top-left", 4, Layout.PLAYER_MENU_BELOW_HEAD_Y
        )
        placement.topPaddingPixel = 1
      else
        placement = Geometry.betterBattlePlacement("top-left", 4, 20)
      end
      Layout.anchorWideHud(
        battle,
        bottomX,
        bottomY,
        bottomW,
        bottomH,
        bottomAnchor or "top",
        placement
      )
    end
    return true
  end

  function M.renderWide(battle)
    if not Layout.battleIsTopState(battle) then return end

    local function anchorHud(battle, x, y, w, h, anchor)
      if not battle:extendedHUD() or not Layout.battleIsTopState(battle) then return end

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

      if w > 0 and h > 0 then renderer:setBattleUIAnchor(x, y, w, h, anchor) end
    end

    local fx = battle.fx
    if fx and fx.flash and fx.flash > 0 and (battle.frame or 0) % 4 < 2 then return end

    local sx = (fx and fx.shakeX) or 0
    local sy = (fx and fx.shakeY) or 0
    if sx == 0 and sy == 0 and fx and fx.shake and fx.shake > 0 then
      sx = (battle.frame or 0) % 4 < 2 and 2 or -2
    end
    love.graphics.push("all")
    if sx ~= 0 or sy ~= 0 then love.graphics.translate(sx, sy) end

    if not battle:extendedHUD() and not Messages.escapeMessageVisible(battle) then
      Panels.renderWideEnemy(battle)
      Panels.renderWidePlayer(battle)
    end

    love.graphics.pop()
  end

  return M
end
