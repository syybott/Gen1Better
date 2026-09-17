-- BetterMenus & BetterBattle Contract Drift Driver
--
-- Exercises the live Gen1Recomp environment against the public BetterMenus and BetterBattle
-- API contracts, exports, hooks, priority chains, scene registrations, shadow settings,
-- provider ownership, and negative boundary guards.
--
-- Outputs a structured report and exits with status 0 on success or throws on failure.

local U = dofile("tests/drivers/util.lua")

return function(game)
  local json = require("src.link.Json")
  local Runtime = require("src.mods.Runtime")

  local dir = os.getenv("SHOT_DIR") or "worker-output/bettermenus-api-driver"
  local width = tonumber(os.getenv("BB_WIDTH")) or 1920
  local height = tonumber(os.getenv("BB_HEIGHT")) or 1080

  love.window.setMode(width, height, { resizable = true })
  U.wait(6)

  local report = {
    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    total = 0,
    passed = 0,
    failed = 0,
    suites = {},
    failures = {},
  }

  local currentSuite = nil

  local function suite(name)
    currentSuite = { name = name, total = 0, passed = 0, failed = 0, tests = {} }
    report.suites[#report.suites + 1] = currentSuite
    print(string.format("\n=== [SUITE] %s ===", name))
  end

  local function check(desc, condition, details)
    report.total = report.total + 1
    currentSuite.total = currentSuite.total + 1
    if condition then
      report.passed = report.passed + 1
      currentSuite.passed = currentSuite.passed + 1
      currentSuite.tests[#currentSuite.tests + 1] = { description = desc, passed = true }
      print(string.format("  [PASS] %s", desc))
    else
      report.failed = report.failed + 1
      currentSuite.failed = currentSuite.failed + 1
      local failEntry = {
        suite = currentSuite.name,
        description = desc,
        details = tostring(details or "assertion failed"),
      }
      currentSuite.tests[#currentSuite.tests + 1] = {
        description = desc,
        passed = false,
        details = failEntry.details,
      }
      report.failures[#report.failures + 1] = failEntry
      print(string.format("  [FAIL] %s: %s", desc, failEntry.details))
    end
  end

  local function eq(actual, expected, desc)
    check(desc or (tostring(actual) .. " == " .. tostring(expected)),
      actual == expected,
      string.format("expected %s, got %s", tostring(expected), tostring(actual)))
  end

  -----------------------------------------------------------------------------
  -- SUITE 1: API Presence Suite
  -----------------------------------------------------------------------------
  suite("1. API Presence Suite")

  local manager = game.mods and game.mods.exports and game.mods.exports["gen1-better-menus"]
  check("gen1-better-menus export table exists", type(manager) == "table", manager)

  local api = manager and manager.betterBattle
  check("betterBattle export table exists", type(api) == "table", api)

  local backdrop = api and api.backdrop
  check("betterBattle.backdrop table exists", type(backdrop) == "table", backdrop)
  if backdrop then
    check("backdrop.sceneIds is a function", type(backdrop.sceneIds) == "function")
    check("backdrop.resolve is a function", type(backdrop.resolve) == "function")
    check("backdrop.diagnostics is a function", type(backdrop.diagnostics) == "function")
    check("backdrop.registerScene is a function", type(backdrop.registerScene) == "function")
    check("backdrop.registerArtistScene is a function", type(backdrop.registerArtistScene) == "function")
    check("backdrop.setScene is a function", type(backdrop.setScene) == "function")
    check("backdrop.refresh is a function", type(backdrop.refresh) == "function")
    check("backdrop.effectiveGroundOffsets is a function", type(backdrop.effectiveGroundOffsets) == "function")

    local ids = backdrop.sceneIds()
    check("sceneIds() returns a table", type(ids) == "table")
    check("sceneIds() has at least 63 built-in scenes", type(ids) == "table" and #ids >= 63, #ids)

    local res, reason = backdrop.resolve({ mapId = "ROUTE_1" })
    check("resolve(ROUTE_1) returns valid string", type(res) == "string" and #res > 0, res)
  end

  local shadowSettings = api and api.shadowSettings
  check("betterBattle.shadowSettings table exists", type(shadowSettings) == "table", shadowSettings)
  if shadowSettings then
    check("shadowSettings.registerScene is a function", type(shadowSettings.registerScene) == "function")
    check("shadowSettings.registerSpecies is a function", type(shadowSettings.registerSpecies) == "function")
    check("shadowSettings.setSpecies is a function", type(shadowSettings.setSpecies) == "function")
    check("shadowSettings.setSide is a function", type(shadowSettings.setSide) == "function")
    check("shadowSettings.addShape is a function", type(shadowSettings.addShape) == "function")
    check("shadowSettings.sceneConfig is a function", type(shadowSettings.sceneConfig) == "function")
    check("shadowSettings.value is a function", type(shadowSettings.value) == "function")
  end

  -----------------------------------------------------------------------------
  -- SUITE 2: Backdrop Registration Suite
  -----------------------------------------------------------------------------
  suite("2. Backdrop Registration Suite")

  local fakeImgData = love.image.newImageData(320, 180)
  fakeImgData:mapPixel(function(x, y, r, g, b, a) return 0.2, 0.4, 0.8, 1 end)
  local fakeImg = love.graphics.newImage(fakeImgData)

  local testMod = { id = "driver_test_mod", name = "Driver Test Mod", path = "mods/driver_test_mod" }
  local foreignMod = { id = "driver_foreign_mod", name = "Driver Foreign Mod", path = "mods/driver_foreign_mod" }

  -- Register fake artist scene with elevated ledge offsets
  local regOk, regId = backdrop.registerArtistScene("driver_test_sunset", {
    image = fakeImg,
    playerOffsetY = 3,
    enemyOffsetY = -6,
    shadows = {
      color = { 0.45, 0.32, 0.18 },
      opacityScale = 0.85,
      offsetY = 1,
    }
  }, testMod)

  check("registerArtistScene returns true, id", regOk == true and regId == "driver_test_sunset", regId)

  -- Confirm it appears in sceneIds()
  local foundInRegistry = false
  for _, id in ipairs(backdrop.sceneIds()) do
    if id == "driver_test_sunset" then foundInRegistry = true; break end
  end
  check("registered scene appears in sceneIds()", foundInRegistry)

  -- Confirm shadow settings and ledge offsets were registered
  local sceneCfg = shadowSettings and shadowSettings.sceneConfig("driver_test_sunset")
  check("registered scene shadow settings exist", type(sceneCfg) == "table")
  if sceneCfg then
    eq(sceneCfg.opacityScale, 0.85, "shadow opacityScale matches")
    eq(sceneCfg.offsetY, 1, "shadow offsetY matches")
    eq(sceneCfg.playerOffsetY, 3, "playerOffsetY matches")
    eq(sceneCfg.enemyOffsetY, -6, "enemyOffsetY matches")
    check("shadow color tint preserved", sceneCfg.color and sceneCfg.color[1] == 0.45)
  end

  -- Same mod reload re-registration succeeds
  local reloadOk, reloadId = backdrop.registerArtistScene("driver_test_sunset", {
    image = fakeImg,
    shadows = { opacityScale = 0.90 }
  }, testMod)
  check("same mod re-registration succeeds (reload-stable)", reloadOk == true and reloadId == "driver_test_sunset")

  -- Negative test: Built-in ID reservation
  local resOk, resErr = backdrop.registerScene("env_route_grass", fakeImg, testMod)
  check("built-in ID reservation rejects overwrite", resOk == false and resErr == "reserved", resErr)

  -- Negative test: Third-party collision protection
  local colOk, colErr = backdrop.registerScene("driver_test_sunset", fakeImg, foreignMod)
  check("third-party collision rejected", colOk == false and colErr == "collision", colErr)

  -- Negative test: Atomic validation (invalid shadows does NOT commit image)
  local atomicFailed = false
  local preCount = #backdrop.sceneIds()
  local atomicOk, atomicErr = pcall(function()
    backdrop.registerArtistScene("driver_atomic_fail", {
      image = fakeImg,
      shadows = "not-a-table", -- Invalid!
    }, testMod)
  end)
  check("bad shadows raises assertion error", atomicOk == false)

  local foundAtomic = false
  for _, id in ipairs(backdrop.sceneIds()) do
    if id == "driver_atomic_fail" then foundAtomic = true; break end
  end
  check("atomic validation prevented partial commit", not foundAtomic and #backdrop.sceneIds() == preCount)

  -- Negative test: Invalid image dimensions
  local badImgData = love.image.newImageData(256, 144)
  local badImg = love.graphics.newImage(badImgData)
  local dimOk, dimErr = pcall(function()
    backdrop.registerScene("driver_bad_dim", badImg, testMod)
  end)
  check("non-320x180 image rejected by assertion", dimOk == false)

  -----------------------------------------------------------------------------
  -- SUITE 3: Backdrop Hook Suite (bettermenus.battle_backdrop)
  -----------------------------------------------------------------------------
  suite("3. Backdrop Hook Suite")

  local dummyGame = { overworld = { map = { id = "ROUTE_1" } }, data = { maps = {} }, renderer = {} }
  dummyGame.stack = { states = {}, visibleBase = function() return 1 end }

  -- Case A: Registered Scene ID return
  local hookCallA = false
  local unwrapA = Runtime.hooks:wrap("bettermenus.battle_backdrop", function(next, ctx)
    hookCallA = true
    return "driver_test_sunset"
  end, 50, "test_hook_a")

  local selectedA = Runtime.call("bettermenus.battle_backdrop", function() return "env_route_grass" end, { mapId = "ROUTE_1" })
  check("hook returns registered scene ID", hookCallA and selectedA == "driver_test_sunset", selectedA)
  unwrapA()

  -- Case B: False return (requests plain scene)
  local unwrapB = Runtime.hooks:wrap("bettermenus.battle_backdrop", function(next, ctx)
    return false
  end, 50, "test_hook_b")

  local selectedB = Runtime.call("bettermenus.battle_backdrop", function() return "env_route_grass" end, { mapId = "ROUTE_1" })
  check("hook returns false for plain scene", selectedB == false, selectedB)
  unwrapB()

  -- Case C: nil / next(ctx) return delegates
  local unwrapC = Runtime.hooks:wrap("bettermenus.battle_backdrop", function(next, ctx)
    return next(ctx)
  end, 50, "test_hook_c")

  local selectedC = Runtime.call("bettermenus.battle_backdrop", function() return "env_route_grass" end, { mapId = "ROUTE_1" })
  check("hook delegates cleanly on next(ctx)", selectedC == "env_route_grass", selectedC)
  unwrapC()

  -- Case D: Dynamic table return { id = "driver_dyn", image = fakeImg }
  local unwrapD = Runtime.hooks:wrap("bettermenus.battle_backdrop", function(next, ctx)
    return { id = "driver_dyn_scene", image = fakeImg }
  end, 50, "test_hook_d")

  local selectedD = Runtime.call("bettermenus.battle_backdrop", function() return "env_route_grass" end, { mapId = "ROUTE_1" })
  check("hook returns table with id", type(selectedD) == "table" and selectedD.id == "driver_dyn_scene")
  unwrapD()

  -----------------------------------------------------------------------------
  -- SUITE 4: Provider Ownership Suite (bettermenus.betterbattle_provider)
  -----------------------------------------------------------------------------
  suite("4. Provider Ownership Suite")

  -- Case 1: Full external provider claims ownership (suppresses backdrop + HUD)
  local unwrapProv1 = Runtime.hooks:wrap("bettermenus.betterbattle_provider", function(next, battle)
    return { active = true, betterBattle = false, name = "driver_full_ext" }
  end, 100, "prov_test_1")

  local provRes1 = Runtime.call("bettermenus.betterbattle_provider", function() return nil end, {})
  check("full provider claims active = true", provRes1 and provRes1.active == true)
  check("full provider claims betterBattle = false", provRes1 and provRes1.betterBattle == false)
  unwrapProv1()

  -- Case 2: HUD-only provider (allows HUD, suppresses 2D backdrop)
  local unwrapProv2 = Runtime.hooks:wrap("bettermenus.betterbattle_provider", function(next, battle)
    return { active = true, betterBattle = true, name = "driver_hud_only" }
  end, 100, "prov_test_2")

  local provRes2 = Runtime.call("bettermenus.betterbattle_provider", function() return nil end, {})
  check("hud-only provider active = true", provRes2 and provRes2.active == true)
  check("hud-only provider betterBattle = true", provRes2 and provRes2.betterBattle == true)
  unwrapProv2()

  -- Case 3: Boolean false does NOT disable provider detection
  local unwrapProv3 = Runtime.hooks:wrap("bettermenus.betterbattle_provider", function(next, battle)
    return false
  end, 100, "prov_test_3")

  local provRes3 = Runtime.call("bettermenus.betterbattle_provider", function() return nil end, {})
  check("boolean false returned as inactive provider indicator", provRes3 == false)
  unwrapProv3()

  -- Case 4: PotatoVoxel recognized as active provider
  local unwrapProv4 = Runtime.hooks:wrap("bettermenus.betterbattle_provider", function(next, battle)
    return { id = "potato_voxel", active = true, betterBattle = false }
  end, 100, "prov_test_4")

  local provRes4 = Runtime.call("bettermenus.betterbattle_provider", function() return nil end, {})
  check("potato_voxel recognized as provider", provRes4 and provRes4.id == "potato_voxel" and provRes4.active == true)
  unwrapProv4()

  -----------------------------------------------------------------------------
  -- SUITE 5: Shadow Hook Suite (bettermenus.battle_shadow)
  -----------------------------------------------------------------------------
  suite("5. Shadow Hook Suite")

  local shadowCtx = {
    side = "player",
    species = "PIKACHU",
    source = "configured",
    shape = 1,
    x = 100,
    y = 150,
    width = 24,
    height = 8,
    alpha = 0.8,
    color = { 0, 0, 0 },
    rotation = 0,
  }

  -- Case A: Mutate shadow properties
  local shadowHookCalled = false
  local unwrapShadowA = Runtime.hooks:wrap("bettermenus.battle_shadow", function(next, ctx)
    shadowHookCalled = true
    return {
      width = ctx.width * 1.5,
      height = ctx.height * 1.2,
      color = { 0.5, 0.2, 0.1 },
      rotation = 12,
    }
  end, 50, "shadow_test_a")

  local shadowResult = Runtime.call("bettermenus.battle_shadow", function() return nil end, shadowCtx)
  check("shadow hook executed", shadowHookCalled)
  check("shadow hook mutated width and height", shadowResult and shadowResult.width == 36 and shadowResult.height == 9.6)
  check("shadow hook mutated color", shadowResult and shadowResult.color and shadowResult.color[1] == 0.5)
  check("shadow hook mutated rotation", shadowResult and shadowResult.rotation == 12)
  unwrapShadowA()

  -- Case B: Suppress shadow shape with false
  local unwrapShadowB = Runtime.hooks:wrap("bettermenus.battle_shadow", function(next, ctx)
    if ctx.shape == 1 then return false end
    return next(ctx)
  end, 50, "shadow_test_b")

  local shadowSuppressed = Runtime.call("bettermenus.battle_shadow", function() return nil end, shadowCtx)
  check("shadow hook suppressed shape with false", shadowSuppressed == false)
  unwrapShadowB()

  -----------------------------------------------------------------------------
  -- SUITE 6: Scene Shadow Suite (shadowSettings.registerScene)
  -----------------------------------------------------------------------------
  suite("6. Scene Shadow Suite")

  shadowSettings.registerScene("driver_void_space", {
    enabled = false,
  })

  shadowSettings.registerScene("driver_deep_water", {
    color = { 0.05, 0.15, 0.35 },
    opacityScale = 0.65,
    offsetY = 4,
  })

  local spaceConfig = shadowSettings.sceneConfig("driver_void_space")
  check("sceneConfig(driver_void_space) exists", type(spaceConfig) == "table")
  eq(spaceConfig and spaceConfig.enabled, false, "void scene shadow enabled is false")

  local waterConfig = shadowSettings.sceneConfig("driver_deep_water")
  check("sceneConfig(driver_deep_water) exists", type(waterConfig) == "table")
  if waterConfig then
    eq(waterConfig.opacityScale, 0.65, "water scene opacityScale is 0.65")
    eq(waterConfig.offsetY, 4, "water scene offsetY is 4")
    check("water scene color tint set", waterConfig.color and waterConfig.color[3] == 0.35)
  end

  -----------------------------------------------------------------------------
  -- SUITE 7: Hook Ordering & Priority Suite
  -----------------------------------------------------------------------------
  suite("7. Hook Ordering & Priority Suite")

  local orderTrace = {}

  local unwrapLow = Runtime.hooks:wrap("bettermenus.battle_backdrop", function(next, ctx)
    orderTrace[#orderTrace + 1] = "low_p10"
    return next(ctx)
  end, 10, "test_order_low")

  local unwrapHigh = Runtime.hooks:wrap("bettermenus.battle_backdrop", function(next, ctx)
    orderTrace[#orderTrace + 1] = "high_p100"
    return next(ctx)
  end, 100, "test_order_high")

  Runtime.call("bettermenus.battle_backdrop", function() return "default" end, { mapId = "ROUTE_1" })

  check("both priority hooks called", #orderTrace == 2)
  eq(orderTrace[1], "high_p100", "priority 100 executed first")
  eq(orderTrace[2], "low_p10", "priority 10 executed second")

  unwrapHigh()
  unwrapLow()

  -----------------------------------------------------------------------------
  -- SUITE 8: Diagnostics & Detachment Suite
  -----------------------------------------------------------------------------
  suite("8. Diagnostics & Detachment Suite")

  local BattleState = require("src.battle.BattleState")
  local mockBattle = {
    game = dummyGame,
    kind = "wild",
    enemy = { mon = { species = "PIDGEY" } },
  }

  -- Test diagnostics on untracked/nil battle returns nil safely
  local diagNil = backdrop.diagnostics(mockBattle)
  check("untracked battle returns nil diagnostics safely", diagNil == nil)

  -- Create wild battle to invoke backdrop capture
  local wildBattle = BattleState.newWild(game, "PIKACHU", 5, {})
  local diag = backdrop.diagnostics(wildBattle)

  check("diagnostics returned for active battle", type(diag) == "table")
  if diag then
    check("diagnostics has sceneId", diag.sceneId ~= nil)
    check("diagnostics has reason", type(diag.reason) == "string")
    check("diagnostics has rendered flag", type(diag.rendered) == "boolean")
    check("diagnostics has shadows table", type(diag.shadows) == "table")

    -- Detachment verification: mutating diag does not mutate future calls
    local origSceneId = diag.sceneId
    diag.sceneId = "MUTATED_BY_MALICIOUS_CALLER"
    local diagFresh = backdrop.diagnostics(wildBattle)
    eq(diagFresh.sceneId, origSceneId, "diagnostics table is detached (immutable)")

    -- Mid-Battle Arena Transformation tests
    local cutOk, cutId = backdrop.setScene(wildBattle, "custom_space", { transition = "cut" })
    check("setScene with transition=cut succeeds", cutOk == true and cutId == "custom_space")
    local diagCut = backdrop.diagnostics(wildBattle)
    eq(diagCut.sceneId, "custom_space", "diagnostics reflect new scene after cut")
    eq(diagCut.transitionActive, false, "cut transition is immediately inactive")

    local fadeOk, fadeId = backdrop.setScene(wildBattle, "driver_test_sunset", { transition = "crossfade", duration = 0.5 })
    check("setScene with transition=crossfade succeeds", fadeOk == true and fadeId == "driver_test_sunset")
    local diagFade = backdrop.diagnostics(wildBattle)
    eq(diagFade.sceneId, "driver_test_sunset", "diagnostics reflect new scene during crossfade")
    eq(diagFade.transitionActive, true, "transitionActive is true during crossfade")
    eq(diagFade.transitionType, "crossfade", "transitionType is crossfade")
    eq(diagFade.playerOffsetY, 3, "elevated ledge playerOffsetY propagates to diagnostics")
    eq(diagFade.enemyOffsetY, -6, "elevated ledge enemyOffsetY propagates to diagnostics")

    local refOk, refId, refStatus = backdrop.refresh(wildBattle, { transition = "cut" })
    check("refresh(battle) re-evaluates hook and updates scene", refOk == true)
    check("refresh returns status string", refStatus == "changed" or refStatus == "unchanged")

    -- Transition Geometry Timing & Asymmetric Ledge Tests
    local regGeomFlat = backdrop.registerArtistScene("driver_geom_flat", {
      image = fakeImg,
      playerOffsetY = 0,
      enemyOffsetY = 0,
    })
    check("registerArtistScene driver_geom_flat succeeds", regGeomFlat == true)

    local regGeomLedge = backdrop.registerArtistScene("driver_geom_ledge", {
      image = fakeImg,
      playerOffsetY = 4,
      enemyOffsetY = -12,
    })
    check("registerArtistScene driver_geom_ledge succeeds", regGeomLedge == true)

    -- Reset to flat floor
    backdrop.setScene(wildBattle, "driver_geom_flat", { transition = "cut" })
    local pInit, eInit = backdrop.effectiveGroundOffsets(wildBattle)
    eq(pInit, 0, "flat scene initial effective playerOffsetY is 0")
    eq(eInit, 0, "flat scene initial effective enemyOffsetY is 0")

    -- Test geometry = "lerp" (asymmetric: player 0->4, enemy 0->-12)
    local lerpOk, lerpId = backdrop.setScene(wildBattle, "driver_geom_ledge", {
      transition = "crossfade",
      duration = 1.0,
      geometry = "lerp",
      elapsed = 0.5,
    })
    check("setScene with geometry=lerp succeeds", lerpOk == true and lerpId == "driver_geom_ledge")
    local diagLerpHalf = backdrop.diagnostics(wildBattle)
    eq(diagLerpHalf.sceneId, "driver_geom_ledge", "scene identity switches immediately")
    eq(diagLerpHalf.transitionGeometry, "lerp", "diagnostics transitionGeometry is lerp")
    eq(diagLerpHalf.playerOffsetY, 4, "diagnostics playerOffsetY reports target scene config")
    eq(diagLerpHalf.enemyOffsetY, -12, "diagnostics enemyOffsetY reports target scene config")

    local pLerpHalf, eLerpHalf = backdrop.effectiveGroundOffsets(wildBattle)
    eq(pLerpHalf, 2, "50% lerp yields playerOffsetY = +2")
    eq(eLerpHalf, -6, "50% lerp yields enemyOffsetY = -6")
    eq(diagLerpHalf.effectivePlayerOffsetY, 2, "diagnostics effectivePlayerOffsetY reports +2 at 50% lerp")
    eq(diagLerpHalf.effectiveEnemyOffsetY, -6, "diagnostics effectiveEnemyOffsetY reports -6 at 50% lerp")

    -- Complete transition (progress = 1.0)
    backdrop.setScene(wildBattle, "driver_geom_ledge", {
      transition = "crossfade",
      duration = 1.0,
      geometry = "lerp",
      elapsed = 1.0,
    })
    local pLerpFull, eLerpFull = backdrop.effectiveGroundOffsets(wildBattle)
    eq(pLerpFull, 4, "100% lerp yields playerOffsetY = +4")
    eq(eLerpFull, -12, "100% lerp yields enemyOffsetY = -12")

    -- Test geometry = "after"
    backdrop.setScene(wildBattle, "driver_geom_flat", { transition = "cut" })
    backdrop.setScene(wildBattle, "driver_geom_ledge", {
      transition = "crossfade",
      duration = 1.0,
      geometry = "after",
      elapsed = 0.5,
    })
    local pAfterHalf, eAfterHalf = backdrop.effectiveGroundOffsets(wildBattle)
    eq(pAfterHalf, 0, "50% after yields origin playerOffsetY = 0")
    eq(eAfterHalf, 0, "50% after yields origin enemyOffsetY = 0")

    backdrop.setScene(wildBattle, "driver_geom_ledge", {
      transition = "crossfade",
      duration = 1.0,
      geometry = "after",
      elapsed = 1.0,
    })
    local pAfterFull, eAfterFull = backdrop.effectiveGroundOffsets(wildBattle)
    eq(pAfterFull, 4, "100% after yields target playerOffsetY = 4")
    eq(eAfterFull, -12, "100% after yields target enemyOffsetY = -12")

    -- Test geometry = "immediate" (default)
    backdrop.setScene(wildBattle, "driver_geom_flat", { transition = "cut" })
    backdrop.setScene(wildBattle, "driver_geom_ledge", {
      transition = "crossfade",
      duration = 1.0,
      geometry = "immediate",
      elapsed = 0.1,
    })
    local pImm, eImm = backdrop.effectiveGroundOffsets(wildBattle)
    eq(pImm, 4, "immediate yields target playerOffsetY = 4 immediately")
    eq(eImm, -12, "immediate yields target enemyOffsetY = -12 immediately")

    -- Test interruption: Active lerp interrupted by cut clears transition and snaps to final offsets immediately
    backdrop.setScene(wildBattle, "driver_geom_flat", { transition = "cut" })
    backdrop.setScene(wildBattle, "driver_geom_ledge", {
      transition = "crossfade",
      duration = 1.0,
      geometry = "lerp",
      elapsed = 0.5,
    })
    local cutInterruptOk = backdrop.setScene(wildBattle, "driver_geom_flat", { transition = "cut" })
    check("cut interrupt succeeds", cutInterruptOk == true)
    local diagCutInterrupted = backdrop.diagnostics(wildBattle)
    eq(diagCutInterrupted.transitionActive, false, "cut interruption clears transitionActive")
    local pCutInt, eCutInt = backdrop.effectiveGroundOffsets(wildBattle)
    eq(pCutInt, 0, "cut interruption immediately sets effective player offset to target")
    eq(eCutInt, 0, "cut interruption immediately sets effective enemy offset to target")

    -- Test sceneId = false edge case
    local falseOk = backdrop.setScene(wildBattle, false, { transition = "cut" })
    check("setScene(battle, false) succeeds", falseOk == true)
    local pFalse, eFalse = backdrop.effectiveGroundOffsets(wildBattle)
    eq(pFalse, 0, "sceneId=false effective player offset resolves to 0 without crash")
    eq(eFalse, 0, "sceneId=false effective enemy offset resolves to 0 without crash")
    local diagFalse = backdrop.diagnostics(wildBattle)
    eq(diagFalse.sceneId, false, "diagnostics reflects sceneId=false")
    eq(diagFalse.playerOffsetY, 0, "diagnostics reports 0 playerOffsetY for sceneId=false")
    eq(diagFalse.effectivePlayerOffsetY, 0, "diagnostics reports 0 effectivePlayerOffsetY for sceneId=false")

    -- 1. image -> false crossfade does not snap immediately and keeps transition active
    backdrop.setScene(wildBattle, "driver_geom_ledge", { transition = "cut" })
    local fadeToPlainOk, fadeToPlainId = backdrop.setScene(wildBattle, false, {
      transition = "crossfade",
      duration = 1.0,
      elapsed = 0.5,
    })
    check("image -> false crossfade setScene succeeds", fadeToPlainOk == true and fadeToPlainId == false)
    local diagFadeToPlain = backdrop.diagnostics(wildBattle)
    eq(diagFadeToPlain.sceneId, false, "image -> false target sceneId is immediately false")
    eq(diagFadeToPlain.transitionActive, true, "image -> false keeps transition active during crossfade")
    eq(diagFadeToPlain.transitionType, "crossfade", "image -> false transitionType is crossfade")
    eq(diagFadeToPlain.transitionProgress, 0.5, "image -> false transitionProgress is 0.5")

    -- 2. false -> image crossfade keeps transition active
    backdrop.setScene(wildBattle, false, { transition = "cut" })
    local fadeFromPlainOk, fadeFromPlainId = backdrop.setScene(wildBattle, "driver_geom_ledge", {
      transition = "crossfade",
      duration = 1.0,
      elapsed = 0.5,
    })
    check("false -> image crossfade setScene succeeds", fadeFromPlainOk == true and fadeFromPlainId == "driver_geom_ledge")
    local diagFadeFromPlain = backdrop.diagnostics(wildBattle)
    eq(diagFadeFromPlain.sceneId, "driver_geom_ledge", "false -> image target sceneId is driver_geom_ledge")
    eq(diagFadeFromPlain.transitionActive, true, "false -> image keeps transition active during crossfade")
    eq(diagFadeFromPlain.transitionProgress, 0.5, "false -> image transitionProgress is 0.5")

    -- 3. false -> false is treated as no-op or cut, does not crash
    backdrop.setScene(wildBattle, false, { transition = "cut" })
    local plainToPlainOk, plainToPlainId = backdrop.setScene(wildBattle, false, {
      transition = "crossfade",
      duration = 0.5,
    })
    check("false -> false setScene succeeds", plainToPlainOk == true and plainToPlainId == false)
    local diagPlainToPlain = backdrop.diagnostics(wildBattle)
    eq(diagPlainToPlain.sceneId, false, "false -> false sceneId is false")
    eq(diagPlainToPlain.transitionActive, false, "false -> false is immediate cut/no-op with no lingering transition")

    -- 4. Unknown scene returns false, "unknown-scene" and diagnostics scene remains unchanged
    backdrop.setScene(wildBattle, "driver_geom_flat", { transition = "cut" })
    local unkOk, unkErr = backdrop.setScene(wildBattle, "completely_nonexistent_backdrop_xyz")
    eq(unkOk, false, "setScene with unknown scene returns false")
    eq(unkErr, "unknown-scene", "setScene with unknown scene returns unknown-scene")
    local diagUnchanged = backdrop.diagnostics(wildBattle)
    eq(diagUnchanged.sceneId, "driver_geom_flat", "diagnostics scene remains unchanged after failed setScene")

    -- Input validation: nil battle and untracked battle return standardized error tuples
    local nilBattleOk, nilBattleErr = backdrop.setScene(nil, "driver_geom_flat")
    eq(nilBattleOk, false, "setScene(nil) returns false")
    eq(nilBattleErr, "invalid-battle", "setScene(nil) returns invalid-battle")

    local untrackedOk, untrackedErr = backdrop.setScene(mockBattle, "driver_geom_flat")
    eq(untrackedOk, false, "setScene(untracked) returns false")
    eq(untrackedErr, "no-record", "setScene(untracked) returns no-record")

    local nilRefOk, nilRefErr = backdrop.refresh(nil)
    eq(nilRefOk, false, "refresh(nil) returns false")
    eq(nilRefErr, "invalid-battle", "refresh(nil) returns invalid-battle")

    local untrackedRefOk, untrackedRefErr = backdrop.refresh(mockBattle)
    eq(untrackedRefOk, false, "refresh(untracked) returns false")
    eq(untrackedRefErr, "no-record", "refresh(untracked) returns no-record")

    -- 5. Geometry/shadow lock test: assert both geometry and shadow consume the same side offset
    backdrop.setScene(wildBattle, "driver_geom_ledge", { transition = "cut" })
    local diagLock = backdrop.diagnostics(wildBattle)
    local pOff, eOff = backdrop.effectiveGroundOffsets(wildBattle)
    eq(pOff, 4, "ground-plane player offset is +4")
    eq(eOff, -12, "ground-plane enemy offset is -12")
    eq(diagLock.playerOffsetY, pOff, "diagnostics raw playerOffsetY matches effectiveGroundOffsets")
    eq(diagLock.enemyOffsetY, eOff, "diagnostics raw enemyOffsetY matches effectiveGroundOffsets")
    eq(diagLock.effectivePlayerOffsetY, pOff, "diagnostics effectivePlayerOffsetY matches effectiveGroundOffsets")
    eq(diagLock.effectiveEnemyOffsetY, eOff, "diagnostics effectiveEnemyOffsetY matches effectiveGroundOffsets")
  end

  -----------------------------------------------------------------------------
  -- Summary & Report Generation
  -----------------------------------------------------------------------------
  print("\n========================================================")
  print(string.format("DRIVER TEST SUMMARY: %d TOTAL | %d PASSED | %d FAILED",
    report.total, report.passed, report.failed))
  print("========================================================")

  -- Ensure output directory exists
  os.execute('mkdir -p "' .. dir .. '" 2>/dev/null')
  local reportPath = dir:gsub("\\", "/") .. "/bettermenus_api_driver_report.json"
  local f = io.open(reportPath, "w")
  if f then
    f:write(json.encode(report))
    f:close()
    print("Report written to: " .. reportPath)
  else
    print("WARNING: Could not write report to " .. reportPath)
  end

  U.wait(6)

  if report.failed > 0 then
    error(string.format("BetterMenus Contract Driver detected %d contract drift failures!", report.failed))
  end
end
