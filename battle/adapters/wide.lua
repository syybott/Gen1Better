-- Internal BetterBattle module. Stock WIDE and BetterBattle integration. install() owns the WideBattle.draw wrapper.
-- Loaded once by better_battle_hud.lua; not a public consumer API.
return function(deps)
  local M = {}
  local Field = assert(deps.field)
  local Layout = assert(deps.layout)
  local Meters = assert(deps.meters)
  local Policy = assert(deps.policy)
  local Presentation = assert(deps.presentation)
  local UiLayer = assert(deps.ui_layer)
  local Font = require("src.render.Font")
  local HudTiles = require("src.render.HudTiles")
  local WideBattle = require("src.battle.WideBattle")
  local betterFrames = deps.betterFrames
  local unpack = table.unpack or unpack

  function M.install()
    local originalWideDraw = WideBattle.draw

    WideBattle.draw = function(battle, ...)
      local uiActive = Policy.uiSetting(battle)
      local stageActive = Policy.stageSetting(battle)
      local stockExtended = Policy.stockWideExtended(battle)
      if not uiActive and not stageActive and not stockExtended then
        return originalWideDraw(battle, ...)
      end
      local args = { ... }

      local originalStatusHUDVisible = rawget(battle, "statusHUDVisible")
      local originalBottomUIVisible = rawget(battle, "bottomUIVisible")
      local originalBallRow = battle.drawBallRow
      local hadOwnBallRow = rawget(battle, "drawBallRow") ~= nil
      local suppressIntroRows = uiActive and battle.introBalls == true
      if suppressIntroRows then battle.drawBallRow = function() end end
      local bottomVisible = true
      if type(battle.bottomUIVisible) == "function" then
        local okVisible, visible = pcall(battle.bottomUIVisible, battle)
        bottomVisible = okVisible and visible == true
      end
      local renderer = battle.game and battle.game.renderer
      local originalEndBattleHUDPass = renderer and renderer.endBattleHUDPass or nil
      local originalHudTile = stockExtended and HudTiles.tile or nil
      local originalFontDraw = stockExtended and Font.draw or nil
      local originalDrawHPBar = stockExtended and HudTiles.drawHPBar or nil
      if originalHudTile then
        HudTiles.tile = function(code, x, y, ...)
          if code == 0x6E and ((x == 88 and y == 8) or (x == 264 and y == 64)) then
            local battler = x == 88 and battle.enemy or battle.player
            local level = battler and battler.mon and battler.mon.level
            return originalHudTile(code, x + Layout.stockWideLevelShift(level), y + 1, ...)
          end
          return originalHudTile(code, x, y, ...)
        end
        Font.draw = function(text, x, y, ...)
          if (x == 8 and y == 8) or (x == 192 and y == 64) then
            local battler = x == 8 and battle.enemy or battle.player
            if battler then
              local side = x == 8 and "enemy" or "player"
              local enemy = side == "enemy"
              local framed = betterFrames and betterFrames.active()
              local nameX = x + (framed and 2 or 0)
              local occupiedX = enemy and 88 or 264

              if battler.shownStatus then
                local label = battle:statusLabel({
                  status = battler.shownStatus,
                })
                local right = (enemy and 128 or 304) - (framed and 10 or 8)
                occupiedX = math.min(occupiedX, right - Font.width(label))
              else
                local level = battler.mon and battler.mon.level or 1
                local shift = Layout.stockWideLevelShift(level)
                occupiedX = occupiedX + shift

                local _, hud = Presentation.genderCompatibility(battle.game)
                local _, symbol = Presentation.battlerGenderInfo(battle, battler)
                if symbol and hud and type(hud.wideGenderXY) == "function" then
                  local ok, genderX = pcall(hud.wideGenderXY, side, level)
                  if ok and type(genderX) == "number" then
                    -- Include the icon's backing, which starts one pixel left.
                    occupiedX = math.min(occupiedX, math.floor(genderX) + shift - 1)
                  end
                end
              end

              local budget = math.max(0, math.floor(occupiedX - nameX - 1))
              local name = tostring(battler.name or "")
              if Font.width(name) > budget then
                local period = Font.width(".")
                if budget < period then
                  name = ""
                else
                  local spans = Font.split(name)
                  local count = Font.spansFitting(spans, budget - period)
                  local parts = {}
                  for i = 1, count do
                    parts[#parts + 1] = name:sub(spans[i].from, spans[i].to)
                  end
                  name = table.concat(parts) .. "."
                end
              end
              text = name
            end
          elseif
            ((x == 96 and y == 8) or (x == 272 and y == 64))
            and type(text) == "string"
            and text:match("^%d+$")
          then
            x = x + Layout.stockWideLevelShift(text)
          elseif x == 240 and y == 80 and type(text) == "string" and text:find("/", 1, true) then
            text = text:gsub("%s+", "")
            x = x + 56 - Font.width(text)
            y = y + 1
          end
          return originalFontDraw(text, x, y, ...)
        end
        HudTiles.drawHPBar = function(...)
          love.graphics.push()
          love.graphics.translate(1, 0)
          local ok, result = pcall(originalDrawHPBar, ...)
          love.graphics.pop()
          if not ok then error(result, 0) end
          return result
        end
      end

      if uiActive then
        battle.statusHUDVisible = function() return false end
        battle.bottomUIVisible = function() return false end
      end

      if battle:extendedHUD() and renderer and originalEndBattleHUDPass then
        renderer.endBattleHUDPass = function(self, previous)
          if Layout.battleIsTopState(battle) then
            if uiActive then
              UiLayer.renderBetterBattleLayer(battle, bottomVisible, originalBallRow)
            else
              if Policy.enemyVisible(battle) then
                Meters.drawSemanticHpFill(
                  battle,
                  battle.enemy,
                  1,
                  2,
                  11,
                  battle.enemy.shownPx,
                  1,
                  0,
                  1
                )
              end
              if Policy.playerVisible(battle) then
                Meters.drawSemanticHpFill(
                  battle,
                  battle.player,
                  24,
                  9,
                  10,
                  battle.player.shownPx,
                  1,
                  0,
                  1
                )
              end
            end
          end
          return originalEndBattleHUDPass(self, previous)
        end
      end

      local ok, result
      if stageActive or uiActive then
        ok, result = pcall(function()
          local drawField = function()
            return Field.withBetterBattleField(
              battle,
              function() return originalWideDraw(battle, unpack(args)) end
            )
          end
          if uiActive then
            return Presentation.withNativeLevels(battle, false, drawField)
          else
            return drawField()
          end
        end)
      else
        ok, result = pcall(function() return originalWideDraw(battle, unpack(args)) end)
      end

      if uiActive then
        battle.statusHUDVisible = originalStatusHUDVisible
        battle.bottomUIVisible = originalBottomUIVisible
      end
      if suppressIntroRows then
        if hadOwnBallRow then
          battle.drawBallRow = originalBallRow
        else
          battle.drawBallRow = nil
        end
      end

      if renderer and originalEndBattleHUDPass then
        renderer.endBattleHUDPass = originalEndBattleHUDPass
      end
      if originalHudTile then
        HudTiles.tile = originalHudTile
        Font.draw = originalFontDraw
        HudTiles.drawHPBar = originalDrawHPBar
      end

      if not ok then error(result, 0) end

      return result
    end
  end

  return M
end
