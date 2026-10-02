-- Two visited Gen 1 maps retain their solo Wild Skies populations. No bird
-- state is written to saves, and no shared-sky provider is registered.
return function(mod, schema)
  if mod.generation and mod.generation ~= 1 then return end

  local Game = require("src.core.Game")
  local OC = require("src.world.OverworldController")
  local KEY = "wild_skies_caching"
  local fields, order = {}, {}
  local api, world, save
  local retired, shared, failed = false, false, false
  local crossing, skipExit, ghostDt = false, false, 1 / 60
  local undo = {}

  local function removeProjections(ow)
    for i = #(ow and ow.ghosts or {}), 1, -1 do
      if ow.ghosts[i].gen1BetterWildSkiesCache then
        table.remove(ow.ghosts, i)
      end
    end
  end

  local function clear()
    removeProjections(world)
    fields, order = {}, {}
  end

  local function enabled()
    return not retired and not failed and not shared and api ~= nil
      and mod.options:get(KEY) ~= false
  end

  local function context(ow)
    if world ~= ow or save ~= Game.save then
      clear()
      world, save = ow, Game.save
      return false
    end
    return true
  end

  local function birds(ow)
    local out = {}
    for _, f in ipairs(ow and ow.entities or {}) do
      if f.wildSkiesFlyer and not f.wildSkiesResidentGhost
          and not f.dead and not f.summonId then
        out[#out + 1] = f
      end
    end
    return out
  end

  local function solo(ow)
    for _, f in ipairs(birds(ow)) do
      if f.sharedReplica or f._sharedRevision ~= nil then return false end
    end
    return true
  end

  local function touch(id)
    for i = #order, 1, -1 do
      if order[i] == id then table.remove(order, i) end
    end
    order[#order + 1] = id
    if #order > 2 then
      fields[table.remove(order, 1)] = nil
    end
  end

  local function remember(ow)
    local id = ow and ow.map and ow.map.id
    if not id then return end
    fields[id] = { birds = birds(ow), projections = {} }
    touch(id)
  end

  local function useMotion(f, ghost)
    if not ghost then return end
    f.px, f.py, f.alt = ghost.px, ghost.py, ghost.alt
    f.vx, f.vy, f.facing = ghost.vx, ghost.vy, ghost.facing
    f.speed = math.sqrt((f.vx or 0) ^ 2 + (f.vy or 0) ^ 2)
    if f.speed > 0 then f.heading = math.atan2(f.vy, f.vx) end
    f.cellX = math.floor(((f.px or 0) + 8) / 16)
    f.cellY = math.floor(((f.py or 0) + 8) / 16)
  end

  local function projection(f)
    local ghost = {}
    for key, value in pairs(f) do ghost[key] = value end
    ghost.wildSkiesResidentGhost = true
    ghost.update = function(self)
      self.t = (self.t or 0) + ghostDt
      if self.mode ~= "ground" then
        local maxX = math.max(0, (self.mapW or 16) - 16)
        local maxY = math.max(0, (self.mapH or 16) - 16)
        self.px = self.px + (self.vx or 0) * ghostDt
        self.py = self.py + (self.vy or 0) * ghostDt
        if self.px <= 0 or self.px >= maxX then
          self.px = math.max(0, math.min(maxX, self.px))
          self.vx = -(self.vx or 0)
        end
        if self.py <= 0 or self.py >= maxY then
          self.py = math.max(0, math.min(maxY, self.py))
          self.vy = -(self.vy or 0)
        end
        if math.abs(self.vx or 0) >= math.abs(self.vy or 0) then
          self.facing = (self.vx or 0) < 0 and "left" or "right"
        else
          self.facing = (self.vy or 0) < 0 and "up" or "down"
        end
      end
      self.cellX = math.floor((self.px + 8) / 16)
      self.cellY = math.floor((self.py + 8) / 16)
    end
    return setmetatable(ghost, getmetatable(f))
  end

  -- Native resident ghosts remain authoritative while they still represent
  -- the cached flock. If Wild Skies reseeds it, project the retained birds
  -- instead, so the flock seen through the seam is the one restored on entry.
  local function neighbors(ow)
    if not (ow and ow.ghosts and ow.neighbors) then return end
    removeProjections(ow)
    for _, neighbor in ipairs(ow.neighbors) do
      local map = neighbor.map
      local field = map and fields[map.id]
      if field and map.id ~= ow.map.id then
        local wanted, native, count = {}, {}, 0
        for _, f in ipairs(field.birds) do
          if not f.dead then wanted[f.id] = f; count = count + 1 end
        end
        local nativeCount, matching = 0, true
        for _, row in ipairs(ow.ghosts) do
          if row.wildSkiesResidentGhost and row.map and row.map.id == map.id then
            local ghost = row.npc
            nativeCount = nativeCount + 1
            if not (ghost and wanted[ghost.id]) then matching = false end
            if ghost then native[ghost.id] = ghost end
          end
        end
        if matching and nativeCount == count then
          field.visuals = native
        else
          for i = #ow.ghosts, 1, -1 do
            local row = ow.ghosts[i]
            if row.wildSkiesResidentGhost and row.map and row.map.id == map.id then
              table.remove(ow.ghosts, i)
            end
          end
          local peers = {}
          for _, f in ipairs(field.birds) do
            if not f.dead then
              local ghost = field.projections[f.id]
              if not ghost then
                useMotion(f, field.visuals and field.visuals[f.id])
                ghost = projection(f)
                field.projections[f.id] = ghost
              end
              peers[#peers + 1] = ghost
            end
          end
          field.visuals = field.projections
          for _, ghost in ipairs(peers) do
            ow.ghosts[#ow.ghosts + 1] = {
              npc = ghost, map = map, ox = neighbor.ox, oy = neighbor.oy,
              peers = peers, wildSkiesResidentGhost = true,
              gen1BetterWildSkiesCache = true,
            }
          end
        end
      end
    end
  end

  local function fail(reason)
    failed = true
    clear()
    mod.log:warn("WildSkies Caching unavailable: %s", tostring(reason))
  end

  local function restore(ow, field)
    local present, wanted, added = {}, {}, {}
    local original = birds(ow)
    for _, f in ipairs(original) do present[f.id] = f end
    for _, f in ipairs(field.birds) do
      if not f.dead then
        wanted[f.id] = true
        if present[f.id] then
          useMotion(present[f.id], field.visuals and field.visuals[f.id])
        end
      end
    end

    for _, f in ipairs(field.birds) do
      if not f.dead and not present[f.id] then
        local class = getmetatable(f)
        if type(class) ~= "table" or class.__index ~= class
            or type(class.new) ~= "function" or type(class.tick) ~= "function"
            or type(class.draw) ~= "function" then
          fail("unsupported bird class")
          return false
        end
      end
    end

    for _, f in ipairs(field.birds) do
      if not f.dead and not present[f.id] then
        useMotion(f, field.visuals and field.visuals[f.id])
        local class, bold = getmetatable(f), f.bold
        local create, delivered = class.new, false
        -- spawnFlyer is the supported insertion path into the private flock.
        -- Supply the retained object only for this synchronous insertion,
        -- then restore the constructor even if the export fails.
        class.new = function(game, live, pick, leader)
          if live == ow and pick.species == f.species and not delivered then
            delivered = true
            return f
          end
          return create(game, live, pick, leader)
        end
        local ok, id = pcall(api.spawnFlyer, f.species, f.level)
        class.new, f.bold = create, bold
        if not ok or not delivered or id ~= f.id then
          if ok and id then pcall(api.removeSharedSkyFieldSpawn, id) end
          for _, live in ipairs(birds(ow)) do
            if live == f then pcall(api.removeSharedSkyFieldSpawn, f.id) end
          end
          for _, addedId in ipairs(added) do
            pcall(api.removeSharedSkyFieldSpawn, addedId)
          end
          fail(ok and "bird insertion refused" or id)
          return false
        end
        added[#added + 1] = id
      end
    end

    for _, f in ipairs(original) do
      if not wanted[f.id] then api.removeSharedSkyFieldSpawn(f.id) end
    end
    return true
  end

  local function entered(ow)
    if not (enabled() and ow and ow.map) then return end
    context(ow)
    if not solo(ow) then shared = true; clear(); return end
    local field = fields[ow.map.id]
    if field and not restore(ow, field) then return end
    remember(ow)
    neighbors(ow)
    skipExit = false
  end

  local function wrap(target, key, callback)
    local original = target[key]
    if type(original) ~= "function" then return end
    local replacement = callback(original)
    target[key] = replacement
    undo[#undo + 1] = function()
      if target[key] == replacement then target[key] = original end
    end
  end

  local function retire()
    retired = true
    clear()
    for i = #undo, 1, -1 do undo[i]() end
  end

  local function detect()
    if retired then return end
    local handle = mod.find("wild_skies")
    if not handle then return end
    if api == handle.exports then return end
    api = handle.exports
    if type(api) ~= "table" or type(api.spawnFlyer) ~= "function"
        or type(api.removeSharedSkyFieldSpawn) ~= "function" then
      api = nil
      return
    end
    local found = false
    for _, row in ipairs(schema) do
      if row.key == KEY then found = true; break end
    end
    if not found then
      schema[#schema + 1] = { key = KEY, label = "WildSkies Caching",
        type = "toggle", default = true }
      mod.options:define(schema)
    end
    wrap(api, "registerSharedSkyProvider", function(original)
      return function(...)
        local ok, reason = original(...)
        if ok then shared = true; clear() end
        return ok, reason
      end
    end)
    wrap(api, "unregisterSharedSkyProvider", function(original)
      return function(...)
        local ok, reason = original(...)
        if ok then shared = false; clear() end
        return ok, reason
      end
    end)
  end

  local control = { retire = retire }
  mod.events:on("mods.loaded", detect, 100)
  mod.events:on("game.ready", function()
    detect()
    if not api or retired then return end
    local previous = OC.__gen1BetterWildSkiesCache
    if previous and previous ~= control then previous.retire() end
    OC.__gen1BetterWildSkiesCache = control
    clear()
    world, save = Game.overworld, Game.save
    wrap(OC, "__wildSkiesCarry", function(original)
      return function(ow, ...)
        crossing = true
        local ok, crossed = pcall(original, ow, ...)
        crossing = false
        if not ok then error(crossed, 0) end
        if crossed then entered(ow) end
        return crossed
      end
    end)
    wrap(OC, "__wildSkiesTick", function(original)
      return function(ow, dt)
        local result = original(ow, dt)
        if enabled() and ow and ow.map then
          if not solo(ow) then shared = true; clear(); return result end
          local same = context(ow)
          if not same or not fields[ow.map.id] then remember(ow) end
          ghostDt = dt or 1 / 60
          neighbors(ow)
        end
        return result
      end
    end)
    entered(Game.overworld)
  end, -100)
  mod.events:on("map.exited", function()
    local ow = Game.overworld
    if enabled() and ow and ow.map and context(ow) and not skipExit then
      if solo(ow) then remember(ow) else shared = true; clear() end
    end
  end, 100)
  mod.events:on("map.entered", function()
    if not crossing then entered(Game.overworld) end
  end, -100)
  mod.events:on("mod.options_changed", function(event)
    if event and event.mod == mod.id and event.key == KEY then clear() end
  end)
  mod.events:on("save.created", function() clear(); skipExit = true end)
  mod.events:on("save.loaded", clear)
  mod.events:on("checkpoint.restored", clear)

  return { retire = retire }
end
