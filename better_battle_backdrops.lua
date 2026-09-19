-- Pixel-art scenes are an outer, true-color layer. Never palette-map this art.
local BetterBattleBackdrops = {}
local ShadowEngine = nil

local function loadShadowEngine(mod)
  if ShadowEngine then return ShadowEngine end
  if mod and type(mod.read) == "function" then
    local source = mod:read("better_shadow_engine.lua")
    if source then
      local chunk, err = load(source, "better_shadow_engine.lua", "t")
      if chunk then
        local ok, result = pcall(chunk)
        if ok and result then
          ShadowEngine = result
          return ShadowEngine
        else
          print("[Gen1Better] Failed to load better_shadow_engine.lua: " .. tostring(result))
        end
      else
        print("[Gen1Better] Failed to compile better_shadow_engine.lua: " .. tostring(err))
      end
    end
  end
  if not ShadowEngine then
    pcall(function() ShadowEngine = require("better_shadow_engine") end)
  end
  return ShadowEngine
end
BetterBattleBackdrops.loadShadowEngine = loadShadowEngine
local sceneNames = [[
boss_agatha boss_bruno boss_lorelei boss_lance boss_champion
boss_giovanni_silph boss_giovanni_hideout boss_giovanni_gym
gym_pewter_leader gym_pewter_grunt gym_cerulean_leader gym_cerulean_grunt
gym_vermilion_leader gym_fuchsia_leader gym_saffron_leader gym_viridian_grunt
town_pallet town_viridian town_pewter town_cerulean town_lavender town_celadon
town_fuchsia town_saffron town_cinnabar town_indigo_plateau
landmark_oak_lab landmark_power_plant landmark_pokemon_mansion landmark_pokemon_tower
landmark_vermilion_dock landmark_ship_deck landmark_ship_quarters landmark_digletts_cave
landmark_seafoam_b4f landmark_nugget_bridge landmark_silence_bridge landmark_fan_club
landmark_lab_general landmark_celadon_mart_roof landmark_celadon_mansion_roof
env_route_grass env_route_dirt env_tall_grass env_grass_variant env_fr_grass
env_viridian_forest env_mountain_pass env_safari_zone env_cave env_water_cave
env_ice_cave env_lava_cave env_desert_cave env_ocean_water env_lake_water env_beach env_shoreline
custom_desert custom_mountain_snow custom_snow_grass custom_space custom_spaceship
]]
local scenes = {}
for id in sceneNames:gmatch("%S+") do
  scenes[id] = "assets/backdrops/wide/" .. id .. "_320.png"
end
local customScenes = {}
local SHADOW_STYLE = "soft-feathered-oval"
local SHADOW_SHAPE = {
  contactWidthScale = 1.30,
  bodyWidthScale = 0.44,
  maximumBodyWidthScale = 0.70,
  minimumWidth = 8,
  heightScale = 0.16,
  minimumHeight = 2.5,
  maximumHeight = 4.5,
  contactInset = 0.20,
  flyingLift = 3,
  flyingWidthScale = 1.08,
  flyingHeightScale = 1.10,
  flyingAlphaScale = 0.72,
}
local SHADOW_RINGS = {
  { scale = 1.00, alpha = 0.025 },
  { scale = 0.82, alpha = 0.050 },
  { scale = 0.64, alpha = 0.075 },
}
local WING_SHADOW_RINGS = {
  { scale = 1.00, alpha = 0.012 },
  { scale = 0.90, alpha = 0.018 },
  { scale = 0.82, alpha = 0.022 },
}
-- Reduce the prior 1.15 global multiplier by 10% while preserving ring
-- proportions and per-species opacityScale overrides.
local SHADOW_GLOBAL_OPACITY = 1.035

local function drawSoftShadow(g, x, y, width, height, alphaScale,
    innerRing, side, middleRing, rotationDegrees, color, customRings)
  if ShadowEngine and ShadowEngine.drawSoftShadow then
    return ShadowEngine.drawSoftShadow(g, x, y, width, height, alphaScale,
      innerRing, side, middleRing, rotationDegrees, color, customRings)
  end
  -- Safety net fallback: inline BetterBattle feathered oval loop
  local rings = customRings or SHADOW_RINGS
  local direction = side == "player" and -1 or 1
  local rotation = math.rad(rotationDegrees or 0) * direction
  local cr, cg, cb = 0, 0, 0
  if type(color) == "table" then
    cr = tonumber(color[1] or color.r) or 0
    cg = tonumber(color[2] or color.g) or 0
    cb = tonumber(color[3] or color.b) or 0
  end
  if rotation ~= 0 then
    g.push()
    g.translate(x, y)
    g.rotate(rotation)
    x, y = 0, 0
  end
  for index, ring in ipairs(rings) do
    local ringX, ringY = x, y
    local ringWidth, ringHeight = width * ring.scale, height * ring.scale
    local tuning = index == #rings and innerRing
      or (index == 2 and middleRing)
    if type(tuning) == "table" then
      ringX = x + width * (tuning.offsetX or 0) * direction
      ringY = y + height * (tuning.offsetY or 0)
      ringWidth = width * (tuning.widthScale or ring.scale)
      ringHeight = height * (tuning.heightScale or ring.scale)
    end
    g.setColor(cr, cg, cb, ring.alpha * alphaScale)
    g.ellipse("fill", ringX, ringY, ringWidth / 2, ringHeight / 2)
  end
  if rotation ~= 0 then g.pop() end
end
BetterBattleBackdrops.drawSoftShadow = drawSoftShadow

local landmarks = {
  AGATHAS_ROOM = "boss_agatha", BRUNOS_ROOM = "boss_bruno",
  LORELEIS_ROOM = "boss_lorelei", LANCES_ROOM = "boss_lance", CHAMPIONS_ROOM = "boss_champion",
  OAKS_LAB = "landmark_oak_lab", POWER_PLANT = "landmark_power_plant",
  VERMILION_DOCK = "landmark_vermilion_dock", SS_ANNE_BOW = "landmark_ship_deck",
  SEAFOAM_ISLANDS_B4F = "landmark_seafoam_b4f", POKEMON_FAN_CLUB = "landmark_fan_club",
  DAYCARE = "landmark_fan_club", CELADON_MART_ROOF = "landmark_celadon_mart_roof",
  CELADON_MANSION_ROOF = "landmark_celadon_mansion_roof",
}
local towns = {
  PALLET_TOWN = "town_pallet", VIRIDIAN_CITY = "town_viridian", PEWTER_CITY = "town_pewter",
  CERULEAN_CITY = "town_cerulean", LAVENDER_TOWN = "town_lavender", CELADON_CITY = "town_celadon",
  FUCHSIA_CITY = "town_fuchsia", SAFFRON_CITY = "town_saffron", CINNABAR_ISLAND = "town_cinnabar",
  INDIGO_PLATEAU = "town_indigo_plateau",
}
local leaders = {
  OPP_BROCK = "gym_pewter_leader", OPP_MISTY = "gym_cerulean_leader",
  OPP_LT_SURGE = "gym_vermilion_leader", OPP_KOGA = "gym_fuchsia_leader",
  OPP_SABRINA = "gym_saffron_leader", OPP_ERIKA = false, OPP_BLAINE = false,
  OPP_AGATHA = "boss_agatha", OPP_BRUNO = "boss_bruno", OPP_LORELEI = "boss_lorelei",
  OPP_LANCE = "boss_lance", OPP_RIVAL3 = "boss_champion",
}
local gyms = {
  PEWTER_GYM = "gym_pewter_grunt", CERULEAN_GYM = "gym_cerulean_grunt",
  VIRIDIAN_GYM = "gym_viridian_grunt", VERMILION_GYM = false,
  FUCHSIA_GYM = false, SAFFRON_GYM = false, CELADON_GYM = false,
  CINNABAR_GYM = false, FIGHTING_DOJO = false,
}
local seas = { ROUTE_12=true, ROUTE_13=true, ROUTE_19=true, ROUTE_20=true, ROUTE_21=true,
  PALLET_TOWN=true, VERMILION_CITY=true, CINNABAR_ISLAND=true, VERMILION_DOCK=true }
local function starts(s, prefix) return s:sub(1, #prefix) == prefix end

-- Pure: false is an intentional plain scene, distinct from no matching rule.
function BetterBattleBackdrops.resolve(c)
  local map, water = c.mapId or "", c.surfing or c.fishing
  if landmarks[map] then return landmarks[map], "landmark" end
  if starts(map, "SILPH_CO_") then return "boss_giovanni_silph", "silph" end
  if starts(map, "ROCKET_HIDEOUT_") then return "boss_giovanni_hideout", "hideout" end
  if starts(map, "POKEMON_MANSION_") then return "landmark_pokemon_mansion", "mansion" end
  if starts(map, "POKEMON_TOWER_") then return "landmark_pokemon_tower", "tower" end
  if starts(map, "DIGLETTS_CAVE") then return "landmark_digletts_cave", "diglett" end
  if starts(map, "SS_ANNE_") then return "landmark_ship_quarters", "ship" end
  if map == "ROUTE_12" and not c.surfing then return "landmark_silence_bridge", "bridge-land-fishing" end
  if map == "ROUTE_24" and not water and c.nuggetBridgeTrainer then
    return "landmark_nugget_bridge", "bridge-trainer"
  end
  if c.kind == "trainer" and leaders[c.trainerClass] ~= nil then
    return leaders[c.trainerClass], "leader"
  end
  if c.kind == "trainer" and c.trainerClass == "OPP_GIOVANNI" and map == "VIRIDIAN_GYM" then
    return "boss_giovanni_gym", "giovanni-gym"
  end
  if gyms[map] ~= nil then return gyms[map], "gym-grunt-or-unfinished" end
  if water then
    if starts(map, "SEAFOAM_ISLANDS_") or starts(map, "CERULEAN_CAVE_") then
      return "env_water_cave", "cave-water"
    end
    return seas[map] and "env_ocean_water" or "env_lake_water", "water"
  end
  if towns[map] then return towns[map], "town" end
  if map == "VIRIDIAN_FOREST" then return "env_viridian_forest", "forest" end
  if map == "ROUTE_23" then return "env_mountain_pass", "mountain-pass" end
  if map:match("^SAFARI_ZONE_[A-Z]+$") and c.tileset == "FOREST" then
    return "env_safari_zone", "safari"
  end
  if starts(map, "SEAFOAM_ISLANDS_") then return "env_ice_cave", "ice-cave" end
  if starts(map, "MT_MOON_") and not map:find("POKECENTER")
      or starts(map, "ROCK_TUNNEL_") and not map:find("POKECENTER")
      or starts(map, "VICTORY_ROAD_") or starts(map, "CERULEAN_CAVE_")
      or c.tileset == "CAVERN" then return "env_cave", "cave" end
  if map:match("^ROUTE_%d+$") then
    return c.kind == "trainer" and "env_route_dirt" or "env_route_grass", "route"
  end
  if c.tileset == "LAB" or starts(map, "CINNABAR_LAB") then
    return "landmark_lab_general", "lab"
  end
  if c.tileset == "HOUSE" or c.tileset == "GATE" or c.tileset == "FOREST_GATE"
      or starts(c.tileset or "", "REDS_HOUSE") or map:find("HOUSE") then
    return "landmark_ship_quarters", "house-gate"
  end
  if c.tileset == "CLUB" then return "landmark_fan_club", "club" end
  if c.tileset and c.tileset ~= "OVERWORLD" and c.tileset ~= "PLATEAU" then
    return "landmark_lab_general", "interior-fallback"
  end
  return "env_route_grass", "universal-fallback"
end

function BetterBattleBackdrops.sceneIds()
  local ids = {}
  for id in pairs(scenes) do ids[#ids+1] = id end
  for id in pairs(customScenes) do ids[#ids+1] = id end
  table.sort(ids)
  return ids
end

function BetterBattleBackdrops.install(mod, api)
  local shadowEngine = loadShadowEngine(mod)
  api.shadowEngine = shadowEngine
  local source, readErr = mod:read("better_battle_shadow_settings.lua")
  assert(source, readErr)
  local chunk, compileErr = load(source,
    "@" .. mod.path .. "/better_battle_shadow_settings.lua")
  assert(chunk, compileErr)
  local shadowSettings = chunk()
  api.shadowSettings = shadowSettings
  local BattleState = require("src.battle.BattleState")
  local WideBattle = require("src.battle.WideBattle")
  local Runtime = require("src.mods.Runtime")
  local Renderer = require("src.render.Renderer")
  local PaletteFX = require("src.render.PaletteFX")
  local records = setmetatable({}, {__mode="k"})
  local images, failures = {}, {}
  local frameBattle, outerCanvas
  local function warn(key, message)
    if not failures[key] then failures[key] = true; mod.log:warn("%s", message) end
  end
  local function modKey(owner)
    if not owner then return "unknown" end
    if type(owner) == "table" then
      return owner.id
        or (owner.manifest and owner.manifest.id)
        or owner.name
        or (owner.manifest and owner.manifest.name)
        or (owner.info and (owner.info.id or owner.info.name))
        or owner.path
        or tostring(owner)
    end
    return tostring(owner)
  end
  local function capture(battle)
    local game = battle.game
    local ow = game and game.overworld
    local map, player = ow and ow.map, ow and ow.player
    local c = { game=game, battle=battle, mapId=map and map.id,
      x=player and player.cellX, y=player and player.cellY,
      surfing=player and player.surfing == true or false, fishing=battle.kaHooked == true,
      tileset=map and (map.def and map.def.tileset or map.tilesetId), kind=battle.kind,
      species=battle.enemy and battle.enemy.mon and battle.enemy.mon.species,
      trainerClass=battle.oppClass, partyIndex=battle.partyIndex }
    local def = game and game.data and game.data.maps and game.data.maps[c.mapId]
    c.tileset = def and def.tileset or c.tileset
    -- The off-bridge junior trainer at x=5 must not inherit Nugget Bridge.
    if c.mapId == "ROUTE_24" and c.kind == "trainer" then
      for _, o in ipairs(def and def.objects or {}) do
        if o.trainerClass == c.trainerClass and o.trainerParty == c.partyIndex
            and (o.x == 10 or o.x == 11) then c.nuggetBridgeTrainer = true end
      end
    end
    local default, reason = BetterBattleBackdrops.resolve(c)
    c.defaultSceneId = default
    local selected = default
    if Runtime.wantsHook("bettermenus.battle_backdrop") then
      selected = Runtime.call("bettermenus.battle_backdrop", function() return default end, c)
      if selected == nil then selected = default end
      if type(selected) == "table" and selected.id then
        local entry = selected
        selected = entry.id
        if entry.image and api and api.backdrop and api.backdrop.registerScene then
          api.backdrop.registerScene(entry.id, entry.image)
        end
      end
      if selected ~= false and not scenes[selected] and not customScenes[selected] then
        warn("hook:" .. tostring(selected), "Invalid battle backdrop scene: " .. tostring(selected))
        selected = default
      elseif selected ~= default then reason = "hook" end
    end
    records[battle] = { context=c, sceneId=selected, reason=reason,
      assetPath=scenes[selected] or (customScenes[selected] and customScenes[selected].path), rendered=false }
    return records[battle]
  end
  local wild = BattleState.newWild
  BattleState.newWild = function(game, species, level, opts)
    local battle = wild(game, species, level, opts)
    if battle then battle.kaHooked = opts and opts.hooked or nil; capture(battle) end
    return battle
  end
  local trainer = BattleState.newTrainer
  BattleState.newTrainer = function(...)
    local battle = trainer(...)
    if battle then capture(battle) end
    return battle
  end
  local function imageFor(record)
    local id = record.sceneId
    if not id then return nil end
    local custom = customScenes[id]
    if custom then
      if custom.type == "image" then
        return custom.image
      elseif custom.type == "factory" then
        if not custom.cached then
          local ok, img = pcall(custom.fn)
          if ok and img and img.getWidth and img:getWidth() == 320 and img:getHeight() == 180 then
            img:setFilter("nearest", "nearest")
            custom.cached = img
          else
            warn("custom:" .. id, "Failed to load custom backdrop " .. id .. ": " .. tostring(img))
            return nil
          end
        end
        return custom.cached
      elseif custom.type == "asset" then
        if not custom.cached then
          local ok, img = pcall(function()
            local m = custom.mod
            local assetImg = m and m.assets and m.assets.image and m.assets:image(custom.path)
            if not assetImg and type(love) == "table" and love.graphics and love.graphics.newImage then
              assetImg = love.graphics.newImage(custom.path)
            end
            assert(assetImg and assetImg:getWidth() == 320 and assetImg:getHeight() == 180,
              "custom backdrop must be 320x180")
            assetImg:setFilter("nearest", "nearest")
            return assetImg
          end)
          if ok and img then
            custom.cached = img
          else
            warn("custom:" .. id, "Failed to load custom asset " .. tostring(custom.path) .. ": " .. tostring(img))
            return nil
          end
        end
        return custom.cached
      end
    end

    local path = record.assetPath
    if not path then return nil end
    if images[path] == false then return nil end
    if not images[path] then
      local ok, image = pcall(function()
        local img = mod.assets:image(path)
        assert(img:getWidth() == 320 and img:getHeight() == 180, "backdrop must be 320x180")
        img:setFilter("nearest", "nearest")
        return img
      end)
      if not ok then
        images[path] = false; warn(path, "Cannot load battle backdrop " .. path .. ": " .. tostring(image))
        return nil
      end
      images[path] = image
    end
    return images[path]
  end
  local function eligible(battle, renderer)
    if not battle or battle.blankForAskName then return false, "nickname-or-no-battle" end
    if not api.enabled(battle) then return false, "betterbattle-inactive" end
    if api.activeProvider(battle) then return false, "external-provider" end
    if renderer.worldOverride ~= nil then return false, "world-override" end
    local stack = battle.game.stack
    local base = stack.visibleBase and stack:visibleBase()
    local found
    for i, state in ipairs(stack.states or {}) do if state == battle then found = i; break end end
    if not found or (base and base > found) then return false, "opaque-state" end
    return true
  end
  local function flyingMon(battle, battler)
    local mon = battler and battler.mon
    local def = mon and battle.data and battle.data.pokemon
      and battle.data.pokemon[mon.species]
    for _, typeId in ipairs((def and def.types) or (mon and mon.types) or {}) do
      local name = tostring(typeId):upper()
      if name == "FLYING" or name == "FLYING_TYPE" then return true end
    end
    return false
  end
  local function shadowVisible(battle, side)
    if battle.fieldCleared or (battle.introSlide or 0) > 0 then return false end
    local battler = battle[side]
    if not (battler and battler.sprite) or battler.fainted then return false end
    if side == "player" then
      return not battle.showPlayerBack and not battle.safari and not battle.demo
        and not battle.sendingOut
    end
    return not battle.showEnemyTrainer and not battle.enemyHidden
      and not battle.enemySendingOut
  end

  local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
  end

  local function spriteLayer(renderer, side)
    for _, layer in ipairs(
        renderer.gen1BetterBattleSpriteLayers or {}) do
      if layer.betterBattleSide == side
          and (layer.authoredShadow
            or layer.shadowFootprint
            or layer.detectedWingShadows) then
        return layer
      end
    end
  end

  local function drawConfiguredShadows(layer, side, species, metrics, ctx, drawn, battle, sceneId, sceneConfig)
    local state = layer.authoredShadow
    local transform = state and state.transform
    if not transform or transform.scaleX == 0 or transform.scaleY == 0 then
      transform = {
        x = side == "player" and 0 or 136,
        y = 0,
        scaleX = 1,
        scaleY = 1,
      }
    end
    local placement = layer.gen1BetterMenusPlacement
    local spritePixels = math.max(1, math.floor(
      metrics.Up * (tonumber(placement.scale) or 1) + 1e-6))
    local ux = spritePixels / (metrics.dpiX or 1)
    local uy = spritePixels / (metrics.dpiY or 1)
    local originX = metrics.uox
      + placement.fieldX * metrics.Ux - placement.fieldX * ux
    local originY = metrics.uoy
      + placement.fieldY * metrics.Uy - placement.fieldY * uy
    local direction = side == "player" and -1 or 1
    local opacityScale = SHADOW_GLOBAL_OPACITY
      * shadowSettings.value(species, side, "opacityScale")
    if sceneConfig and type(sceneConfig.opacityScale) == "number" then
      opacityScale = opacityScale * sceneConfig.opacityScale
    end
    local battler = battle and battle[side]
    local flying = battler and flyingMon(battle, battler)
    local grounding = shadowSettings.value(species, side, "grounding")
    if grounding == "grounded" then flying = false end
    if grounding == "flying" then flying = true end

    local g = love.graphics
    for index, authored in ipairs(state.profile.shapes) do
      if shadowSettings.shadowShapeEnabled(state.profile, authored) then
        local measurement = state.measurements[index]
        local shape = {}
        for key, value in pairs(authored) do shape[key] = value end
        if type(authored.animate) == "function" then
          local changes = authored.animate({
            sprite = state.sprite, frame = state.frame, side = side,
            species = species, measurement = measurement,
          })
          if changes then
            for key, value in pairs(changes) do shape[key] = value end
          end
        end
        local x, y, width, height = shape.x, shape.y,
          shape.width, shape.height
        if authored.source == "detected" and measurement then
          local footprint = measurement.footprint
          local function sizing(key)
            return shadowSettings.detectionSizing(species, side, shape, key)
          end
          local measuredWidth = math.max(
            footprint.contactWidth * sizing("contactWidthScale"),
            footprint.visibleWidth * sizing("bodyWidthScale"))
          local minimumWidth = sizing("minimumWidth")
          local maximumWidthScale = sizing("maximumWidthScale")
          if minimumWidth ~= false then
            measuredWidth = math.max(minimumWidth, measuredWidth)
          end
          if maximumWidthScale ~= false then
            measuredWidth = math.min(
              footprint.visibleWidth * maximumWidthScale, measuredWidth)
          end
          local measuredHeight = measuredWidth * sizing("heightScale")
          local minimumHeight = sizing("minimumHeight")
          local maximumHeight = sizing("maximumHeight")
          if minimumHeight ~= false then
            measuredHeight = math.max(minimumHeight, measuredHeight)
          end
          if maximumHeight ~= false then
            measuredHeight = math.min(maximumHeight, measuredHeight)
          end
          width = measuredWidth / math.abs(transform.scaleX)
            * (shape.widthScale or 1)
          height = measuredHeight / math.abs(transform.scaleY)
            * (shape.heightScale or 1)
          if shape.minWidth then width = math.max(shape.minWidth, width) end
          if shape.minHeight then height = math.max(shape.minHeight, height) end
          if x == nil then
            x = (measurement.anchor.centerX - transform.x) / transform.scaleX
            if side == "player" then x = 56 - x end
          end
          if y == nil then
            y = (measurement.anchor.contactY - transform.y) / transform.scaleY
          end
        end
        local available = authored.source == "manual" or measurement
        if available then
          assert(type(x) == "number" and type(y) == "number"
              and type(width) == "number" and width > 0
              and type(height) == "number" and height > 0
              and type(shape.opacity) == "number"
              and shape.opacity >= 0 and shape.opacity <= 1,
            "Invalid shadow shape " .. tostring(index)
              .. " for " .. tostring(species))
          local spOffX = shadowSettings.value(species, side, "offsetX") or 0
          local spOffY = shadowSettings.value(species, side, "offsetY") or 0
          local spWScale = shadowSettings.value(species, side, "widthScale") or 1
          local spHScale = shadowSettings.value(species, side, "heightScale") or 1
          x = x + (shape.offsetX or 0) + spOffX
          y = y + (shape.offsetY or 0) + spOffY
          width = width * spWScale
          height = height * spHScale
          local spriteX = side == "player" and 56 - x or x
          local layerX = transform.x + spriteX * transform.scaleX
          local layerY = transform.y + y * transform.scaleY
          local screenX = (originX + layerX * ux - ctx.viewX) * ctx.dpiX
          local screenY = (originY + layerY * uy - ctx.viewY) * ctx.dpiY
          local scaleX = math.abs(transform.scaleX) * ux * ctx.dpiX
          local scaleY = math.abs(transform.scaleY) * uy * ctx.dpiY
          local shapeWidth = width * scaleX
          local shapeHeight = height * scaleY

          local alphaMultiplier = (shape.opacity and (shape.opacity / 0.075) or 1)
          if shape.opacityScale then
            alphaMultiplier = alphaMultiplier * shape.opacityScale
          end
          local finalAlpha = alphaMultiplier * opacityScale
          local finalColor = sceneConfig and sceneConfig.color or nil
          local finalX = screenX
          local finalY = screenY + (sceneConfig and sceneConfig.offsetY and (sceneConfig.offsetY * uy * ctx.dpiY) or 0)
          local finalW = shapeWidth
          local finalH = shapeHeight
          local finalInner = shape.innerRing
          local finalMiddle = shape.middleRing
          local finalRot = shape.rotationDegrees
          local cancelled = false

          if battle and Runtime.wantsHook("bettermenus.battle_shadow") then
            local shadowCtx = {
              game = battle.game,
              battle = battle,
              sceneId = sceneId,
              side = side,
              species = species,
              battler = battler,
              flying = flying,
              kind = "configured",
              shapeIndex = index,
              source = authored.source,
              x = finalX,
              y = finalY,
              width = finalW,
              height = finalH,
              alpha = finalAlpha,
              color = finalColor,
              rotationDegrees = finalRot,
              innerRing = finalInner,
              middleRing = finalMiddle,
            }
            local res = Runtime.call("bettermenus.battle_shadow", function(c) return c end, shadowCtx)
            if res == false then
              cancelled = true
            elseif type(res) == "table" then
              finalX = res.x or finalX
              finalY = res.y or finalY
              finalW = res.width or finalW
              finalH = res.height or finalH
              finalAlpha = res.alpha ~= nil and res.alpha or finalAlpha
              finalColor = res.color or finalColor
              finalRot = res.rotationDegrees or finalRot
              finalInner = res.innerRing or finalInner
              finalMiddle = res.middleRing or finalMiddle
            end
          end

          if not cancelled then
            if shape.soft ~= false then
              drawSoftShadow(g, finalX, finalY, finalW, finalH,
                finalAlpha,
                finalInner, side, finalMiddle, finalRot, finalColor)
            else
              g.push("all")
              g.translate(finalX, finalY)
              g.scale(scaleX, scaleY)
              g.rotate(math.rad(finalRot or 0) * direction)
              local cr, cg, cb = 0, 0, 0
              if type(finalColor) == "table" then
                cr = tonumber(finalColor[1] or finalColor.r) or 0
                cg = tonumber(finalColor[2] or finalColor.g) or 0
                cb = tonumber(finalColor[3] or finalColor.b) or 0
              end
              g.setColor(cr, cg, cb, (shape.opacity or 0.05) * opacityScale)
              g.ellipse("fill", 0, 0, width / 2, height / 2)
              g.pop()
            end
            drawn[#drawn + 1] = {
              side = side, species = species, source = authored.source,
              shape = index, x = finalX, y = finalY,
              width = finalW, height = finalH,
              alphaScale = finalAlpha, sourceX = x, sourceY = y,
            }
          end
        end
      end
    end
  end

  local function drawDetectedWingShadows(
      layer, side, species, metrics, ctx, drawn, battle, sceneId, sceneConfig)
    local state = layer.detectedWingShadows
    if not state then return end
    local placement = layer.gen1BetterMenusPlacement
    local transform = state.transform
    if not placement or not transform then return end
    local spritePixels = math.max(1, math.floor(
      metrics.Up * (tonumber(placement.scale) or 1) + 1e-6))
    local ux = spritePixels / (metrics.dpiX or 1)
    local uy = spritePixels / (metrics.dpiY or 1)
    local originX = metrics.uox
      + placement.fieldX * metrics.Ux - placement.fieldX * ux
    local originY = metrics.uoy
      + placement.fieldY * metrics.Uy - placement.fieldY * uy
    local direction = side == "player" and -1 or 1
    local opacityScale = SHADOW_GLOBAL_OPACITY
      * shadowSettings.value(species, side, "opacityScale")
    if sceneConfig and type(sceneConfig.opacityScale) == "number" then
      opacityScale = opacityScale * sceneConfig.opacityScale
    end
    local battler = battle and battle[side]
    local flying = battler and flyingMon(battle, battler)
    local grounding = shadowSettings.value(species, side, "grounding")
    if grounding == "grounded" then flying = false end
    if grounding == "flying" then flying = true end

    local manualContactY =
      shadowSettings.value(species, side, "manualContactY")
    local bodyAnchor = layer.shadowAnchor or layer.shadowFootprint
    local groundY
    if type(manualContactY) == "number" then
      groundY = transform.y + manualContactY * transform.scaleY
    elseif bodyAnchor then
      groundY = bodyAnchor.contactY
    end
    for index, wing in ipairs(state.settings) do
      local footprint = state.measurements[index]
      if footprint then
        local width, height = shadowSettings.measuredDimensions(
          species, side, wing, footprint)
        width = width * (wing.widthScale or 1)
        height = height * (wing.heightScale or 1)
        local x = footprint.centerX
          + (wing.offsetX or 0) * math.abs(transform.scaleX)
        local y = (groundY or footprint.contactY)
          + (wing.offsetY or 0) * math.abs(transform.scaleY)
        local screenX =
          (originX + x * ux - ctx.viewX) * ctx.dpiX
        local screenY =
          (originY + y * uy - ctx.viewY) * ctx.dpiY
        local screenWidth = width * ux * ctx.dpiX
        local screenHeight = height * uy * ctx.dpiY
        local alphaMultiplier = (wing.opacity and (wing.opacity / 0.075) or 1)
        local finalAlpha = alphaMultiplier * opacityScale
        local finalColor = sceneConfig and sceneConfig.color or nil
        local finalX = screenX
        local finalY = screenY + (sceneConfig and sceneConfig.offsetY and (sceneConfig.offsetY * uy * ctx.dpiY) or 0)
        local finalW = screenWidth
        local finalH = screenHeight
        local finalRot = wing.rotationDegrees
        local cancelled = false

        if battle and Runtime.wantsHook("bettermenus.battle_shadow") then
          local shadowCtx = {
            game = battle.game,
            battle = battle,
            sceneId = sceneId,
            side = side,
            species = species,
            battler = battler,
            flying = flying,
            kind = "wing",
            shapeIndex = index,
            source = "detected-wing",
            x = finalX,
            y = finalY,
            width = finalW,
            height = finalH,
            alpha = finalAlpha,
            color = finalColor,
            rotationDegrees = finalRot,
            innerRing = nil,
            middleRing = nil,
          }
          local res = Runtime.call("bettermenus.battle_shadow", function(c) return c end, shadowCtx)
          if res == false then
            cancelled = true
          elseif type(res) == "table" then
            finalX = res.x or finalX
            finalY = res.y or finalY
            finalW = res.width or finalW
            finalH = res.height or finalH
            finalAlpha = res.alpha ~= nil and res.alpha or finalAlpha
            finalColor = res.color or finalColor
            finalRot = res.rotationDegrees or finalRot
          end
        end

        if not cancelled then
          drawSoftShadow(love.graphics, finalX, finalY, finalW, finalH,
            finalAlpha,
            nil, side, nil, finalRot, finalColor, WING_SHADOW_RINGS)
          drawn[#drawn + 1] = {
            side = side,
            species = species,
            source = "detected-wing",
            shape = index,
            x = finalX,
            y = finalY,
            width = finalW,
            height = finalH,
            sourceX = x,
            sourceY = y,
          }
        end
      end
    end
  end

  local function drawBattleShadows(battle, renderer, ctx)
    local record = records[battle]
    local sceneId = record and record.sceneId
    local sceneConfig = shadowSettings.sceneConfig and shadowSettings.sceneConfig(sceneId)
    if sceneConfig and sceneConfig.enabled == false then return {} end
    local metrics = renderer:frameRects()
    local drawn = {}

    for _, side in ipairs({ "player", "enemy" }) do
      if shadowVisible(battle, side) then
        local battler = battle[side]
        local layer = spriteLayer(renderer, side)
        local placement = layer and layer.gen1BetterMenusPlacement
        local footprint = layer and layer.shadowFootprint

        if placement and layer.authoredShadow then
          drawConfiguredShadows(
            layer, side, battler.mon and battler.mon.species,
            metrics, ctx, drawn, battle, sceneId, sceneConfig)
        end
        if placement and footprint and not layer.authoredShadow then
          local spritePixels = math.max(1, math.floor(
            metrics.Up * (tonumber(placement.scale) or 1) + 1e-6))
          local ux = spritePixels / (metrics.dpiX or 1)
          local uy = spritePixels / (metrics.dpiY or 1)
          local originX = metrics.uox + placement.fieldX * metrics.Ux
            - placement.fieldX * ux
          local originY = metrics.uoy + placement.fieldY * metrics.Uy
            - placement.fieldY * uy
          local species = battler.mon and battler.mon.species
          local grounding = shadowSettings.value(species, side, "grounding")
          local flying = flyingMon(battle, battler)
          if grounding == "grounded" then flying = false end
          if grounding == "flying" then flying = true end

          local fullWidth =
            footprint.fullVisibleWidth or footprint.visibleWidth
          local fullHeight =
            footprint.fullVisibleHeight or footprint.visibleHeight or 1
          local majorExtent = math.max(fullWidth, fullHeight)
          local spriteWidthScale = shadowSettings.automaticBodyValue(
            species, side, "spriteWidthScale")
          local majorExtentScale = shadowSettings.automaticBodyValue(
            species, side, "majorExtentScale")

          local sourceWidth = math.max(
            footprint.contactWidth * SHADOW_SHAPE.contactWidthScale,
            fullWidth * spriteWidthScale,
            majorExtent * majorExtentScale)
          sourceWidth = clamp(
            sourceWidth,
            SHADOW_SHAPE.minimumWidth,
            majorExtent
              * SHADOW_SHAPE.maximumBodyWidthScale)
          local sourceHeight = clamp(
            sourceWidth * SHADOW_SHAPE.heightScale,
            SHADOW_SHAPE.minimumHeight,
            SHADOW_SHAPE.maximumHeight)
          local anchor = layer.shadowAnchor or footprint
          local sourceY = anchor.contactY
          local alphaScale = SHADOW_GLOBAL_OPACITY

          if flying then
            sourceY = sourceY + SHADOW_SHAPE.flyingLift
            sourceWidth =
              sourceWidth * SHADOW_SHAPE.flyingWidthScale
            sourceHeight =
              sourceHeight * SHADOW_SHAPE.flyingHeightScale
            alphaScale = alphaScale * SHADOW_SHAPE.flyingAlphaScale
          end

          -- Apply tuning without changing the cached animation footprint.
          local sourceX = anchor.centerX
            + shadowSettings.value(species, side, "offsetX")
          sourceY = sourceY + shadowSettings.value(species, side, "offsetY")
          sourceWidth = math.max(
            shadowSettings.value(species, side, "baseWidth"),
            sourceWidth * shadowSettings.value(species, side, "widthScale"))
          sourceHeight = math.max(
            shadowSettings.value(species, side, "baseHeight"),
            sourceHeight * shadowSettings.value(species, side, "heightScale"))
          if footprint.automatic == true then
            local bodyScale = shadowSettings.automaticBodyValue(
              species, side, "sizeScale")
            sourceWidth = sourceWidth * bodyScale
            sourceHeight = sourceHeight * bodyScale
          end
          alphaScale = alphaScale
            * shadowSettings.value(species, side, "opacityScale")
          if sceneConfig and type(sceneConfig.opacityScale) == "number" then
            alphaScale = alphaScale * sceneConfig.opacityScale
          end

          local x =
            (originX + sourceX * ux - ctx.viewX)
              * ctx.dpiX
          local y =
            (originY + sourceY * uy - ctx.viewY) * ctx.dpiY
          local width = sourceWidth * ux * ctx.dpiX
          local height = sourceHeight * uy * ctx.dpiY

          local finalAlpha = alphaScale
          local finalColor = sceneConfig and sceneConfig.color or nil
          local finalX = x
          local finalY = y + (sceneConfig and sceneConfig.offsetY and (sceneConfig.offsetY * uy * ctx.dpiY) or 0)
          local finalW = width
          local finalH = height
          local finalInner = shadowSettings.value(species, side, "innerRing")
          local finalMiddle = shadowSettings.value(species, side, "middleRing")
          local finalRot = shadowSettings.value(species, side, "rotationDegrees")
          local cancelled = false

          if battle and Runtime.wantsHook("bettermenus.battle_shadow") then
            local shadowCtx = {
              game = battle.game,
              battle = battle,
              sceneId = sceneId,
              side = side,
              species = species,
              battler = battler,
              flying = flying,
              kind = "footprint",
              shapeIndex = 1,
              source = "footprint",
              x = finalX,
              y = finalY,
              width = finalW,
              height = finalH,
              alpha = finalAlpha,
              color = finalColor,
              rotationDegrees = finalRot,
              innerRing = finalInner,
              middleRing = finalMiddle,
            }
            local res = Runtime.call("bettermenus.battle_shadow", function(c) return c end, shadowCtx)
            if res == false then
              cancelled = true
            elseif type(res) == "table" then
              finalX = res.x or finalX
              finalY = res.y or finalY
              finalW = res.width or finalW
              finalH = res.height or finalH
              finalAlpha = res.alpha ~= nil and res.alpha or finalAlpha
              finalColor = res.color or finalColor
              finalRot = res.rotationDegrees or finalRot
              finalInner = res.innerRing or finalInner
              finalMiddle = res.middleRing or finalMiddle
            end
          end

          if not cancelled then
            drawSoftShadow(
              love.graphics, finalX, finalY, finalW, finalH, finalAlpha,
              finalInner, side,
              finalMiddle,
              finalRot, finalColor)
            drawn[#drawn + 1] = {
              side = side,
              species = battler.mon and battler.mon.species,
              flying = flying,
              x = finalX,
              y = finalY,
              width = finalW,
              height = finalH,
              alphaScale = finalAlpha,
              sourceX = sourceX,
              sourceY = sourceY,
              contactX = footprint.centerX,
              contactY = footprint.contactY,
            }
          end
        end
        if placement and layer and layer.detectedWingShadows then
          drawDetectedWingShadows(
            layer, side, battler.mon and battler.mon.species,
            metrics, ctx, drawn, battle, sceneId, sceneConfig)
        end
      end
    end
    love.graphics.setColor(1, 1, 1, 1)
    return drawn
  end
  local beginFrame = Renderer.beginFrame
  Renderer.beginFrame = function(self, ...)
    self.gen1BetterBattleFieldGeometry = nil
    if frameBattle and records[frameBattle] then
      records[frameBattle].rendered = false
      records[frameBattle].fieldTransparent = false
      records[frameBattle].inactiveReason = "not-drawn"
      records[frameBattle].shadowStyle = nil
      records[frameBattle].shadows = nil
    end
    frameBattle = nil
    return beginFrame(self, ...)
  end
  local wideDraw = WideBattle.draw
  WideBattle.draw = function(battle, ...)
    local renderer = battle.game.renderer
    local r = records[battle] or capture(battle)
    r.rendered, r.fieldTransparent = false, false
    local active, why = eligible(battle, renderer)
    r.inactiveReason = why
    if not active then return wideDraw(battle, ...) end
    if not r.transition and not imageFor(r) then
      r.inactiveReason = r.sceneId == false and "plain-scene" or "image-unavailable"
      return wideDraw(battle, ...)
    end
    local own = rawget(battle, "extendedWorldHUD")
    local g = love.graphics
    g.push("all")
    -- This is the actor canvas, not the outer art canvas. No white field survives.
    g.clear(0, 0, 0, 0)
    battle.extendedWorldHUD = function() return true end
    local ok, result = pcall(wideDraw, battle, ...)
    battle.extendedWorldHUD = own
    g.pop()
    if not ok then error(result, 0) end
    frameBattle = battle
    r.fieldTransparent = true
    return result
  end
  mod.hooks:wrap("render.compose", function(next, renderer, ctx)
    local handled = next(renderer, ctx)
    local battle = frameBattle
    if not battle then return handled end
    local r = records[battle]
    local active, why = eligible(battle, renderer)
    r.inactiveReason = handled == true and "external-compositor" or why
    if handled == true or not active then return handled end

    local t = r.transition
    if not t and not imageFor(r) then return handled end

    local w = math.max(1, math.floor(ctx.viewWidth * ctx.dpiX + 0.5))
    local h = math.max(1, math.floor(ctx.viewHeight * ctx.dpiY + 0.5))
    local g = love.graphics
    g.push("all")
    local previous = g.getCanvas()
    local ok, err = pcall(function()
      if not outerCanvas or outerCanvas:getWidth() ~= w or outerCanvas:getHeight() ~= h then
        if outerCanvas then outerCanvas:release() end
        outerCanvas = g.newCanvas(w, h, {dpiscale=1})
        outerCanvas:setFilter("nearest", "nearest")
      end
      g.setCanvas(outerCanvas); g.origin(); g.setScissor(); g.setShader()
      g.clear(0, 0, 0, 0); g.setColor(1, 1, 1, 1); g.setBlendMode("alpha")
      local scale = h / 180
      local dx = (w - 320 * scale) / 2

      local function drawPlainField(alpha)
        local pr, pg, pb = 1, 1, 1
        if PaletteFX and PaletteFX.paperShade then
          local okShade, rShade, gShade, bShade = pcall(PaletteFX.paperShade, battle.data)
          if okShade and rShade then pr, pg, pb = rShade, gShade, bShade end
        end
        g.setColor(pr, pg, pb, alpha or 1)
        g.rectangle("fill", 0, 0, w, h)
      end

      local function drawBackdropImg(targetImg, alpha)
        if not targetImg then return end
        g.setColor(1, 1, 1, alpha or 1)
        g.draw(targetImg, dx, 0, 0, scale, scale)
        if dx > 0 then
          r.leftQuad = r.leftQuad or g.newQuad(0, 0, 1, 180, 320, 180)
          r.rightQuad = r.rightQuad or g.newQuad(319, 0, 1, 180, 320, 180)
          g.draw(targetImg, r.leftQuad, 0, 0, 0, dx, scale)
          g.draw(targetImg, r.rightQuad, w-dx, 0, 0, dx, scale)
        end
      end

      if t then
        local dt = (love.timer and love.timer.getDelta and love.timer.getDelta()) or (1/60)
        t.elapsed = t.elapsed + dt
        local progress = math.min(1, t.elapsed / t.duration)

        local fromRecord = t.fromId and { sceneId = t.fromId, assetPath = t.fromAsset }
        local fromImg = fromRecord and imageFor(fromRecord)
        local toRecord = t.toId and { sceneId = t.toId, assetPath = t.toAsset }
        local toImg = toRecord and imageFor(toRecord)

        if not fromImg and not toImg then
          -- Plain -> Plain: no-op / clear to plain field
          drawPlainField(1.0)
          r.transition = nil
        elseif fromImg and toImg then
          -- Image -> Image
          if t.type == "crossfade" then
            drawBackdropImg(fromImg, 1.0)
            drawBackdropImg(toImg, progress)
          elseif t.type == "flash" then
            if progress < 0.5 then
              local flashProg = progress * 2
              drawBackdropImg(fromImg, 1.0 - flashProg)
              g.setColor(1, 1, 1, flashProg)
              g.rectangle("fill", 0, 0, w, h)
            else
              local flashProg = (progress - 0.5) * 2
              drawBackdropImg(toImg, flashProg)
              g.setColor(1, 1, 1, 1.0 - flashProg)
              g.rectangle("fill", 0, 0, w, h)
            end
          else
            drawBackdropImg(toImg, 1.0)
          end
        elseif fromImg and not toImg then
          -- Image -> Plain: draw plain field underneath, fade out fromImg
          drawPlainField(1.0)
          if t.type == "crossfade" then
            drawBackdropImg(fromImg, 1.0 - progress)
          elseif t.type == "flash" then
            if progress < 0.5 then
              local flashProg = progress * 2
              drawBackdropImg(fromImg, 1.0 - flashProg)
              g.setColor(1, 1, 1, flashProg)
              g.rectangle("fill", 0, 0, w, h)
            else
              local flashProg = (progress - 0.5) * 2
              g.setColor(1, 1, 1, 1.0 - flashProg)
              g.rectangle("fill", 0, 0, w, h)
            end
          end
        elseif not fromImg and toImg then
          -- Plain -> Image: draw plain field underneath, fade in toImg
          drawPlainField(1.0)
          if t.type == "crossfade" then
            drawBackdropImg(toImg, progress)
          elseif t.type == "flash" then
            if progress < 0.5 then
              local flashProg = progress * 2
              g.setColor(1, 1, 1, flashProg)
              g.rectangle("fill", 0, 0, w, h)
            else
              local flashProg = (progress - 0.5) * 2
              drawBackdropImg(toImg, flashProg)
              g.setColor(1, 1, 1, 1.0 - flashProg)
              g.rectangle("fill", 0, 0, w, h)
            end
          else
            drawBackdropImg(toImg, 1.0)
          end
        end

        if progress >= 1 then
          r.transition = nil
        end
      else
        local img = imageFor(r)
        if img then
          drawBackdropImg(img, 1.0)
        else
          drawPlainField(1.0)
        end
      end

      r.shadowStyle = SHADOW_STYLE
      r.shadows = drawBattleShadows(battle, renderer, ctx)
    end)
    g.setCanvas(previous); g.pop()
    if not ok then error(err, 0) end
    -- Claim only after downstream providers have had their chance this frame.
    renderer:setWorldOverride(outerCanvas)
    renderer.battleDim = 0
    r.rendered, r.inactiveReason = true, nil
    r.viewportWidth, r.viewportHeight = w, h
    return handled
  end, math.huge)
  api.backdrop = {
    sceneIds=BetterBattleBackdrops.sceneIds,
    resolve=function(context) return BetterBattleBackdrops.resolve(context) end,
    registerScene=function(id, imageOrPath, sourceMod)
      assert(type(id) == "string", "registerScene requires string id")
      local owner = sourceMod or mod
      local ownerKey = modKey(owner)
      if scenes[id] ~= nil then
        warn("reserved:" .. id .. ":" .. ownerKey,
          "Scene ID '" .. id .. "' is reserved by built-in backdrops; registration rejected for mod '" .. ownerKey .. "'")
        return false, "reserved"
      end
      local existing = customScenes[id]
      if existing then
        local existingMod = existing.mod
        local existingKey = modKey(existingMod)
        if existingKey ~= ownerKey then
          warn("collision:" .. id .. ":" .. ownerKey,
            "Scene ID '" .. id .. "' collision: already registered by '" .. existingKey .. "', rejected registration from '" .. ownerKey .. "'")
          return false, "collision"
        end
      end
      if type(imageOrPath) == "string" then
        customScenes[id] = { type = "asset", path = imageOrPath, mod = owner }
      elseif type(imageOrPath) == "userdata" or (type(imageOrPath) == "table" and imageOrPath.getWidth) then
        assert(imageOrPath:getWidth() == 320 and imageOrPath:getHeight() == 180,
          "Custom backdrop must be exactly 320x180 pixels")
        if imageOrPath.setFilter then
          imageOrPath:setFilter("nearest", "nearest")
        end
        customScenes[id] = { type = "image", image = imageOrPath, mod = owner }
      elseif type(imageOrPath) == "function" then
        customScenes[id] = { type = "factory", fn = imageOrPath, mod = owner }
      else
        error("Invalid imageOrPath for registerScene", 2)
      end
      return true, id
    end,
    registerArtistScene=function(id, config, sourceMod)
      assert(type(id) == "string", "registerArtistScene requires string id")
      assert(type(config) == "table", "registerArtistScene requires configuration table")

      local image = config.image or config[1]
      assert(image, "registerArtistScene requires config.image or config[1]")

      local shadows = config.shadows
      if shadows ~= nil then
        assert(type(shadows) == "table", "registerArtistScene shadows must be a table")
      end

      local owner = sourceMod or config.mod or mod
      local registered, err = api.backdrop.registerScene(id, image, owner)
      if not registered then return false, err end

      local shadowApi = api.shadowSettings
      if shadowApi and shadowApi.registerScene then
        local sceneCfg = {}
        if type(shadows) == "table" then
          for k, v in pairs(shadows) do sceneCfg[k] = v end
        end
        local playerOffY = config.playerOffsetY or (shadows and shadows.playerOffsetY)
        local enemyOffY = config.enemyOffsetY or (shadows and shadows.enemyOffsetY)
        if playerOffY ~= nil then sceneCfg.playerOffsetY = tonumber(playerOffY) end
        if enemyOffY ~= nil then sceneCfg.enemyOffsetY = tonumber(enemyOffY) end
        shadowApi.registerScene(id, sceneCfg)
      end

      return true, id
    end,
    effectiveGroundOffsets=function(battle)
      local r = records[battle]
      if not r then return 0, 0 end
      local curConfig = r.sceneId and shadowSettings.sceneConfig and shadowSettings.sceneConfig(r.sceneId)
      local targetPlayerY = curConfig and tonumber(curConfig.playerOffsetY) or 0
      local targetEnemyY = curConfig and tonumber(curConfig.enemyOffsetY) or 0

      local t = r.transition
      if not t then
        return targetPlayerY, targetEnemyY
      end

      local geom = t.geometry or "immediate"
      if geom == "immediate" then
        return t.toPlayerOffsetY or targetPlayerY, t.toEnemyOffsetY or targetEnemyY
      end

      local progress = 1
      if t.duration and t.duration > 0 then
        progress = math.max(0, math.min(1, (t.elapsed or 0) / t.duration))
      end

      if geom == "after" then
        if progress < 1 then
          return t.fromPlayerOffsetY or 0, t.fromEnemyOffsetY or 0
        else
          return t.toPlayerOffsetY or targetPlayerY, t.toEnemyOffsetY or targetEnemyY
        end
      elseif geom == "lerp" then
        local fromP = t.fromPlayerOffsetY or 0
        local toP = t.toPlayerOffsetY or targetPlayerY
        local fromE = t.fromEnemyOffsetY or 0
        local toE = t.toEnemyOffsetY or targetEnemyY
        local effP = fromP + (toP - fromP) * progress
        local effE = fromE + (toE - fromE) * progress
        return effP, effE
      end

      return targetPlayerY, targetEnemyY
    end,
    setScene=function(battle, sceneId, opts)
      if not battle then return false, "invalid-battle" end
      local r = records[battle]
      if not r then return false, "no-record" end
      opts = opts or {}
      local targetId = sceneId
      if targetId ~= false and scenes[targetId] == nil and customScenes[targetId] == nil then
        warn("setScene:" .. tostring(targetId), "Cannot set unknown backdrop scene: " .. tostring(targetId))
        return false, "unknown-scene"
      end

      local oldId = r.sceneId
      local oldAsset = r.assetPath
      local newAsset = targetId and (scenes[targetId] or (customScenes[targetId] and customScenes[targetId].path)) or nil

      local oldSceneCfg = oldId and shadowSettings.sceneConfig and shadowSettings.sceneConfig(oldId)
      local newSceneCfg = targetId and shadowSettings.sceneConfig and shadowSettings.sceneConfig(targetId)
      local fromPlayerOff = oldSceneCfg and tonumber(oldSceneCfg.playerOffsetY) or 0
      local fromEnemyOff = oldSceneCfg and tonumber(oldSceneCfg.enemyOffsetY) or 0
      local toPlayerOff = newSceneCfg and tonumber(newSceneCfg.playerOffsetY) or 0
      local toEnemyOff = newSceneCfg and tonumber(newSceneCfg.enemyOffsetY) or 0

      local transType = opts.transition or "crossfade"
      local duration = tonumber(opts.duration)
      if duration == nil then
        duration = transType == "cut" and 0 or 0.4
      end

      if transType == "cut" or duration <= 0 or oldId == targetId then
        r.sceneId = targetId
        r.assetPath = newAsset
        r.reason = opts.reason or "api"
        r.transition = nil
        return true, targetId
      end

      r.transition = {
        type = transType,
        geometry = opts.geometry or "immediate",
        fromId = oldId,
        fromAsset = oldAsset,
        toId = targetId,
        toAsset = newAsset,
        fromPlayerOffsetY = fromPlayerOff,
        fromEnemyOffsetY = fromEnemyOff,
        toPlayerOffsetY = toPlayerOff,
        toEnemyOffsetY = toEnemyOff,
        duration = duration,
        elapsed = tonumber(opts.elapsed) or 0,
      }
      r.sceneId = targetId
      r.assetPath = newAsset
      r.reason = opts.reason or "api"
      return true, targetId
    end,
    refresh=function(battle, opts)
      if not battle then return false, "invalid-battle" end
      local r = records[battle]
      if not r or not r.context then return false, "no-record" end
      local oldId = r.sceneId
      local c = r.context
      local default = c.defaultSceneId or BetterBattleBackdrops.resolve(c)
      local selected = default
      local reason = "refresh-default"
      if Runtime.wantsHook("bettermenus.battle_backdrop") then
        selected = Runtime.call("bettermenus.battle_backdrop", function() return default end, c)
        if selected == nil then selected = default end
        if type(selected) == "table" and selected.id then
          local entry = selected
          selected = entry.id
          if entry.image and api and api.backdrop and api.backdrop.registerScene then
            api.backdrop.registerScene(entry.id, entry.image)
          end
        end
        if selected ~= false and not scenes[selected] and not customScenes[selected] then
          selected = default
        elseif selected ~= default then
          reason = "refresh-hook"
        end
      end
      local optTable = opts or {}
      optTable.reason = optTable.reason or reason
      local ok, res = api.backdrop.setScene(battle, selected, optTable)
      if not ok then return false, res end
      local status = (selected ~= oldId) and "changed" or "unchanged"
      return true, selected, status
    end,
    diagnostics=function(battle)
      local r = records[battle]
      if not r then return nil end
      local sceneConfig = r.sceneId and shadowSettings.sceneConfig and shadowSettings.sceneConfig(r.sceneId)
      local effPlayer, effEnemy = api.backdrop.effectiveGroundOffsets(battle)
      local out = { sceneId=r.sceneId, reason=r.reason, assetPath=r.assetPath,
        rendered=r.rendered, inactiveReason=r.inactiveReason,
        fieldTransparent=r.fieldTransparent == true,
        viewportWidth=r.viewportWidth, viewportHeight=r.viewportHeight,
        shadowStyle=r.shadowStyle, shadowCount=#(r.shadows or {}),
        playerOffsetY=sceneConfig and sceneConfig.playerOffsetY or 0,
        enemyOffsetY=sceneConfig and sceneConfig.enemyOffsetY or 0,
        effectivePlayerOffsetY=effPlayer,
        effectiveEnemyOffsetY=effEnemy,
        transitionActive=r.transition ~= nil }
      if r.transition then
        out.transitionType = r.transition.type
        out.transitionGeometry = r.transition.geometry or "immediate"
        out.transitionProgress = r.transition.duration > 0
          and math.min(1, (r.transition.elapsed or 0) / r.transition.duration) or 1
      end
      out.shadows = {}
      for i, shadow in ipairs(r.shadows or {}) do
        out.shadows[i] = {
          side=shadow.side,
          species=shadow.species,
          flying=shadow.flying,
          x=shadow.x,
          y=shadow.y,
          width=shadow.width,
          height=shadow.height,
          alphaScale=shadow.alphaScale,
          sourceX=shadow.sourceX,
          sourceY=shadow.sourceY,
          contactX=shadow.contactX,
          contactY=shadow.contactY
        }
      end
      for _, key in ipairs({"mapId","x","y","surfing","fishing","kind","species",
          "trainerClass","partyIndex","defaultSceneId","tileset"}) do out[key] = r.context[key] end
      return out
    end,
  }
end
return BetterBattleBackdrops
