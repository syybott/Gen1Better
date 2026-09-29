-- Internal BetterBattle module. Classic HUD capture and zone-pass integration. install() owns classic battle wrappers.
-- Loaded once by better_battle_hud.lua; not a public consumer API.
return function(deps)
  local M = {}
  local Meters = assert(deps.meters)
  local NativePanels = assert(deps.native_panels)
  local Policy = assert(deps.policy)
  local Presentation = assert(deps.presentation)
  local BattleState = require("src.battle.BattleState")
  local unpack = table.unpack or unpack
  local originalClassicDrawHUDs

  local classicHudLayer

  local function getClassicHudLayer()
    local g = love.graphics
    if classicHudLayer then return classicHudLayer end
    if type(g.newCanvas) ~= "function" then return nil end
    local ok, layer = pcall(g.newCanvas, 160, 144)
    if not ok or not layer then return nil end
    if type(layer.setFilter) == "function" then layer:setFilter("nearest", "nearest") end
    classicHudLayer = layer
    return classicHudLayer
  end

  local function classicEnhancementActive(battle, slide)
    return Policy.setting(battle)
      and battle
      and slide == 0
      and not battle.blankForAskName
      and (battle.introSlide or 0) <= 0
      and not battle.introBalls
      and not Policy.wideLayout(battle)
      and not Policy.stagedLayout(battle)
  end

  local function drawClassicHud(battle, slide, args)
    local g = love.graphics
    if
      type(g.getCanvas) ~= "function"
      or type(g.setCanvas) ~= "function"
      or type(g.clear) ~= "function"
      or type(g.draw) ~= "function"
    then
      return originalClassicDrawHUDs(battle, slide, unpack(args))
    end
    local layer = getClassicHudLayer()
    if not layer then return originalClassicDrawHUDs(battle, slide, unpack(args)) end

    local previous = g.getCanvas()
    local result
    local pushed = false
    local ok, err = xpcall(function()
      g.push("all")
      pushed = true
      g.setCanvas(layer)
      g.clear(0, 0, 0, 0)
      result = Presentation.withNativeLevels(battle, false, function()
        local nativeResult = originalClassicDrawHUDs(battle, slide, unpack(args))
        NativePanels.drawStagedHudContent(battle, false, true, Policy.battleColorMode(battle))
        return nativeResult
      end)
      g.pop()
      pushed = false
      if previous then
        g.setCanvas(previous)
      else
        g.setCanvas()
      end

      g.push("all")
      pushed = true
      g.setColor(1, 1, 1, 1)
      g.draw(layer, 0, 0)
      g.pop()
      pushed = false
    end, function(err) return tostring(err) end)

    if pushed then pcall(g.pop) end
    if previous then
      g.setCanvas(previous)
    else
      g.setCanvas()
    end
    if not ok then error(err, 0) end
    return result
  end

  function M.install()
    -- In the normal 160x144 renderer the battle sprites and native HUD share
    -- one canvas. Render the native HUD into a transparent 160x144 layer first,
    -- edit that layer in place, then composite it where the original draw would
    -- have happened. This keeps the game's own tiles and drawing order without
    -- clearing holes through the battlefield underneath the player panel.
    originalClassicDrawHUDs = BattleState.drawHUDs

    BattleState.drawHUDs = function(battle, slide, ...)
      local args = { ... }
      if not classicEnhancementActive(battle, slide) then
        return originalClassicDrawHUDs(battle, slide, unpack(args))
      end
      return drawClassicHud(battle, slide, args)
    end

    local originalClassicZonePass = BattleState.drawZonePass

    BattleState.drawZonePass = function(battle, ...)
      local result = originalClassicZonePass(battle, ...)
      if classicEnhancementActive(battle, 0) then Meters.drawClassicExpFill(battle) end
      return result
    end
  end

  return M
end
