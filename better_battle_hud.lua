-- BetterBattle composition root. Keep feature implementation in battle/ modules.
-- Public entry point and exported API are retained for existing consumers.
return function(
  mod,
  menuColors,
  useStockOgMenuPalette,
  betterBattleUIMode,
  compatibility,
  betterBattlesMode,
  betterFrames
)
  compatibility = compatibility or {}
  local betterBattleApi = {}
  local function loadModule(file)
    return assert(load(assert(mod:read(file)), "@" .. mod.path .. "/" .. file))()
  end
  local indicators = loadModule("better_battle_indicators.lua")
  local effects = loadModule("better_battle_effects.lua")
  mod.gen1BetterBattleEffects = effects

  local policy = loadModule("battle/policy.lua")({
    betterBattleUIMode = betterBattleUIMode,
    betterBattlesMode = betterBattlesMode,
    mod = mod,
  })
  local layout = loadModule("battle/layout.lua")({
    betterFrames = betterFrames,
  })
  local geometry = loadModule("battle/geometry.lua")({
    betterBattleApi = betterBattleApi,
    layout = layout,
    policy = policy,
  })
  local presentation = loadModule("battle/presentation.lua")({
    compatibility = compatibility,
    indicators = indicators,
    menuColors = menuColors,
    mod = mod,
    policy = policy,
  })
  local meters = loadModule("battle/meters.lua")({
    layout = layout,
    mod = mod,
    policy = policy,
  })
  local native_panels = loadModule("battle/native_panels.lua")({
    meters = meters,
    policy = policy,
    presentation = presentation,
  })
  local panels = loadModule("battle/panels.lua")({
    compatibility = compatibility,
    layout = layout,
    meters = meters,
    policy = policy,
    presentation = presentation,
  })
  local portraits = loadModule("battle/portraits.lua")({
    compatibility = compatibility,
    layout = layout,
    menuColors = menuColors,
    policy = policy,
  })
  local messages = loadModule("battle/messages.lua")({
    layout = layout,
    policy = policy,
    text = mod.gen1BetterMenusText or loadModule("better_text.lua"),
  })
  local menus = loadModule("battle/menus.lua")({
    compatibility = compatibility,
    layout = layout,
    policy = policy,
    presentation = presentation,
  })
  local ui_layer = loadModule("battle/ui_layer.lua")({
    geometry = geometry,
    layout = layout,
    menuColors = menuColors,
    menus = menus,
    messages = messages,
    panels = panels,
    policy = policy,
    portraits = portraits,
  })
  local footprint = loadModule("battle/footprint.lua")({
    betterBattleApi = betterBattleApi,
  })
  local field = loadModule("battle/field.lua")({
    betterBattleApi = betterBattleApi,
    effects = effects,
    footprint = footprint,
    geometry = geometry,
    messages = messages,
    mod = mod,
  })
  local wide = loadModule("battle/adapters/wide.lua")({
    betterFrames = betterFrames,
    field = field,
    layout = layout,
    meters = meters,
    policy = policy,
    presentation = presentation,
    ui_layer = ui_layer,
  })
  local classic = loadModule("battle/adapters/classic.lua")({
    meters = meters,
    native_panels = native_panels,
    policy = policy,
    presentation = presentation,
  })
  local gender = loadModule("battle/adapters/gender.lua")({
    layout = layout,
    menuColors = menuColors,
    mod = mod,
    policy = policy,
    presentation = presentation,
  })
  local palette = loadModule("battle/palette.lua")({
    menuColors = menuColors,
    meters = meters,
    mod = mod,
    native_panels = native_panels,
    policy = policy,
  })
  local staged = loadModule("battle/adapters/staged.lua")({
    gender = gender,
    mod = mod,
    native_panels = native_panels,
    palette = palette,
    policy = policy,
    presentation = presentation,
  })

  -- Preserve the original registration sequence.
  presentation.install()
  messages.install()
  menus.install()

  betterBattleApi.enabled = function(battle) return policy.uiSetting(battle) end
  betterBattleApi.uiEnabled = function(battle) return policy.uiSetting(battle) end
  betterBattleApi.battlesEnabled = function(battle) return policy.stageSetting(battle) end
  betterBattleApi.stageEnabled = function(battle) return policy.stageSetting(battle) end
  betterBattleApi.modeFor = function(battle) return policy.effectiveBattleMode(battle) end
  betterBattleApi.activeProvider = function(battle) return policy.activeProvider(battle) end
  betterBattleApi.drawStatBox = ui_layer.renderStatBox
  betterBattleApi.drawLayer = function(battle, bottomVisible)
    if bottomVisible == nil and battle and type(battle.bottomUIVisible) == "function" then
      local ok, visible = pcall(battle.bottomUIVisible, battle)
      bottomVisible = ok and visible == true or false
    end
    return ui_layer.renderBetterBattleLayer(battle, bottomVisible ~= false)
  end
  betterBattleApi.expPixels = function(battle)
    local state = meters.getBattleXpState(battle)
    return math.max(0, math.floor(tonumber(state.shown) or 0))
  end
  betterBattleApi.registerBattleGeometryProvider = function(id, providerFn, priority)
    return geometry.registerBattleGeometryProvider(id, providerFn, priority)
  end
  betterBattleApi.unregisterBattleGeometryProvider = function(id)
    return geometry.unregisterBattleGeometryProvider(id)
  end
  betterBattleApi.getBattleGeometry = function(battle) return geometry.resolveBattleGeometry(battle) end
  mod.exports.betterBattle = betterBattleApi

  wide.install()
  classic.install()

  mod.events:on("game.ready", function(ev)
    local game = ev and ev.game
    policy.setGame(game)
    gender.installGenderBridge(game)
    staged.installDramaticBridges(game)
  end)

  palette.install()

  mod.hooks:wrap("battle.overlay", function(next, battle)
    gender.installGenderBridge(battle and battle.game)
    local layout = policy.layoutFor(battle)
    if not layout then return next(battle) end
    if layout == "staged" then
      staged.installDramaticBridges(battle.game)
      return next(battle)
    end
    next(battle)
    ui_layer.renderWide(battle)
  end, 50)
end
