-- Pixel-art scenes are an outer, true-color layer. Never palette-map this art.
local BetterBattleBackdrops = {}
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
  local ids = {}; for id in pairs(scenes) do ids[#ids+1] = id end
  table.sort(ids); return ids
end

function BetterBattleBackdrops.install(mod, api)
  local BattleState = require("src.battle.BattleState")
  local WideBattle = require("src.battle.WideBattle")
  local Runtime = require("src.mods.Runtime")
  local Renderer = require("src.render.Renderer")
  local records = setmetatable({}, {__mode="k"})
  local images, failures = {}, {}
  local frameBattle, outerCanvas
  local function warn(key, message)
    if not failures[key] then failures[key] = true; mod.log:warn("%s", message) end
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
      if selected ~= false and not scenes[selected] then
        warn("hook:" .. tostring(selected), "Invalid battle backdrop scene: " .. tostring(selected))
        selected = default
      elseif selected ~= default then reason = "hook" end
    end
    records[battle] = { context=c, sceneId=selected, reason=reason,
      assetPath=scenes[selected], rendered=false }
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
  local beginFrame = Renderer.beginFrame
  Renderer.beginFrame = function(self, ...)
    if frameBattle and records[frameBattle] then
      records[frameBattle].rendered = false
      records[frameBattle].fieldTransparent = false
      records[frameBattle].inactiveReason = "not-drawn"
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
    if not imageFor(r) then
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
    local img = imageFor(r)
    if not img then return handled end
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
      g.draw(img, dx, 0, 0, scale, scale)
      if dx > 0 then
        r.leftQuad = r.leftQuad or g.newQuad(0, 0, 1, 180, 320, 180)
        r.rightQuad = r.rightQuad or g.newQuad(319, 0, 1, 180, 320, 180)
        g.draw(img, r.leftQuad, 0, 0, 0, dx, scale)
        g.draw(img, r.rightQuad, w-dx, 0, 0, dx, scale)
      end
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
    diagnostics=function(battle)
      local r = records[battle]
      if not r then return nil end
      local out = { sceneId=r.sceneId, reason=r.reason, assetPath=r.assetPath,
        rendered=r.rendered, inactiveReason=r.inactiveReason,
        fieldTransparent=r.fieldTransparent == true,
        viewportWidth=r.viewportWidth, viewportHeight=r.viewportHeight }
      for _, key in ipairs({"mapId","x","y","surfing","fishing","kind","species",
          "trainerClass","partyIndex","defaultSceneId","tileset"}) do out[key] = r.context[key] end
      return out
    end,
  }
end
return BetterBattleBackdrops
