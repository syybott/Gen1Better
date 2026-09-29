-- Internal BetterBattle module. Public geometry-provider registry and resolved field placement. Services on the public API are read at call time.
-- Loaded once by better_battle_hud.lua; not a public consumer API.
return function(deps)
  local M = {}
  local Layout = assert(deps.layout)
  local Policy = assert(deps.policy)
  local Runtime = require("src.mods.Runtime")
  local betterBattleApi = deps.betterBattleApi

  local geometryProviders = {}

  local geometryProviderCounter = 0

  function M.registerBattleGeometryProvider(id, providerFn, priority)
    if not id or type(providerFn) ~= "function" then return false end
    priority = tonumber(priority) or 0
    local found = false
    for _, entry in ipairs(geometryProviders) do
      if entry.id == id then
        entry.fn = providerFn
        entry.priority = priority
        found = true
        break
      end
    end
    if not found then
      geometryProviderCounter = geometryProviderCounter + 1
      table.insert(geometryProviders, {
        id = id,
        fn = providerFn,
        priority = priority,
        order = geometryProviderCounter,
      })
    end
    table.sort(geometryProviders, function(a, b)
      if a.priority ~= b.priority then return a.priority > b.priority end
      return a.order < b.order
    end)
    return true
  end

  function M.unregisterBattleGeometryProvider(id)
    if not id then return false end
    for i, entry in ipairs(geometryProviders) do
      if entry.id == id then
        table.remove(geometryProviders, i)
        return true
      end
    end
    return false
  end

  local function normalizeGeometry(g)
    if type(g) ~= "table" then return nil end
    local coordSpace = g.coordinateSpace
    if coordSpace ~= "native" and coordSpace ~= "field" then return nil end

    local playerGround = tonumber(g.playerGround)
    local enemyGround = tonumber(g.enemyGround)
    if not playerGround or not enemyGround then return nil end

    local playerShift = tonumber(g.playerShift)
    if not playerShift then playerShift = coordSpace == "native" and 0 or (playerGround - 104) end
    local enemyShift = tonumber(g.enemyShift)
    if not enemyShift then enemyShift = coordSpace == "native" and 0 or (enemyGround - 56) end

    return {
      owner = g.owner or "external",
      coordinateSpace = coordSpace,
      playerX = tonumber(g.playerX) or (coordSpace == "field" and 52 or 0),
      enemyX = tonumber(g.enemyX) or (coordSpace == "field" and 260 or 0),
      playerGround = playerGround,
      enemyGround = enemyGround,
      playerShift = playerShift,
      enemyShift = enemyShift,
      spriteScale = tonumber(g.spriteScale)
        or (coordSpace == "field" and Layout.BETTER_BATTLE_SPRITE_SCALE or 1),
      nativeBlit = g.nativeBlit == true,
      nativeAnim = g.nativeAnim == true,
      nativeClip = g.nativeClip == true,
      stock = g.stock == true,
    }
  end

  local function betterBattleGeometry(battle)
    local r = battle.game.renderer:frameRects()
    local step = math.max(1, math.floor(r.Up * Layout.BETTER_BATTLE_SCALE + 1e-6))
    local hudY = step / r.dpiY
    -- Reserve the complete player panel and its 2px ground gap.
    local playerPanelHeight = Layout.framePadding() > 0 and 56 or 48
    local playerGround =
      math.min(142, math.floor((r.vuy + r.vuh - r.uoy - (playerPanelHeight + 2) * hudY) / r.Uy))
    local baseEnemyGround = playerGround - 32
    local playerOffY = 0
    local enemyOffY = 0
    local backdropApi = betterBattleApi and betterBattleApi.backdrop
    if backdropApi and backdropApi.effectiveGroundOffsets then
      playerOffY, enemyOffY = backdropApi.effectiveGroundOffsets(battle)
      playerOffY = tonumber(playerOffY) or 0
      enemyOffY = tonumber(enemyOffY) or 0
    else
      local diag = backdropApi and backdropApi.diagnostics and backdropApi.diagnostics(battle)
      local sceneId = diag and diag.sceneId
      local shadowApi = betterBattleApi and betterBattleApi.shadowSettings
      local cfg = shadowApi and shadowApi.sceneConfig and shadowApi.sceneConfig(sceneId)
      if cfg then
        playerOffY = tonumber(cfg.playerOffsetY) or 0
        enemyOffY = tonumber(cfg.enemyOffsetY) or 0
      end
    end
    playerGround = playerGround + playerOffY
    local enemyGround = baseEnemyGround + enemyOffY
    return {
      owner = "betterbattle",
      coordinateSpace = "field",
      playerX = 52,
      enemyX = 260,
      playerGround = playerGround,
      enemyGround = enemyGround,
      playerShift = playerGround - 104,
      enemyShift = enemyGround - 56,
      spriteScale = Layout.BETTER_BATTLE_SPRITE_SCALE,
      nativeBlit = false,
      nativeAnim = false,
      nativeClip = false,
      stock = false,
    }
  end

  function M.resolveBattleGeometry(battle)
    if not battle then return nil end
    local context = {
      game = battle.game,
      battle = battle,
      uiEnabled = Policy.uiSetting(battle),
      battlesEnabled = Policy.stageSetting(battle),
    }
    if Runtime.wantsHook("bettermenus.battle_geometry") then
      local ok, custom = pcall(
        Runtime.call,
        "bettermenus.battle_geometry",
        function(ctx) return nil end,
        context
      )
      if ok and type(custom) == "table" then
        local normalized = normalizeGeometry(custom)
        if normalized then return normalized end
      end
    end
    for _, entry in ipairs(geometryProviders) do
      local ok, custom = pcall(entry.fn, battle, context)
      if ok and type(custom) == "table" then
        local normalized = normalizeGeometry(custom)
        if normalized then return normalized end
      end
    end
    if Policy.uiSetting(battle) then return normalizeGeometry(betterBattleGeometry(battle)) end
    return normalizeGeometry({
      owner = "stock",
      coordinateSpace = "native",
      playerX = 0,
      enemyX = 0,
      playerGround = 104,
      enemyGround = 56,
      playerShift = 0,
      enemyShift = 0,
      spriteScale = 1,
      nativeBlit = true,
      nativeAnim = true,
      nativeClip = true,
      stock = true,
    })
  end

  function M.betterBattlePlacement(edge, gapX, gapY, fieldX, fieldY)
    return {
      owner = "betterbattle",
      scale = Layout.BETTER_BATTLE_SCALE,
      edge = edge,
      gapX = gapX or 0,
      gapY = gapY or 0,
      fieldX = fieldX,
      fieldY = fieldY,
    }
  end

  return M
end
