-- Encounter probabilities are conditional on the method producing a battle.
local Indicators = {}

function Indicators.isRare(chance)
  return type(chance) == "number" and chance > 0 and chance <= 0.05
end

function Indicators.slotChance(slots, buckets, species, level)
  if type(slots) ~= "table" or type(buckets) ~= "table"
      or #slots ~= #buckets or buckets[#buckets] ~= 256 then return nil end
  local previous, matching = 0, 0
  for i, threshold in ipairs(buckets) do
    local slot = slots[i]
    if type(threshold) ~= "number" or threshold % 1 ~= 0
        or threshold < previous or threshold > 256
        or type(slot) ~= "table" then return nil end
    if slot.species == species and slot.level == level then
      matching = matching + threshold - previous
    end
    previous = threshold
  end
  return matching / 256
end

function Indicators.fishingChance(pool, always, species, level)
  if always then
    return always.species == species and always.level == level and 1 or 0
  end
  -- The engine's rod roll selects uniformly among up to four candidates.
  if type(pool) ~= "table" or #pool == 0 or #pool > 4 then return nil end
  local matching = 0
  for _, slot in ipairs(pool) do
    if slot.species == species and slot.level == level then
      matching = matching + 1
    end
  end
  return matching / #pool
end

function Indicators.install(mod, enabled)
  local Runtime = require("src.mods.Runtime")
  local FieldDefaults = require("src.world.FieldDefaults")
  local BattleState = require("src.battle.BattleState")
  local origins = setmetatable({}, { __mode = "k" })
  local game, pending

  mod.events:on("game.ready", function(ev)
    game, pending = ev and ev.game, nil
  end)

  local function foreignHook(name)
    for _, entry in ipairs((Runtime.hooks.chains or {})[name] or {}) do
      if entry.owner ~= mod.id then return true end
    end
    return false
  end

  local function remember(enc, map, method, chance, hooked)
    pending = enc and {
      game = game, map = map, method = method, hooked = hooked,
      species = enc.species, level = enc.level, chance = chance,
    } or nil
  end

  mod.hooks:wrap("encounter.roll", function(next, def, ctx)
    pending = nil
    if not enabled() then return next(def, ctx) end
    local enc = next(def, ctx)
    local chance
    if enc and game and ctx and def and def.grass
        and not foreignHook("encounter.roll")
        and not foreignHook("encounter.species") then
      chance = Indicators.slotChance(def.grass.slots,
        def.grass.buckets or FieldDefaults.constant(game.data, "encounterBuckets"),
        enc.species, enc.level)
    end
    remember(enc, ctx and ctx.mapId, ctx and ctx.terrain, chance, false)
    return enc
  end)

  mod.hooks:wrap("encounter.fishing", function(next, rod, map, pool)
    pending = nil
    if not enabled() then return next(rod, map, pool) end
    local enc = next(rod, map, pool)
    local chance
    if enc and game and not foreignHook("encounter.fishing") then
      local def = (FieldDefaults.field(game.data, "fishing") or {})[rod]
      chance = Indicators.fishingChance(pool,
        def and not def.pool and not def.perMap and def.always,
        enc.species, enc.level)
    end
    remember(enc, map, rod, chance, true)
    return enc
  end)

  local originalNewWild = BattleState.newWild
  BattleState.newWild = function(g, species, level, opts, ...)
    local origin = pending
    pending = nil
    local battle = originalNewWild(g, species, level, opts, ...)
    local map = g.overworld and g.overworld.map
    if enabled(battle) and origin and origin.game == g and map and origin.map == map.id
        and origin.species == species and origin.level == level
        and origin.hooked == (opts and opts.hooked == true or false) then
      origins[battle] = origin
    end
    return battle
  end

  return function(battle)
    local origin = origins[battle]
    if not enabled(battle) or battle.kind ~= "wild" or not origin then return false end
    if not origin.hooked then
      local checkpoint = battle.checkpointOrigin
      if not checkpoint or checkpoint.kind ~= "wild_encounter"
          or checkpoint.map ~= origin.map then return false end
    end
    return Indicators.isRare(origin.chance)
  end
end

return Indicators
