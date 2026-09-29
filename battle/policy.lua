-- Internal BetterBattle module. Feature gates, provider ownership, and battler visibility.
-- Loaded once by better_battle_hud.lua; not a public consumer API.
return function(deps)
  local M = {}
  local BattleState = require("src.battle.BattleState")
  local Runtime = require("src.mods.Runtime")
  local betterBattleUIMode = deps.betterBattleUIMode
  local betterBattlesMode = deps.betterBattlesMode
  local mod = deps.mod

  M.STAGED_COMPANIONS = {
    "DRAMATIC_SHAPE",
    "BATTLE_ART_VOXEL_FORK",
    "DRAMALESS_SHAPE",
    "potato_voxel",
  }

  local hudGame
  local providerStates = setmetatable({}, { __mode = "k" })

  function M.setGame(game) hudGame = game end

  local function battleModeValue()
    local mode
    if type(betterBattleUIMode) == "function" then
      local ok, value = pcall(betterBattleUIMode)
      if ok then mode = value end
    end
    if mode == nil then
      local ok, value = pcall(mod.options.get, mod.options, "better_battle_ui")
      if not ok or value == nil then
        ok, value = pcall(mod.options.get, mod.options, "modern_battle_ui")
      end
      mode = ok and value or "on"
    end
    if mode == true or mode == nil then return "on" end
    if mode == false then return "off" end
    return mode
  end

  local function battleStageValue()
    local mode
    if type(betterBattlesMode) == "function" then
      local ok, value = pcall(betterBattlesMode)
      if ok then mode = value end
    end
    if mode == nil then
      local ok, value = pcall(mod.options.get, mod.options, "better_battles")
      if not ok or value == nil then
        ok, value = pcall(mod.options.get, mod.options, "modern_battle_ui")
      end
      mode = ok and value or "on"
    end
    if mode == true or mode == nil then return "on" end
    if mode == false then return "off" end
    return mode
  end

  local function wideSettingsSelected(game)
    local options = game and game.save and game.save.options
    return options and options.battleLayout == "wide" or false
  end

  local function extendedSettingsSelected(game)
    local options = game and game.save and game.save.options
    return options and options.battleHud == "extended" or false
  end

  function M.stagedLayout(battle)
    return battle
        and (rawget(battle, "dramaticShapeShot") ~= nil or battle.letterboxWhite == false)
      or false
  end

  local function knownActiveProvider(battle)
    if not M.stagedLayout(battle) then return nil end
    local exports = battle and battle.game and battle.game.mods and battle.game.mods.exports or {}
    for _, id in ipairs(M.STAGED_COMPANIONS) do
      if type(exports[id]) == "table" then
        return { id = id, active = true, betterBattle = false }
      end
    end
    return {
      id = "detected-3d-battle-provider",
      active = true,
      betterBattle = false,
    }
  end

  function M.activeProvider(battle)
    if not battle then return nil end
    local frame = tonumber(battle.frame) or 0
    local cached = providerStates[battle]
    if cached and cached.frame == frame then return cached.claim end

    local known = knownActiveProvider(battle)
    local context = {
      game = battle.game,
      battle = battle,
      provider = known and known.id or nil,
      detected = known ~= nil,
      defaultClaim = known,
    }
    local claim = known
    if Runtime.wantsHook("bettermenus.betterbattle_provider") then
      claim = Runtime.call(
        "bettermenus.betterbattle_provider",
        function(ctx) return ctx.defaultClaim end,
        context
      )
    end

    if claim == true then
      claim = {
        id = context.provider or "custom-battle-provider",
        active = true,
        betterBattle = true,
      }
    elseif claim == false then
      claim = known
    elseif type(claim) ~= "table" or claim.active ~= true then
      claim = nil
    else
      claim = {
        id = tostring(claim.id or context.provider or "custom-battle-provider"),
        active = true,
        betterBattle = claim.betterBattle == true,
      }
    end

    providerStates[battle] = { frame = frame, claim = claim }
    return claim
  end

  function M.effectiveBattleMode(battle)
    local mode = battleModeValue()
    if mode ~= "on" then return mode end
    local provider = M.activeProvider(battle)
    if provider and not provider.betterBattle then return "mod" end
    return "on"
  end

  function M.uiSetting(battle)
    if M.effectiveBattleMode(battle) ~= "on" then return false end
    local game = battle and battle.game or hudGame
    return wideSettingsSelected(game) and extendedSettingsSelected(game)
  end

  function M.stageSetting(battle)
    if battleStageValue() ~= "on" then return false end
    local game = battle and battle.game or hudGame
    return wideSettingsSelected(game) and extendedSettingsSelected(game)
  end

  function M.setting(battle) return M.uiSetting(battle) end

  function M.inversePalette()
    local ok, value = pcall(mod.options.get, mod.options, "inverse")
    return ok and value == true
  end

  function M.caughtIndicatorStyle()
    local ok, value = pcall(mod.options.get, mod.options, "pokedex_indicator")
    return ok and value or "default"
  end

  function M.wideLayout(battle)
    if not (battle and type(battle.wideLayout) == "function") then return false end
    local ok, wide = pcall(battle.wideLayout, battle)
    return ok and wide == true
  end

  function M.stockWideExtended(battle)
    if
      not battle
      or M.effectiveBattleMode(battle) ~= "off"
      or not M.wideLayout(battle)
      or type(battle.extendedHUD) ~= "function"
    then
      return false
    end
    local ok, extended = pcall(battle.extendedHUD, battle)
    return ok and extended == true
  end

  function M.shownHP(battler)
    local mon = battler and battler.mon
    return math.max(0, math.floor((battler and battler.shownHP) or (mon and mon.hp) or 0))
  end

  function M.battleColorMode(battle)
    if not (battle and type(battle.colorMode) == "function") then return false end
    local ok, enabled = pcall(battle.colorMode, battle)
    return ok and enabled == true
  end

  function M.enemyVisible(battle)
    local enemy = battle.enemy
    if
      not enemy
      or battle.showEnemyTrainer
      or battle.enemySendingOut
      or battle.introBalls
      or enemy.fainted
    then
      return false
    end
    if type(battle.growInScale) == "function" then
      local ok, scale = pcall(battle.growInScale, battle, enemy)
      if ok and scale then return false end
    end
    return true
  end

  function M.levelUpStatBoxVisible(battle)
    local stack = battle and battle.game and battle.game.stack
    local top = stack and stack:top()
    return top and getmetatable(top) == BattleState.StatBox and top.gen1BetterMenusWide
  end

  function M.playerVisible(battle)
    if M.levelUpStatBoxVisible(battle) then return false end
    return battle.player ~= nil
      and not battle.safari
      and not battle.demo
      and not battle.showPlayerBack
  end

  function M.layoutFor(battle)
    if not battle or battle.blankForAskName or (battle.introSlide or 0) > 0 then return nil end
    -- Staged/3-D providers own their detached HUD texture.  They still pass
    -- through BetterMenus palette coverage even when BetterBattle is OFF or
    -- has yielded to the provider, so install the bridge independently of
    -- the BetterBattle layout gate.
    if M.stagedLayout(battle) then return "staged" end
    if M.setting(battle) and M.wideLayout(battle) then return "wide" end
    return nil
  end

  function M.headPanelsVisible(battle)
    if
      not battle
      or battle.safari
      or battle.demo
      or battle.oakDemo
      or battle.blankForAskName
      or battle.fieldCleared
      or battle.result
      or battle.showPlayerBack
      or battle.showEnemyTrainer
      or battle.enemySendingOut
    then
      return false
    end
    if battle.introBalls then return battle.player ~= nil end
    if (battle.introSlide or 0) > 0 then return false end
    return battle.player ~= nil
  end

  return M
end
