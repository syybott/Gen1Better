-- BetterScenes — Story Stage & Narrative Presentation Subsystem
-- 320x180 integer-scaled story canvas, independent from combat states.

local BetterScenes = {}

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
BetterScenes.loadShadowEngine = loadShadowEngine

local RESERVED_PREFIXES = { "gen1_", "better_", "system_" }
local VALID_TRANSITIONS = { cut = true, crossfade = true, flash = true }
local VALID_UNDERLAYS = { black = true, paper = true, transparent = true }

local VALID_ACTOR_TRANSITIONS = { cut = true, fade = true, slide = true }
local VALID_SLIDE_DIRS = { left = true, right = true, top = true, bottom = true }

local DEFAULT_SLOTS = {
  left   = { x = 70,  y = 155, mirror = false, slide = "left" },
  center = { x = 160, y = 155, mirror = false, slide = "bottom" },
  right  = { x = 250, y = 155, mirror = true,  slide = "right" },
}

local DEFAULT_ANCHORS = {
  top   = { x = 0, y = -48 },
  head  = { x = 0, y = -36 },
  mouth = { x = 0, y = -26 },
}

local VALID_BUBBLE_STYLES = { speech = true, thought = true, shout = true }
local VALID_BUBBLE_TRANSITIONS = { cut = true, fade = true, pop = true }
local VALID_SUBTITLE_POSITIONS = { bottom = true, top = true, center = true }
local VALID_SUBTITLE_TRANSITIONS = { cut = true, fade = true }
local VALID_EMOTE_TYPES = {
  exclamation = true,
  question = true,
  sweat = true,
  anger = true,
  heart = true,
  dots = true,
  music = true,
}

local VALID_SHAKE_DIRS = { both = true, horizontal = true, vertical = true }

local TINT_PRESETS = {
  sunset     = { r = 1.0,  g = 0.55, b = 0.2,  a = 0.35 },
  night      = { r = 0.08, g = 0.1,  b = 0.35, a = 0.5 },
  cave       = { r = 0.05, g = 0.05, b = 0.15, a = 0.4 },
  underwater = { r = 0.1,  g = 0.65, b = 0.75, a = 0.35 },
  poison     = { r = 0.55, g = 0.1,  b = 0.65, a = 0.4 },
  sepia      = { r = 0.75, g = 0.55, b = 0.3,  a = 0.3 },
}

local FLASH_PRESETS = {
  white  = { r = 1, g = 1, b = 1 },
  red    = { r = 1, g = 0.1, b = 0.1 },
  yellow = { r = 1, g = 0.9, b = 0.2 },
  black  = { r = 0, g = 0, b = 0 },
}

local VALID_FLASH_MODES = { ["out"] = true, inout = true }
local VALID_FLASH_SCOPES = { stage = true, full = true }

local VALID_VIGNETTE_STYLES = { letterbox = true, spotlight = true, dither = true }

local VALID_WEATHER_TYPES = {
  leaves         = true,
  cherry_blossom = true,
  embers         = true,
  dust           = true,
  rain           = true,
  snow           = true,
}

local VALID_BATTLE_TYPES = { trainer = true, wild = true, boss = true }
local VALID_BATTLE_TRANSITIONS = { cut = true, flash = true, blinds = true, mosaic = true, swirl = true }
local VALID_BATTLE_OUTCOMES = { win = true, lose = true, flee = true, draw = true }

local function createPRNG(seed)
  local s = (type(seed) == "number" and math.floor(seed)) or 1
  if s <= 0 then s = 1 end
  return function()
    s = (s * 1103515245 + 12345) % 2147483648
    return s / 2147483648
  end
end

local CHAR_WIDTH = 6
local LINE_HEIGHT = 8

local function wrapText(text, maxPixelWidth)
  local maxCharsPerLine = math.max(4, math.floor(maxPixelWidth / CHAR_WIDTH))
  local lines = {}
  for rawLine in (text .. "\n"):gmatch("([^\n]*)\n") do
    if #rawLine <= maxCharsPerLine then
      table.insert(lines, rawLine)
    else
      local cur = ""
      for word in rawLine:gmatch("%S+") do
        if cur == "" then
          cur = word
        elseif #cur + 1 + #word <= maxCharsPerLine then
          cur = cur .. " " .. word
        else
          table.insert(lines, cur)
          cur = word
        end
      end
      if cur ~= "" then
        table.insert(lines, cur)
      end
    end
  end
  if #lines == 0 then table.insert(lines, "") end
  return lines
end

local function getOffscreenCoord(dir, targetX, targetY)
  if dir == "left" then
    return -40, targetY
  elseif dir == "right" then
    return 360, targetY
  elseif dir == "top" then
    return targetX, -40
  elseif dir == "bottom" then
    return targetX, 220
  end
  return targetX, 220
end

local function isReservedId(id)
  for _, prefix in ipairs(RESERVED_PREFIXES) do
    if id:sub(1, #prefix) == prefix then
      return true
    end
  end
  return false
end

local function resolveModKey(sourceMod)
  if type(sourceMod) == "string" then return sourceMod end
  if type(sourceMod) == "table" then
    return sourceMod.id
      or (sourceMod.manifest and sourceMod.manifest.id)
      or (sourceMod.info and sourceMod.info.id)
      or sourceMod.name
      or sourceMod.path
      or tostring(sourceMod)
  end
  return "unknown"
end

function BetterScenes.new(options)
  options = options or {}
  local shadowEngine = loadShadowEngine(options.mod)
  local isSelfMod = options.isSelfMod or function() return false end
  local getPalettePaperColor = options.getPalettePaperColor or function() return 1, 1, 1, 1 end

  local registry = {}

  local currentSceneId = nil
  local currentUnderlay = "transparent"
  local transition = nil

  local actors = {}

  local nextBubbleId = 1
  local activeBubble = nil
  local activeSubtitle = nil
  local activeEmotes = {}

  local nextSequenceId = 1
  local activeSequence = nil

  local activeShake = nil
  local activeTint = {
    current = { r = 0, g = 0, b = 0, a = 0 },
    target  = { r = 0, g = 0, b = 0, a = 0 },
    start   = { r = 0, g = 0, b = 0, a = 0 },
    duration = 0,
    elapsed = 0,
  }
  local activeFlash = nil
  local activeVignette = nil
  local activeWeather = nil

  local nextHandoffId = 1
  local activeHandoff = nil
  local internalHandoffCallbacks = nil

  local processSequence = nil

  local loadedImages = {}

  local function getActorImage(actor)
    if not actor then return nil end
    if actor.image then return actor.image end
    if not actor.path then return nil end
    if loadedImages[actor.path] then return loadedImages[actor.path] end

    if love and love.graphics and love.graphics.newImage then
      local ok, img = pcall(love.graphics.newImage, actor.path)
      if ok and img then
        img:setFilter("nearest", "nearest")
        loadedImages[actor.path] = img
        return img
      end
    end
    return nil
  end

  local function getImage(sceneId)
    if not sceneId or type(sceneId) ~= "string" then return nil end
    local entry = registry[sceneId]
    if not entry then return nil end
    if entry.image then return entry.image end
    if not entry.path then return nil end
    if loadedImages[entry.path] then return loadedImages[entry.path] end

    if love and love.graphics and love.graphics.newImage then
      local ok, img = pcall(love.graphics.newImage, entry.path)
      if ok and img then
        img:setFilter("nearest", "nearest")
        loadedImages[entry.path] = img
        return img
      end
    end
    return nil
  end

  local api = {}

  function api.registerScene(id, config, sourceMod)
    if type(id) ~= "string" or id == "" then
      return false, "invalid-scene"
    end
    if type(config) ~= "table" then
      return false, "invalid-scene"
    end
    if not (config.path or config.image) then
      return false, "invalid-scene"
    end

    local modKey = resolveModKey(sourceMod)
    local isSelf = isSelfMod(sourceMod, modKey)

    if isReservedId(id) and not isSelf then
      return false, "reserved-scene"
    end

    local existing = registry[id]
    if existing and existing.modKey ~= modKey then
      return false, "duplicate-scene"
    end

    -- Runtime dimension check if image or love image measurement is available
    if config.image then
      local img = config.image
      local w = (img.getWidth and img:getWidth()) or img.width
      local h = (img.getHeight and img:getHeight()) or img.height
      if w and h and (w ~= 320 or h ~= 180) then
        return false, "invalid-dimensions"
      end
    elseif config.path and love and love.image and love.image.newImageData then
      local ok, data = pcall(love.image.newImageData, config.path)
      if ok and data then
        if data:getWidth() ~= 320 or data:getHeight() ~= 180 then
          return false, "invalid-dimensions"
        end
      end
    end

    registry[id] = {
      id = id,
      path = config.path,
      image = config.image,
      underlay = config.underlay,
      modKey = modKey,
    }

    return true, id
  end

  local function validateOptions(opts)
    if opts == nil then opts = {} end
    if type(opts) ~= "table" then return false, "invalid-options" end

    local trans = opts.transition or "cut"
    if not VALID_TRANSITIONS[trans] then
      return false, "invalid-options"
    end

    if opts.underlay ~= nil and not VALID_UNDERLAYS[opts.underlay] then
      return false, "invalid-options"
    end

    local duration = opts.duration
    if duration ~= nil then
      if type(duration) ~= "number" or duration < 0 then
        return false, "invalid-options"
      end
    end

    if trans == "cut" then
      duration = 0
    else
      if duration == nil then
        duration = 0.35
      elseif duration <= 0 then
        return false, "invalid-options"
      end
    end

    return true, {
      transition = trans,
      duration = duration,
      underlay = opts.underlay,
    }
  end

  local function resolveUnderlay(callsiteUnderlay, targetSceneId)
    if callsiteUnderlay then return callsiteUnderlay end
    if targetSceneId and registry[targetSceneId] and registry[targetSceneId].underlay then
      return registry[targetSceneId].underlay
    end
    if currentSceneId ~= nil and currentUnderlay then
      return currentUnderlay
    end
    return "transparent"
  end

  function api.show(idOrFalse, opts)
    if idOrFalse == nil then
      return false, "invalid-scene"
    end
    if idOrFalse ~= false and type(idOrFalse) ~= "string" then
      return false, "invalid-scene"
    end
    if type(idOrFalse) == "string" and not registry[idOrFalse] then
      return false, "unknown-scene"
    end

    local validOpts, validated = validateOptions(opts)
    if not validOpts then
      return false, validated
    end

    local targetUnderlay = resolveUnderlay(validated.underlay, idOrFalse)
    local transType = validated.transition
    local duration = validated.duration

    if transType == "cut" or (currentSceneId == idOrFalse and currentUnderlay == targetUnderlay) then
      currentSceneId = idOrFalse
      currentUnderlay = targetUnderlay
      transition = nil
      return true, idOrFalse
    end

    -- Endpoint-aware animated transition
    local fromId = currentSceneId
    local toId = idOrFalse
    local fromImg = getImage(fromId)
    local toImg = getImage(toId)
    local fromUnderlay = currentUnderlay

    transition = {
      type = transType,
      duration = duration,
      elapsed = 0,
      startTime = (love and love.timer and love.timer.getTime and love.timer.getTime()) or nil,
      fromId = fromId,
      toId = toId,
      fromImg = fromImg,
      toImg = toImg,
      fromUnderlay = fromUnderlay,
      toUnderlay = targetUnderlay,
      toActive = true,
    }

    currentSceneId = idOrFalse
    currentUnderlay = targetUnderlay
    return true, idOrFalse
  end

  function api.hide(opts)
    -- Idempotent if already fully inactive
    if currentSceneId == nil and transition == nil then
      return true, nil
    end

    local validOpts, validated = validateOptions(opts)
    if not validOpts then
      return false, validated
    end

    local transType = validated.transition
    local duration = validated.duration

    if transType == "cut" then
      currentSceneId = nil
      currentUnderlay = "transparent"
      transition = nil
      return true, nil
    end

    -- Animated transition toward inactive
    local fromId = currentSceneId
    local fromImg = getImage(fromId)
    local fromUnderlay = currentUnderlay

    transition = {
      type = transType,
      duration = duration,
      elapsed = 0,
      startTime = (love and love.timer and love.timer.getTime and love.timer.getTime()) or nil,
      fromId = fromId,
      toId = nil,
      fromImg = fromImg,
      toImg = nil,
      fromUnderlay = fromUnderlay,
      toUnderlay = "transparent",
      toActive = false,
    }

    currentSceneId = nil
    currentUnderlay = "transparent"
    return true, nil
  end

  function api.current()
    return currentSceneId
  end

  function api.isActive()
    return currentSceneId ~= nil
      or transition ~= nil
      or next(actors) ~= nil
      or activeBubble ~= nil
      or activeSubtitle ~= nil
      or next(activeEmotes) ~= nil
      or activeSequence ~= nil
  end

  local function validateActorOpts(opts, defaultSlideDir)
    if opts == nil then opts = {} end
    if type(opts) ~= "table" then return false, "invalid-options" end

    local trans = opts.transition or "cut"
    if not VALID_ACTOR_TRANSITIONS[trans] then
      return false, "invalid-options"
    end

    local duration = opts.duration
    if duration ~= nil then
      if type(duration) ~= "number" or duration < 0 then
        return false, "invalid-options"
      end
    end

    if trans == "cut" then
      duration = 0
    else
      if duration == nil then
        duration = 0.3
      elseif duration <= 0 then
        return false, "invalid-options"
      end
    end

    local slideDir = opts.from or opts.to or defaultSlideDir
    if trans == "slide" and slideDir ~= nil and not VALID_SLIDE_DIRS[slideDir] then
      return false, "invalid-options"
    end

    return true, {
      transition = trans,
      duration = duration,
      slideDir = slideDir,
    }
  end

  function api.setActor(slot, config, opts)
    if slot == nil or type(slot) ~= "string" or slot == "" then
      return false, "invalid-slot"
    end
    if type(config) ~= "table" then
      return false, "invalid-actor"
    end
    if not (config.path or config.image) then
      return false, "invalid-actor"
    end

    local defaultPreset = DEFAULT_SLOTS[slot]
    local targetX = config.x or (defaultPreset and defaultPreset.x)
    local targetY = config.y or (defaultPreset and defaultPreset.y)

    if type(targetX) ~= "number" or type(targetY) ~= "number" then
      return false, "invalid-actor"
    end

    local mirror = config.mirror
    if mirror == nil then
      mirror = defaultPreset and defaultPreset.mirror or false
    else
      mirror = not not mirror
    end

    local scale = config.scale or 1.0
    if type(scale) ~= "number" or scale <= 0 then
      scale = 1.0
    end

    local defaultSlide = defaultPreset and defaultPreset.slide or "bottom"
    local validOpts, validated = validateActorOpts(opts, defaultSlide)
    if not validOpts then
      return false, validated
    end

    local anchors = {}
    for k, v in pairs(DEFAULT_ANCHORS) do
      anchors[k] = { x = v.x, y = v.y }
    end
    if type(config.anchors) == "table" then
      for k, v in pairs(config.anchors) do
        if type(v) == "table" and type(v.x) == "number" and type(v.y) == "number" then
          anchors[k] = { x = v.x, y = v.y }
        end
      end
    end

    local transType = validated.transition
    local duration = validated.duration
    local slideDir = validated.slideDir or defaultSlide

    local shadowCfg = config.shadow
    local shadowState = nil
    if shadowCfg ~= false and (shadowCfg ~= nil or config.species ~= nil) and ShadowEngine then
      local actorImg = config.image or (config.path and loadedImages[config.path])
      shadowState = ShadowEngine.resolveShadowState({
        species = config.species,
        side = "scene",
        image = actorImg,
        config = shadowCfg,
      })
    end

    local transState = nil
    local currentAlpha = 1.0
    local currentX = targetX
    local currentY = targetY

    if transType == "fade" then
      currentAlpha = 0.0
      transState = {
        type = "fade",
        duration = duration,
        elapsed = 0,
        startTime = (love and love.timer and love.timer.getTime and love.timer.getTime()) or nil,
        exiting = false,
        startAlpha = 0.0,
        targetAlpha = 1.0,
      }
    elseif transType == "slide" then
      local offX, offY = getOffscreenCoord(slideDir, targetX, targetY)
      currentX = offX
      currentY = offY
      transState = {
        type = "slide",
        duration = duration,
        elapsed = 0,
        startTime = (love and love.timer and love.timer.getTime and love.timer.getTime()) or nil,
        exiting = false,
        startX = offX,
        startY = offY,
        targetX = targetX,
        targetY = targetY,
      }
    end

    actors[slot] = {
      slot = slot,
      x = targetX,
      y = targetY,
      currentX = currentX,
      currentY = currentY,
      currentAlpha = currentAlpha,
      mirror = mirror,
      scale = scale,
      pose = config.pose or "idle",
      path = config.path,
      image = config.image,
      anchors = anchors,
      species = config.species,
      shadow = shadowCfg,
      shadowState = shadowState,
      transition = transState,
    }

    return true, slot
  end

  function api.clearActor(slot, opts)
    if slot == nil or type(slot) ~= "string" or slot == "" then
      return false, "invalid-slot"
    end

    local actor = actors[slot]
    if not actor then
      return true, nil
    end

    if actor.transition and actor.transition.exiting then
      return true, slot
    end

    local defaultSlide = (DEFAULT_SLOTS[slot] and DEFAULT_SLOTS[slot].slide) or "bottom"
    local validOpts, validated = validateActorOpts(opts, defaultSlide)
    if not validOpts then
      return false, validated
    end

    local transType = validated.transition
    local duration = validated.duration
    local slideDir = validated.slideDir or defaultSlide

    if transType == "cut" then
      actors[slot] = nil
      return true, slot
    end

    if transType == "fade" then
      actor.transition = {
        type = "fade",
        duration = duration,
        elapsed = 0,
        startTime = (love and love.timer and love.timer.getTime and love.timer.getTime()) or nil,
        exiting = true,
        startAlpha = actor.currentAlpha or 1.0,
        targetAlpha = 0.0,
      }
    elseif transType == "slide" then
      local offX, offY = getOffscreenCoord(slideDir, actor.x, actor.y)
      actor.transition = {
        type = "slide",
        duration = duration,
        elapsed = 0,
        startTime = (love and love.timer and love.timer.getTime and love.timer.getTime()) or nil,
        exiting = true,
        startX = actor.currentX or actor.x,
        startY = actor.currentY or actor.y,
        targetX = offX,
        targetY = offY,
      }
    end

    return true, slot
  end

  function api.clearActors(opts)
    local slotsToClear = {}
    for slot, _ in pairs(actors) do
      table.insert(slotsToClear, slot)
    end

    local count = 0
    for _, slot in ipairs(slotsToClear) do
      local ok, res = api.clearActor(slot, opts)
      if ok and res ~= nil then
        count = count + 1
      end
    end

    return true, count
  end

  function api.getActor(slot)
    if slot == nil or type(slot) ~= "string" then return nil end
    local actor = actors[slot]
    if not actor then return nil end

    return {
      slot = actor.slot,
      x = actor.x,
      y = actor.y,
      mirror = actor.mirror,
      scale = actor.scale,
      pose = actor.pose or "idle",
      imagePath = actor.path,
      species = actor.species,
      shadow = actor.shadow,
      shadowState = actor.shadowState,
      transitionActive = (actor.transition ~= nil),
      exiting = (actor.transition and actor.transition.exiting) or false,
    }
  end

  function api.getActorAnchor(slot, anchorName)
    if slot == nil or type(slot) ~= "string" then
      return nil, "invalid-slot"
    end
    local actor = actors[slot]
    if not actor then
      return nil, "actor-not-found"
    end
    if type(anchorName) ~= "string" or anchorName == "" then
      return nil, "invalid-anchor"
    end
    local anchor = actor.anchors and actor.anchors[anchorName]
    if not anchor then
      return nil, "invalid-anchor"
    end

    local resolvedX = actor.x + ((actor.mirror and -anchor.x or anchor.x) * actor.scale)
    local resolvedY = actor.y + (anchor.y * actor.scale)
    return resolvedX, resolvedY
  end

  local function resolveSpeakerAnchor(speaker, anchorName)
    if speaker == nil or speaker == "narrator" then
      return nil, nil, "none"
    end
    if type(speaker) == "table" then
      if type(speaker.x) == "number" and type(speaker.y) == "number" then
        return speaker.x, speaker.y, "coord"
      else
        return nil, nil, "invalid-speaker"
      end
    end
    if type(speaker) == "string" then
      local actor = actors[speaker]
      if not actor then
        return nil, nil, "invalid-speaker"
      end
      local aname = anchorName or "mouth"
      local ax, ay = api.getActorAnchor(speaker, aname)
      if not ax then
        return nil, nil, "invalid-anchor"
      end
      return ax, ay, "actor"
    end
    return nil, nil, "invalid-speaker"
  end

  function api.showBubble(speaker, text, opts)
    if text == nil or type(text) ~= "string" or text == "" then
      return false, "invalid-text"
    end
    opts = opts or {}
    if type(opts) ~= "table" then
      return false, "invalid-options"
    end

    local style = opts.style or "speech"
    if not VALID_BUBBLE_STYLES[style] then
      return false, "invalid-options"
    end

    local trans = opts.transition or "cut"
    if not VALID_BUBBLE_TRANSITIONS[trans] then
      return false, "invalid-options"
    end

    local duration = opts.duration
    if duration ~= nil then
      if type(duration) ~= "number" or duration <= 0 then
        return false, "invalid-options"
      end
    end

    local anchorName = opts.anchor or "mouth"
    local targetX, targetY, speakerType = resolveSpeakerAnchor(speaker, anchorName)
    if speakerType == "invalid-speaker" then
      return false, "invalid-speaker"
    elseif speakerType == "invalid-anchor" then
      return false, "invalid-anchor"
    end

    local maxWidth = opts.maxWidth or 180
    local padding = opts.padding or 6

    local lines = wrapText(text, maxWidth - padding * 2)
    local maxChars = 0
    for _, l in ipairs(lines) do
      if #l > maxChars then maxChars = #l end
    end
    local textWidth = maxChars * CHAR_WIDTH
    local textHeight = #lines * LINE_HEIGHT
    local bubbleWidth = math.max(36, textWidth + padding * 2)
    local bubbleHeight = math.max(20, textHeight + padding * 2)

    local bubbleX, bubbleY
    if speakerType == "none" then
      bubbleX = math.floor((320 - bubbleWidth) / 2)
      bubbleY = 20
    else
      if targetY > 70 then
        bubbleY = targetY - bubbleHeight - 12
      else
        bubbleY = targetY + 12
      end
      bubbleX = math.floor(targetX - bubbleWidth / 2)
    end

    -- Clamp strictly within stage boundaries [4, 4, 316, 176]
    bubbleX = math.max(4, math.min(316 - bubbleWidth, bubbleX))
    bubbleY = math.max(4, math.min(176 - bubbleHeight, bubbleY))

    local hasTail = (speakerType ~= "none") and (opts.tail ~= false)
    local tailRootX, tailRootY
    if hasTail then
      if bubbleY + bubbleHeight <= targetY then
        tailRootY = bubbleY + bubbleHeight
        tailRootX = math.max(bubbleX + 6, math.min(bubbleX + bubbleWidth - 6, targetX))
      elseif bubbleY >= targetY then
        tailRootY = bubbleY
        tailRootX = math.max(bubbleX + 6, math.min(bubbleX + bubbleWidth - 6, targetX))
      else
        tailRootY = bubbleY + math.floor(bubbleHeight / 2)
        tailRootX = (targetX < bubbleX) and bubbleX or (bubbleX + bubbleWidth)
      end
    end

    local bubbleId = nextBubbleId
    nextBubbleId = nextBubbleId + 1

    local transState = nil
    if trans == "fade" or trans == "pop" then
      transState = {
        type = trans,
        duration = 0.2,
        elapsed = 0,
        startTime = (love and love.timer and love.timer.getTime and love.timer.getTime()) or nil,
        exiting = false,
      }
    end

    activeBubble = {
      id = bubbleId,
      speaker = speaker,
      speakerType = speakerType,
      anchorName = anchorName,
      text = text,
      lines = lines,
      style = style,
      x = bubbleX,
      y = bubbleY,
      width = bubbleWidth,
      height = bubbleHeight,
      hasTail = hasTail,
      tailTargetX = targetX,
      tailTargetY = targetY,
      tailRootX = tailRootX,
      tailRootY = tailRootY,
      padding = padding,
      duration = duration,
      elapsed = 0,
      transition = transState,
      currentAlpha = (trans == "fade") and 0.0 or 1.0,
      currentScale = (trans == "pop") and 0.7 or 1.0,
    }

    return true, bubbleId
  end

  function api.hideBubble(opts)
    if not activeBubble or (activeBubble.transition and activeBubble.transition.exiting) then
      return true, nil
    end

    opts = opts or {}
    local trans = opts.transition or "cut"
    if not VALID_BUBBLE_TRANSITIONS[trans] then
      return false, "invalid-options"
    end

    if trans == "cut" then
      activeBubble = nil
      return true, nil
    end

    activeBubble.transition = {
      type = trans,
      duration = 0.2,
      elapsed = 0,
      startTime = (love and love.timer and love.timer.getTime and love.timer.getTime()) or nil,
      exiting = true,
      startAlpha = activeBubble.currentAlpha or 1.0,
      startScale = activeBubble.currentScale or 1.0,
    }
    return true, nil
  end

  function api.getBubble()
    if not activeBubble then return nil end

    local targetX = activeBubble.tailTargetX
    local targetY = activeBubble.tailTargetY
    if activeBubble.speakerType == "actor" and actors[activeBubble.speaker] then
      local liveX, liveY = api.getActorAnchor(activeBubble.speaker, activeBubble.anchorName)
      if liveX and liveY then
        targetX = liveX
        targetY = liveY
        activeBubble.tailTargetX = liveX
        activeBubble.tailTargetY = liveY
      end
    end

    return {
      active = true,
      id = activeBubble.id,
      speaker = activeBubble.speaker,
      speakerType = activeBubble.speakerType,
      text = activeBubble.text,
      style = activeBubble.style,
      x = activeBubble.x,
      y = activeBubble.y,
      width = activeBubble.width,
      height = activeBubble.height,
      hasTail = activeBubble.hasTail,
      tailTargetX = targetX,
      tailTargetY = targetY,
      tailRootX = activeBubble.tailRootX,
      tailRootY = activeBubble.tailRootY,
      transitionActive = (activeBubble.transition ~= nil),
      exiting = (activeBubble.transition and activeBubble.transition.exiting) or false,
    }
  end

  function api.setSubtitle(text, opts)
    if text == nil or type(text) ~= "string" or text == "" then
      return false, "invalid-text"
    end
    opts = opts or {}
    if type(opts) ~= "table" then
      return false, "invalid-options"
    end

    local pos = opts.position or "bottom"
    if not VALID_SUBTITLE_POSITIONS[pos] then
      return false, "invalid-options"
    end

    local trans = opts.transition or "cut"
    if not VALID_SUBTITLE_TRANSITIONS[trans] then
      return false, "invalid-options"
    end

    local duration = opts.duration
    if duration ~= nil and (type(duration) ~= "number" or duration <= 0) then
      return false, "invalid-options"
    end

    local bar = (opts.bar ~= false)
    local align = opts.align or "center"

    local transState = nil
    if trans == "fade" then
      transState = {
        type = "fade",
        duration = 0.25,
        elapsed = 0,
        startTime = (love and love.timer and love.timer.getTime and love.timer.getTime()) or nil,
        exiting = false,
      }
    end

    activeSubtitle = {
      text = text,
      position = pos,
      bar = bar,
      align = align,
      duration = duration,
      elapsed = 0,
      transition = transState,
      currentAlpha = (trans == "fade") and 0.0 or 1.0,
    }

    return true, nil
  end

  function api.clearSubtitle(opts)
    if not activeSubtitle or (activeSubtitle.transition and activeSubtitle.transition.exiting) then
      return true, nil
    end
    opts = opts or {}
    local trans = opts.transition or "cut"
    if not VALID_SUBTITLE_TRANSITIONS[trans] then
      return false, "invalid-options"
    end

    if trans == "cut" then
      activeSubtitle = nil
      return true, nil
    end

    activeSubtitle.transition = {
      type = "fade",
      duration = 0.25,
      elapsed = 0,
      startTime = (love and love.timer and love.timer.getTime and love.timer.getTime()) or nil,
      exiting = true,
      startAlpha = activeSubtitle.currentAlpha or 1.0,
    }
    return true, nil
  end

  function api.getSubtitle()
    if not activeSubtitle then return nil end
    return {
      active = true,
      text = activeSubtitle.text,
      position = activeSubtitle.position,
      bar = activeSubtitle.bar,
      align = activeSubtitle.align,
      transitionActive = (activeSubtitle.transition ~= nil),
      exiting = (activeSubtitle.transition and activeSubtitle.transition.exiting) or false,
    }
  end

  function api.showEmote(target, emoteType, opts)
    if target == nil then
      return false, "invalid-target"
    end
    if type(target) == "string" and not actors[target] then
      return false, "invalid-target"
    end
    if type(target) == "table" and (type(target.x) ~= "number" or type(target.y) ~= "number") then
      return false, "invalid-target"
    end
    if emoteType == nil or not VALID_EMOTE_TYPES[emoteType] then
      return false, "invalid-emote"
    end

    opts = opts or {}
    local duration = opts.duration
    if duration ~= nil and (type(duration) ~= "number" or duration <= 0) then
      return false, "invalid-options"
    end

    local targetKey = (type(target) == "string") and target or string.format("coord_%d_%d", target.x, target.y)

    activeEmotes[targetKey] = {
      target = target,
      targetKey = targetKey,
      emoteType = emoteType,
      duration = duration,
      elapsed = 0,
      bounce = (opts.bounce ~= false),
    }

    return true, targetKey
  end

  function api.clearEmote(target)
    if target == nil then
      local count = 0
      for _, _ in pairs(activeEmotes) do
        count = count + 1
      end
      activeEmotes = {}
      return true, count
    end

    local targetKey = (type(target) == "string") and target or string.format("coord_%d_%d", target.x, target.y)
    if activeEmotes[targetKey] then
      activeEmotes[targetKey] = nil
      return true, 1
    end
    return true, 0
  end

  function api.getEmotes()
    local out = {}
    for k, v in pairs(activeEmotes) do
      local originX, originY
      if type(v.target) == "string" and actors[v.target] then
        originX, originY = api.getActorAnchor(v.target, "top")
      elseif type(v.target) == "table" then
        originX, originY = v.target.x, v.target.y
      end
      out[k] = {
        target = v.target,
        emoteType = v.emoteType,
        x = originX or 0,
        y = originY or 0,
        duration = v.duration,
      }
    end
    return out
  end

  -- =========================================================================
  -- Horizon 4: 320x180 Stage FX & Camera Dynamics
  -- =========================================================================

  function api.shakeScreen(opts)
    opts = opts or {}
    if type(opts) ~= "table" then
      return false, "invalid-options"
    end
    local intensity = opts.intensity or 4
    if type(intensity) ~= "number" or intensity <= 0 then
      return false, "invalid-options"
    end
    local duration = opts.duration or 0.4
    if type(duration) ~= "number" or duration <= 0 then
      return false, "invalid-options"
    end
    local frequency = opts.frequency or 24
    if type(frequency) ~= "number" or frequency <= 0 then
      return false, "invalid-options"
    end
    local dir = opts.direction or "both"
    if not VALID_SHAKE_DIRS[dir] then
      return false, "invalid-options"
    end

    local pixelSnap = (opts.pixelSnap ~= false)
    local shakeUI = (opts.shakeUI == true)

    activeShake = {
      intensity = intensity,
      duration = duration,
      frequency = frequency,
      direction = dir,
      pixelSnap = pixelSnap,
      shakeUI = shakeUI,
      elapsed = 0,
      offsetX = 0,
      offsetY = 0,
    }

    local step = 0
    local decay = 1.0
    local nx = math.sin(step * 1.7 + 0.3) * math.cos(step * 0.9 + 1.1)
    local ny = math.cos(step * 1.3 + 0.7) * math.sin(step * 1.1 + 0.5)
    local rawX = (dir == "vertical") and 0 or (nx * intensity * decay)
    local rawY = (dir == "horizontal") and 0 or (ny * intensity * decay)
    if pixelSnap then
      activeShake.offsetX = math.floor(rawX + (rawX >= 0 and 0.5 or -0.5))
      activeShake.offsetY = math.floor(rawY + (rawY >= 0 and 0.5 or -0.5))
    else
      activeShake.offsetX = rawX
      activeShake.offsetY = rawY
    end

    return true, nil
  end

  function api.stopShake()
    activeShake = nil
    return true, nil
  end

  function api.getShake()
    if not activeShake then
      return {
        active = false,
        intensity = 0,
        duration = 0,
        elapsed = 0,
        frequency = 0,
        direction = "both",
        pixelSnap = true,
        shakeUI = false,
        offsetX = 0,
        offsetY = 0,
      }
    end
    return {
      active = true,
      intensity = activeShake.intensity,
      duration = activeShake.duration,
      elapsed = activeShake.elapsed,
      frequency = activeShake.frequency,
      direction = activeShake.direction,
      pixelSnap = activeShake.pixelSnap,
      shakeUI = activeShake.shakeUI,
      offsetX = activeShake.offsetX,
      offsetY = activeShake.offsetY,
    }
  end

  local function resolveTintColor(colorOrPreset)
    if type(colorOrPreset) == "string" then
      local p = TINT_PRESETS[colorOrPreset]
      if not p then return nil end
      return { r = p.r, g = p.g, b = p.b, a = p.a }
    elseif type(colorOrPreset) == "table" then
      local r = colorOrPreset.r or colorOrPreset[1]
      local g = colorOrPreset.g or colorOrPreset[2]
      local b = colorOrPreset.b or colorOrPreset[3]
      local a = colorOrPreset.a or colorOrPreset[4]
      if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" or type(a) ~= "number" then
        return nil
      end
      return {
        r = math.max(0, math.min(1, r)),
        g = math.max(0, math.min(1, g)),
        b = math.max(0, math.min(1, b)),
        a = math.max(0, math.min(1, a)),
      }
    end
    return nil
  end

  function api.setTint(colorOrPreset, opts)
    local c = resolveTintColor(colorOrPreset)
    if not c then
      return false, "invalid-tint"
    end
    opts = opts or {}
    if type(opts) ~= "table" then
      return false, "invalid-options"
    end
    local duration = opts.duration or 0
    if type(duration) ~= "number" or duration < 0 then
      return false, "invalid-options"
    end

    if duration == 0 then
      activeTint.current = { r = c.r, g = c.g, b = c.b, a = c.a }
      activeTint.target = { r = c.r, g = c.g, b = c.b, a = c.a }
      activeTint.start = { r = c.r, g = c.g, b = c.b, a = c.a }
      activeTint.duration = 0
      activeTint.elapsed = 0
    else
      activeTint.start = {
        r = activeTint.current.r,
        g = activeTint.current.g,
        b = activeTint.current.b,
        a = activeTint.current.a,
      }
      activeTint.target = { r = c.r, g = c.g, b = c.b, a = c.a }
      activeTint.duration = duration
      activeTint.elapsed = 0
    end
    return true, nil
  end

  function api.clearTint(opts)
    opts = opts or {}
    if type(opts) ~= "table" then
      return false, "invalid-options"
    end
    local duration = opts.duration or 0
    if type(duration) ~= "number" or duration < 0 then
      return false, "invalid-options"
    end
    return api.setTint({ r = 0, g = 0, b = 0, a = 0 }, { duration = duration })
  end

  function api.getTint()
    local isTrans = (activeTint.duration > 0 and activeTint.elapsed < activeTint.duration)
    local isActive = (activeTint.current.a > 0) or (activeTint.target.a > 0) or isTrans
    return {
      active = isActive,
      r = activeTint.current.r,
      g = activeTint.current.g,
      b = activeTint.current.b,
      a = activeTint.current.a,
      target = {
        r = activeTint.target.r,
        g = activeTint.target.g,
        b = activeTint.target.b,
        a = activeTint.target.a,
      },
      duration = activeTint.duration,
      elapsed = activeTint.elapsed,
      transitionActive = isTrans,
    }
  end

  local function resolveFlashColor(colorOrPreset)
    if type(colorOrPreset) == "string" then
      local p = FLASH_PRESETS[colorOrPreset]
      if not p then return nil end
      return { r = p.r, g = p.g, b = p.b }
    elseif type(colorOrPreset) == "table" then
      local r = colorOrPreset.r or colorOrPreset[1]
      local g = colorOrPreset.g or colorOrPreset[2]
      local b = colorOrPreset.b or colorOrPreset[3]
      if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
        return nil
      end
      return {
        r = math.max(0, math.min(1, r)),
        g = math.max(0, math.min(1, g)),
        b = math.max(0, math.min(1, b)),
      }
    end
    return nil
  end

  function api.flashScreen(colorOrPreset, opts)
    local c = resolveFlashColor(colorOrPreset or "white")
    if not c then
      return false, "invalid-flash"
    end
    opts = opts or {}
    if type(opts) ~= "table" then
      return false, "invalid-options"
    end
    local duration = opts.duration or 0.3
    if type(duration) ~= "number" or duration <= 0 then
      return false, "invalid-options"
    end
    local mode = opts.mode or "out"
    if not VALID_FLASH_MODES[mode] then
      return false, "invalid-options"
    end
    local scope = opts.scope or "stage"
    if not VALID_FLASH_SCOPES[scope] then
      return false, "invalid-options"
    end

    activeFlash = {
      r = c.r,
      g = c.g,
      b = c.b,
      duration = duration,
      elapsed = 0,
      mode = mode,
      scope = scope,
      alpha = (mode == "out") and 1.0 or 0.0,
    }
    return true, nil
  end

  function api.stopFlash()
    activeFlash = nil
    return true, nil
  end

  function api.getFlash()
    if not activeFlash then
      return {
        active = false,
        r = 0, g = 0, b = 0,
        alpha = 0,
        duration = 0,
        elapsed = 0,
        mode = "out",
        scope = "stage",
      }
    end
    return {
      active = true,
      r = activeFlash.r,
      g = activeFlash.g,
      b = activeFlash.b,
      alpha = activeFlash.alpha,
      duration = activeFlash.duration,
      elapsed = activeFlash.elapsed,
      mode = activeFlash.mode,
      scope = activeFlash.scope,
    }
  end

  function api.setVignette(style, opts)
    if type(style) ~= "string" or not VALID_VIGNETTE_STYLES[style] then
      return false, "invalid-style"
    end
    opts = opts or {}
    if type(opts) ~= "table" then
      return false, "invalid-options"
    end
    local duration = opts.duration or 0
    if type(duration) ~= "number" or duration < 0 then
      return false, "invalid-options"
    end
    local targetAlpha = opts.alpha or 0.75
    if type(targetAlpha) ~= "number" or targetAlpha < 0 or targetAlpha > 1 then
      return false, "invalid-options"
    end

    local color = opts.color or { 0, 0, 0 }
    local r, g, b = 0, 0, 0
    if type(color) == "table" then
      r = color.r or color[1] or 0
      g = color.g or color[2] or 0
      b = color.b or color[3] or 0
    end

    local target = opts.target or "center"
    local radius = opts.radius or 80

    local startAlpha = (activeVignette and activeVignette.alpha) or 0.0
    local curAlpha = (duration == 0) and targetAlpha or startAlpha

    activeVignette = {
      style = style,
      r = r, g = g, b = b,
      alpha = curAlpha,
      startAlpha = startAlpha,
      targetAlpha = targetAlpha,
      target = target,
      radius = radius,
      duration = duration,
      elapsed = 0,
      exiting = false,
    }
    return true, nil
  end

  function api.clearVignette(opts)
    if not activeVignette then
      return true, nil
    end
    opts = opts or {}
    if type(opts) ~= "table" then
      return false, "invalid-options"
    end
    local duration = opts.duration or 0
    if type(duration) ~= "number" or duration < 0 then
      return false, "invalid-options"
    end

    if duration == 0 then
      activeVignette = nil
      return true, nil
    end

    activeVignette.startAlpha = activeVignette.alpha
    activeVignette.targetAlpha = 0.0
    activeVignette.duration = duration
    activeVignette.elapsed = 0
    activeVignette.exiting = true
    return true, nil
  end

  function api.getVignette()
    if not activeVignette then
      return {
        active = false,
        style = nil,
        r = 0, g = 0, b = 0,
        alpha = 0,
        target = nil,
        radius = 0,
        transitionActive = false,
        exiting = false,
      }
    end
    local isTrans = (activeVignette.duration > 0 and activeVignette.elapsed < activeVignette.duration)
    return {
      active = (activeVignette.alpha > 0 or isTrans),
      style = activeVignette.style,
      r = activeVignette.r,
      g = activeVignette.g,
      b = activeVignette.b,
      alpha = activeVignette.alpha,
      target = activeVignette.target,
      radius = activeVignette.radius,
      transitionActive = isTrans,
      exiting = activeVignette.exiting,
    }
  end

  function api.setWeather(weatherType, opts)
    if type(weatherType) ~= "string" or not VALID_WEATHER_TYPES[weatherType] then
      return false, "invalid-weather"
    end
    opts = opts or {}
    if type(opts) ~= "table" then
      return false, "invalid-options"
    end
    local speed = opts.speed or 1.0
    if type(speed) ~= "number" or speed <= 0 then
      return false, "invalid-options"
    end
    local seed = opts.seed or 1
    if type(seed) ~= "number" then
      return false, "invalid-options"
    end
    local count = opts.count or 20
    if type(count) ~= "number" or count <= 0 then
      return false, "invalid-options"
    end
    count = math.floor(count)

    local duration = opts.duration or 0
    if type(duration) ~= "number" or duration < 0 then
      return false, "invalid-options"
    end

    local prng = createPRNG(seed)
    local particles = {}
    for i = 1, count do
      local px = prng() * 320
      local py = prng() * 180
      local pvx, pvy, size, phase
      if weatherType == "rain" then
        pvx = -15 * speed
        pvy = (140 + prng() * 40) * speed
        size = 4 + math.floor(prng() * 3)
        phase = 0
      elseif weatherType == "snow" then
        pvx = (prng() * 12 - 6) * speed
        pvy = (18 + prng() * 14) * speed
        size = 1 + (prng() > 0.6 and 1 or 0)
        phase = prng() * 6.28
      elseif weatherType == "leaves" or weatherType == "cherry_blossom" then
        pvx = (20 + prng() * 20) * speed
        pvy = (25 + prng() * 15) * speed
        size = 2
        phase = prng() * 6.28
      elseif weatherType == "embers" then
        pvx = (prng() * 10 - 5) * speed
        pvy = -(25 + prng() * 20) * speed
        size = 1 + (prng() > 0.7 and 1 or 0)
        phase = prng() * 6.28
      elseif weatherType == "dust" then
        pvx = (prng() * 8 - 4) * speed
        pvy = (prng() * 8 - 4) * speed
        size = 1
        phase = prng() * 6.28
      end
      table.insert(particles, {
        x = px,
        y = py,
        vx = pvx,
        vy = pvy,
        size = size,
        phase = phase,
        initX = px,
        initY = py,
      })
    end

    activeWeather = {
      weatherType = weatherType,
      count = count,
      speed = speed,
      seed = seed,
      particles = particles,
      alpha = (duration == 0) and 1.0 or 0.0,
      startAlpha = (duration == 0) and 1.0 or 0.0,
      targetAlpha = 1.0,
      duration = duration,
      elapsed = 0,
      exiting = false,
    }
    return true, nil
  end

  function api.clearWeather(opts)
    if not activeWeather then
      return true, nil
    end
    opts = opts or {}
    if type(opts) ~= "table" then
      return false, "invalid-options"
    end
    local duration = opts.duration or 0
    if type(duration) ~= "number" or duration < 0 then
      return false, "invalid-options"
    end

    if duration == 0 then
      activeWeather = nil
      return true, nil
    end

    activeWeather.startAlpha = activeWeather.alpha
    activeWeather.targetAlpha = 0.0
    activeWeather.duration = duration
    activeWeather.elapsed = 0
    activeWeather.exiting = true
    return true, nil
  end

  function api.getWeather()
    if not activeWeather then
      return {
        active = false,
        weatherType = nil,
        count = 0,
        speed = 0,
        seed = 1,
        alpha = 0,
        transitionActive = false,
        exiting = false,
        particles = {},
      }
    end
    local isTrans = (activeWeather.duration > 0 and activeWeather.elapsed < activeWeather.duration)
    local pCopy = {}
    for i, p in ipairs(activeWeather.particles) do
      pCopy[i] = { x = p.x, y = p.y, vx = p.vx, vy = p.vy, size = p.size }
    end
    return {
      active = (activeWeather.alpha > 0 or isTrans),
      weatherType = activeWeather.weatherType,
      count = activeWeather.count,
      speed = activeWeather.speed,
      seed = activeWeather.seed,
      alpha = activeWeather.alpha,
      transitionActive = isTrans,
      exiting = activeWeather.exiting,
      particles = pCopy,
    }
  end

  -- =========================================================================
  -- Horizon 5: Decoupled Battle Handoff
  -- =========================================================================

  function api.prepareBattleHandoff(opts)
    if activeHandoff and (activeHandoff.state == "prepared" or activeHandoff.state == "transitioning" or activeHandoff.state == "handed_off") then
      return false, "handoff-active"
    end

    opts = opts or {}
    if type(opts) ~= "table" then
      return false, "invalid-options"
    end

    local bType = opts.battleType or "trainer"
    if not VALID_BATTLE_TYPES[bType] then
      return false, "invalid-options"
    end

    local trans = opts.transition or "swirl"
    if not VALID_BATTLE_TRANSITIONS[trans] then
      return false, "invalid-options"
    end

    local dur = opts.duration or (trans == "cut" and 0 or 0.8)
    if type(dur) ~= "number" or dur < 0 then
      return false, "invalid-options"
    end

    local handoffId = string.format("bh_%d", nextHandoffId)
    nextHandoffId = nextHandoffId + 1

    local curTint = api.getTint()
    local curWeather = api.getWeather()

    local transferableAtmosphere = {
      underlay = currentUnderlay,
      tint = curTint.active and { r = curTint.r, g = curTint.g, b = curTint.b, a = curTint.a } or nil,
      weather = curWeather.active and {
        weatherType = curWeather.weatherType,
        count = curWeather.count,
        speed = curWeather.speed,
      } or nil,
      music = opts.music,
    }

    local isInstant = (trans == "cut" or dur == 0)
    local initialState = isInstant and "handed_off" or "transitioning"
    local initialProgress = isInstant and 1.0 or 0.0

    activeHandoff = {
      id = handoffId,
      source = "better_scenes",
      state = initialState,
      storySceneId = currentSceneId,
      battleBackdropId = opts.battleBackdropId or opts.backdropId or currentSceneId,
      battleType = bType,
      trainerId = opts.trainerId,
      species = opts.species,
      level = opts.level,
      music = opts.music,
      atmosphere = transferableAtmosphere,
      transition = trans,
      duration = dur,
      elapsed = 0,
      transitionProgress = initialProgress,
      outcome = nil,
    }

    internalHandoffCallbacks = {
      onHandoff = opts.onHandoff,
      onWin = opts.onWin,
      onLose = opts.onLose,
      onFlee = opts.onFlee,
      onReturn = opts.onReturn,
    }

    if isInstant and internalHandoffCallbacks.onHandoff then
      local ok, err = pcall(internalHandoffCallbacks.onHandoff, api.getBattleHandoff())
      if not ok then
        activeHandoff.lastError = "handoff-error"
      end
    end

    return true, api.getBattleHandoff()
  end

  function api.getBattleHandoff()
    if not activeHandoff then return nil end
    local h = activeHandoff
    return {
      id = h.id,
      source = h.source,
      state = h.state,
      storySceneId = h.storySceneId,
      battleBackdropId = h.battleBackdropId,
      battleType = h.battleType,
      trainerId = h.trainerId,
      species = h.species,
      level = h.level,
      music = h.music,
      atmosphere = {
        underlay = h.atmosphere and h.atmosphere.underlay,
        tint = h.atmosphere and h.atmosphere.tint and {
          r = h.atmosphere.tint.r,
          g = h.atmosphere.tint.g,
          b = h.atmosphere.tint.b,
          a = h.atmosphere.tint.a,
        },
        weather = h.atmosphere and h.atmosphere.weather and {
          weatherType = h.atmosphere.weather.weatherType,
          count = h.atmosphere.weather.count,
          speed = h.atmosphere.weather.speed,
        },
        music = h.atmosphere and h.atmosphere.music,
      },
      transition = h.transition,
      duration = h.duration,
      elapsed = h.elapsed,
      transitionProgress = h.transitionProgress,
      outcome = h.outcome,
    }
  end

  function api.cancelBattleHandoff()
    if not activeHandoff or activeHandoff.state == "returned" or activeHandoff.state == "cancelled" then
      return false, "no-handoff"
    end
    if activeHandoff.state == "handed_off" then
      return false, "handoff-locked"
    end

    activeHandoff.state = "cancelled"
    internalHandoffCallbacks = nil
    return true, nil
  end

  function api.resumeFromBattle(resultToken)
    if not activeHandoff then
      return false, "no-handoff"
    end
    if type(resultToken) ~= "table" then
      return false, "invalid-options"
    end
    if resultToken.handoffId ~= activeHandoff.id then
      return false, "invalid-handoff-id"
    end
    local outcome = resultToken.outcome
    if not outcome or not VALID_BATTLE_OUTCOMES[outcome] then
      return false, "invalid-outcome"
    end

    activeHandoff.outcome = outcome
    activeHandoff.state = "returned"

    local cbs = internalHandoffCallbacks or {}
    if outcome == "win" and type(cbs.onWin) == "function" then
      pcall(cbs.onWin, api, resultToken)
    elseif outcome == "lose" and type(cbs.onLose) == "function" then
      pcall(cbs.onLose, api, resultToken)
    elseif outcome == "flee" and type(cbs.onFlee) == "function" then
      pcall(cbs.onFlee, api, resultToken)
    end
    if type(cbs.onReturn) == "function" then
      pcall(cbs.onReturn, api, resultToken)
    end

    if activeSequence and activeSequence.waitingBattle then
      activeSequence.waitingBattle = false
      activeSequence.lastBattleOutcome = outcome
      activeSequence.index = activeSequence.index + 1
      processSequence()
    end

    return true, outcome
  end

  local function cleanupSequenceResources(seq)
    if not seq then return end
    if seq.ownedBubble then
      api.hideBubble({ transition = "cut" })
    end
    if seq.ownedSubtitle then
      api.clearSubtitle({ transition = "cut" })
    end
    for key, _ in pairs(seq.ownedEmotes or {}) do
      api.clearEmote(key)
    end
    for slot, _ in pairs(seq.ownedActors or {}) do
      api.clearActor(slot, { transition = "cut" })
    end
    if seq.priorFX then
      if seq.priorFX.shake then
        if seq.priorFX.shake.active then
          api.shakeScreen(seq.priorFX.shake)
        else
          api.stopShake()
        end
      end
      if seq.priorFX.tint then
        if seq.priorFX.tint.active then
          api.setTint({
            r = seq.priorFX.tint.r,
            g = seq.priorFX.tint.g,
            b = seq.priorFX.tint.b,
            a = seq.priorFX.tint.a,
          }, { duration = 0 })
        else
          api.clearTint({ duration = 0 })
        end
      end
      if seq.priorFX.vignette then
        if seq.priorFX.vignette.active then
          api.setVignette(seq.priorFX.vignette.style, {
            color = {
              seq.priorFX.vignette.r,
              seq.priorFX.vignette.g,
              seq.priorFX.vignette.b,
              seq.priorFX.vignette.a,
            },
            target = seq.priorFX.vignette.target,
            radius = seq.priorFX.vignette.radius,
            duration = 0,
          })
        else
          api.clearVignette({ duration = 0 })
        end
      end
      if seq.priorFX.weather then
        if seq.priorFX.weather.active then
          api.setWeather(seq.priorFX.weather.weatherType, {
            count = seq.priorFX.weather.count,
            speed = seq.priorFX.weather.speed,
            seed = seq.priorFX.weather.seed,
            duration = 0,
          })
        else
          api.clearWeather({ duration = 0 })
        end
      end
    end
  end

  local function executeStep(step)
    if type(step) ~= "table" then return true, 0 end
    local action = step.action or step[1]
    if not action then return true, 0 end

    local shouldWait = (step.wait == true) or (step.opts and step.opts.wait == true)

    if action == "show" then
      api.show(step.scene or step.id or false, step.opts or step)
      if shouldWait then
        local dur = step.duration or (step.opts and step.opts.duration) or 0.35
        return true, dur
      end
    elseif action == "hide" then
      api.hide(step.opts or step)
      if shouldWait then
        local dur = step.duration or (step.opts and step.opts.duration) or 0.35
        return true, dur
      end
    elseif action == "actor" or action == "setActor" then
      api.setActor(step.slot, step.config or step, step.opts)
      if activeSequence and activeSequence.cleanup and step.slot then
        activeSequence.ownedActors[step.slot] = true
      end
      if shouldWait then
        local dur = step.duration or (step.opts and step.opts.duration) or 0.3
        return true, dur
      end
    elseif action == "clearActor" then
      api.clearActor(step.slot, step.opts)
      if shouldWait then
        local dur = step.duration or (step.opts and step.opts.duration) or 0.3
        return true, dur
      end
    elseif action == "clearActors" then
      api.clearActors(step.opts)
      if shouldWait then
        local dur = step.duration or (step.opts and step.opts.duration) or 0.3
        return true, dur
      end
    elseif action == "bubble" or action == "showBubble" then
      api.showBubble(step.speaker, step.text, step.opts or step)
      if activeSequence and activeSequence.cleanup then
        activeSequence.ownedBubble = true
      end
      if shouldWait then
        local dur = step.duration or (step.opts and step.opts.duration) or 0.2
        return true, dur
      end
    elseif action == "hideBubble" then
      api.hideBubble(step.opts or step)
      if shouldWait then
        local dur = step.duration or (step.opts and step.opts.duration) or 0.2
        return true, dur
      end
    elseif action == "subtitle" or action == "setSubtitle" then
      api.setSubtitle(step.text, step.opts or step)
      if activeSequence and activeSequence.cleanup then
        activeSequence.ownedSubtitle = true
      end
      if shouldWait then
        local dur = step.duration or (step.opts and step.opts.duration) or 0.25
        return true, dur
      end
    elseif action == "clearSubtitle" then
      api.clearSubtitle(step.opts or step)
      if shouldWait then
        local dur = step.duration or (step.opts and step.opts.duration) or 0.25
        return true, dur
      end
    elseif action == "emote" or action == "showEmote" then
      local ok, key = api.showEmote(step.target, step.type or step.emoteType, step.opts or step)
      if ok and activeSequence and activeSequence.cleanup and key then
        activeSequence.ownedEmotes[key] = true
      end
    elseif action == "clearEmote" then
      api.clearEmote(step.target)
    elseif action == "shake" or action == "shakeScreen" then
      if activeSequence and activeSequence.cleanup then
        if not activeSequence.priorFX.shake then
          activeSequence.priorFX.shake = api.getShake()
        end
      end
      api.shakeScreen(step.opts or step)
      if shouldWait then
        local dur = step.duration or (step.opts and step.opts.duration) or 0.4
        return true, dur
      end
    elseif action == "stopShake" then
      api.stopShake()
    elseif action == "flash" or action == "flashScreen" then
      api.flashScreen(step.color or step.preset or step[2] or "white", step.opts or step)
      if shouldWait then
        local dur = step.duration or (step.opts and step.opts.duration) or 0.3
        return true, dur
      end
    elseif action == "tint" or action == "setTint" then
      if activeSequence and activeSequence.cleanup then
        if not activeSequence.priorFX.tint then
          activeSequence.priorFX.tint = api.getTint()
        end
      end
      api.setTint(step.color or step.preset or step[2], step.opts or step)
      if shouldWait then
        local dur = step.duration or (step.opts and step.opts.duration) or 0
        if dur > 0 then return true, dur end
      end
    elseif action == "clearTint" then
      if activeSequence and activeSequence.cleanup then
        if not activeSequence.priorFX.tint then
          activeSequence.priorFX.tint = api.getTint()
        end
      end
      api.clearTint(step.opts or step)
      if shouldWait then
        local dur = step.duration or (step.opts and step.opts.duration) or 0
        if dur > 0 then return true, dur end
      end
    elseif action == "vignette" or action == "setVignette" then
      if activeSequence and activeSequence.cleanup then
        if not activeSequence.priorFX.vignette then
          activeSequence.priorFX.vignette = api.getVignette()
        end
      end
      api.setVignette(step.style or step[2], step.opts or step)
      if shouldWait then
        local dur = step.duration or (step.opts and step.opts.duration) or 0
        if dur > 0 then return true, dur end
      end
    elseif action == "clearVignette" then
      if activeSequence and activeSequence.cleanup then
        if not activeSequence.priorFX.vignette then
          activeSequence.priorFX.vignette = api.getVignette()
        end
      end
      api.clearVignette(step.opts or step)
      if shouldWait then
        local dur = step.duration or (step.opts and step.opts.duration) or 0
        if dur > 0 then return true, dur end
      end
    elseif action == "weather" or action == "setWeather" then
      if activeSequence and activeSequence.cleanup then
        if not activeSequence.priorFX.weather then
          activeSequence.priorFX.weather = api.getWeather()
        end
      end
      api.setWeather(step.weatherType or step.type or step[2], step.opts or step)
      if shouldWait then
        local dur = step.duration or (step.opts and step.opts.duration) or 0
        if dur > 0 then return true, dur end
      end
    elseif action == "clearWeather" then
      if activeSequence and activeSequence.cleanup then
        if not activeSequence.priorFX.weather then
          activeSequence.priorFX.weather = api.getWeather()
        end
      end
      api.clearWeather(step.opts or step)
      if shouldWait then
        local dur = step.duration or (step.opts and step.opts.duration) or 0
        if dur > 0 then return true, dur end
      end
    elseif action == "battle" then
      local ok, token = api.prepareBattleHandoff(step.opts or step)
      if ok and activeSequence then
        activeSequence.waitingBattle = true
        activeSequence.currentAction = "battle"
      end
      return true, 0
    elseif action == "call" or action == "fn" then
      local fn = step.fn or step.callback
      if type(fn) == "function" then
        local ok, err = pcall(fn, api, activeSequence)
        if not ok then
          if activeSequence then
            activeSequence.lastError = "callback-error"
          end
          return false, "callback-error"
        end
      end
    end
    return true, 0
  end

  processSequence = function()
    if not activeSequence or activeSequence.completed then
      return
    end

    while activeSequence.index <= #activeSequence.steps do
      local step = activeSequence.steps[activeSequence.index]
      local action = (type(step) == "table" and (step.action or step[1])) or "noop"

      if action == "wait" then
        local dur = (type(step) == "table" and step.duration) or 0.5
        if dur > 0 then
          activeSequence.waitTimer = dur
          activeSequence.currentAction = "wait"
          return
        else
          activeSequence.index = activeSequence.index + 1
        end
      elseif action == "waitInput" then
        activeSequence.waitingInput = true
        activeSequence.currentAction = "waitInput"
        return
      else
        local ok, waitDur = executeStep(step)
        if not ok then
          local onAbort = activeSequence.onAbort
          activeSequence.aborted = true
          if activeSequence.cleanup then
            cleanupSequenceResources(activeSequence)
          end
          activeSequence = nil
          if type(onAbort) == "function" then
            pcall(onAbort, api, "callback-error")
          end
          return
        end

        if activeSequence and activeSequence.waitingBattle then
          return
        end

        activeSequence.index = activeSequence.index + 1

        if waitDur and waitDur > 0 then
          activeSequence.waitTimer = waitDur
          activeSequence.currentAction = action .. "_wait"
          return
        end
      end
    end

    activeSequence.completed = true
    local onComplete = activeSequence.onComplete
    activeSequence = nil
    if type(onComplete) == "function" then
      pcall(onComplete, api)
    end
  end

  function api.playSequence(steps, opts)
    if type(steps) ~= "table" or #steps == 0 then
      return false, "invalid-sequence"
    end
    opts = opts or {}
    if type(opts) ~= "table" then
      return false, "invalid-options"
    end
    if opts.skippable ~= nil and type(opts.skippable) ~= "boolean" then
      return false, "invalid-options"
    end
    if opts.cleanup ~= nil and type(opts.cleanup) ~= "boolean" then
      return false, "invalid-options"
    end

    if activeSequence then
      api.stopSequence()
    end

    local seqId = opts.id or nextSequenceId
    nextSequenceId = nextSequenceId + 1

    activeSequence = {
      id = seqId,
      steps = steps,
      index = 1,
      waitTimer = 0,
      waitingInput = false,
      currentAction = "start",
      skippable = (opts.skippable ~= false),
      cleanup = (opts.cleanup == true),
      ownedActors = {},
      ownedEmotes = {},
      ownedBubble = false,
      ownedSubtitle = false,
      priorFX = {},
      waitingBattle = false,
      lastBattleOutcome = nil,
      onComplete = opts.onComplete,
      onAbort = opts.onAbort,
      completed = false,
      aborted = false,
      lastError = nil,
    }

    processSequence()
    return true, seqId
  end

  function api.stopSequence(opts)
    if not activeSequence then
      return true, nil
    end

    local seq = activeSequence
    seq.aborted = true
    if seq.cleanup then
      cleanupSequenceResources(seq)
    end

    local onAbort = seq.onAbort
    activeSequence = nil

    if type(onAbort) == "function" then
      pcall(onAbort, api)
    end
    return true, nil
  end

  function api.skipSequence()
    if not activeSequence then
      return true, nil
    end
    if not activeSequence.skippable then
      return false, "not-skippable"
    end

    while activeSequence.index <= #activeSequence.steps do
      local step = activeSequence.steps[activeSequence.index]
      local action = (type(step) == "table" and (step.action or step[1])) or "noop"
      if action ~= "wait" and action ~= "waitInput" and action ~= "battle" then
        executeStep(step)
      end
      activeSequence.index = activeSequence.index + 1
    end

    activeSequence.completed = true
    local onComplete = activeSequence.onComplete
    activeSequence = nil

    if type(onComplete) == "function" then
      pcall(onComplete, api)
    end
    return true, nil
  end

  function api.advanceSequence()
    if not activeSequence then
      return false, "not-waiting"
    end

    if activeSequence.waitingInput then
      activeSequence.waitingInput = false
      activeSequence.index = activeSequence.index + 1
      processSequence()
      return true, activeSequence and activeSequence.index or nil
    elseif activeSequence.waitTimer > 0 then
      activeSequence.waitTimer = 0
      activeSequence.index = activeSequence.index + 1
      processSequence()
      return true, activeSequence and activeSequence.index or nil
    end

    return false, "not-waiting"
  end

  function api.getSequence()
    if not activeSequence then return nil end
    return {
      active = true,
      id = activeSequence.id,
      stepIndex = activeSequence.index,
      totalSteps = #activeSequence.steps,
      waitingInput = activeSequence.waitingInput,
      waitingBattle = activeSequence.waitingBattle or false,
      lastBattleOutcome = activeSequence.lastBattleOutcome,
      waitRemaining = activeSequence.waitTimer or 0,
      currentAction = activeSequence.currentAction,
      skippable = activeSequence.skippable,
      aborted = activeSequence.aborted or false,
      lastError = activeSequence.lastError,
    }
  end

  function api.update(dt)
    dt = dt or 0

    -- 1. Scene transitions
    if transition then
      transition.elapsed = transition.elapsed + dt
      if transition.elapsed >= transition.duration then
        local wasHide = (transition.toActive == false)
        transition = nil
        if wasHide then
          currentSceneId = nil
          currentUnderlay = "transparent"
        end
      end
    end

    -- 2. Actor transitions
    local finishedSlots = {}
    for slot, actor in pairs(actors) do
      local t = actor.transition
      if t then
        t.elapsed = t.elapsed + dt
        local progress = t.duration > 0 and math.min(1, t.elapsed / t.duration) or 1
        if t.type == "fade" then
          actor.currentAlpha = t.startAlpha + (t.targetAlpha - t.startAlpha) * progress
        elseif t.type == "slide" then
          actor.currentX = t.startX + (t.targetX - t.startX) * progress
          actor.currentY = t.startY + (t.targetY - t.startY) * progress
        end
        if t.elapsed >= t.duration then
          if t.exiting then
            table.insert(finishedSlots, slot)
          else
            actor.currentAlpha = 1.0
            actor.currentX = actor.x
            actor.currentY = actor.y
            actor.transition = nil
          end
        end
      end
    end
    for _, slot in ipairs(finishedSlots) do
      actors[slot] = nil
    end

    -- 3. Bubble transition & duration auto-dismiss
    if activeBubble then
      local b = activeBubble
      if b.duration then
        b.elapsed = b.elapsed + dt
        if b.elapsed >= b.duration and not (b.transition and b.transition.exiting) then
          api.hideBubble({ transition = "fade" })
        end
      end
      if b.transition then
        local t = b.transition
        t.elapsed = t.elapsed + dt
        local prog = t.duration > 0 and math.min(1, t.elapsed / t.duration) or 1
        if t.type == "fade" then
          b.currentAlpha = t.exiting and (1 - prog) or prog
        elseif t.type == "pop" then
          b.currentScale = t.exiting and (1 - prog * 0.3) or (0.7 + prog * 0.3)
        end
        if t.elapsed >= t.duration then
          if t.exiting then
            activeBubble = nil
          else
            b.currentAlpha = 1.0
            b.currentScale = 1.0
            b.transition = nil
          end
        end
      end
    end

    -- 4. Subtitle transition & duration auto-dismiss
    if activeSubtitle then
      local s = activeSubtitle
      if s.duration then
        s.elapsed = s.elapsed + dt
        if s.elapsed >= s.duration and not (s.transition and s.transition.exiting) then
          api.clearSubtitle({ transition = "fade" })
        end
      end
      if s.transition then
        local t = s.transition
        t.elapsed = t.elapsed + dt
        local prog = t.duration > 0 and math.min(1, t.elapsed / t.duration) or 1
        s.currentAlpha = t.exiting and (1 - prog) or prog
        if t.elapsed >= t.duration then
          if t.exiting then
            activeSubtitle = nil
          else
            s.currentAlpha = 1.0
            s.transition = nil
          end
        end
      end
    end

    -- 5. Emote duration auto-dismiss
    local expiredEmotes = {}
    for k, e in pairs(activeEmotes) do
      if e.duration then
        e.elapsed = e.elapsed + dt
        if e.elapsed >= e.duration then
          table.insert(expiredEmotes, k)
        end
      end
    end
    for _, k in ipairs(expiredEmotes) do
      activeEmotes[k] = nil
    end

    -- 6. Horizon 4 FX updates
    -- Screen shake decay
    if activeShake then
      local s = activeShake
      s.elapsed = s.elapsed + dt
      if s.elapsed >= s.duration then
        activeShake = nil
      else
        local prog = s.elapsed / s.duration
        local decay = 1.0 - prog
        local step = math.floor(s.elapsed * s.frequency)
        local nx = math.sin(step * 1.7 + 0.3) * math.cos(step * 0.9 + 1.1)
        local ny = math.cos(step * 1.3 + 0.7) * math.sin(step * 1.1 + 0.5)
        local rawX = (s.direction == "vertical") and 0 or (nx * s.intensity * decay)
        local rawY = (s.direction == "horizontal") and 0 or (ny * s.intensity * decay)
        if s.pixelSnap then
          s.offsetX = math.floor(rawX + (rawX >= 0 and 0.5 or -0.5))
          s.offsetY = math.floor(rawY + (rawY >= 0 and 0.5 or -0.5))
        else
          s.offsetX = rawX
          s.offsetY = rawY
        end
      end
    end

    -- Tint lerp
    if activeTint.duration > 0 and activeTint.elapsed < activeTint.duration then
      activeTint.elapsed = activeTint.elapsed + dt
      local prog = math.min(1.0, activeTint.elapsed / activeTint.duration)
      local st = activeTint.start
      local tg = activeTint.target
      activeTint.current.r = st.r + (tg.r - st.r) * prog
      activeTint.current.g = st.g + (tg.g - st.g) * prog
      activeTint.current.b = st.b + (tg.b - st.b) * prog
      activeTint.current.a = math.max(0, math.min(1, st.a + (tg.a - st.a) * prog))
      if activeTint.elapsed >= activeTint.duration then
        activeTint.current.r = tg.r
        activeTint.current.g = tg.g
        activeTint.current.b = tg.b
        activeTint.current.a = tg.a
        activeTint.duration = 0
      end
    end

    -- Flash decay
    if activeFlash then
      local f = activeFlash
      f.elapsed = f.elapsed + dt
      if f.elapsed >= f.duration then
        activeFlash = nil
      else
        local prog = math.min(1.0, f.elapsed / f.duration)
        if f.mode == "out" then
          f.alpha = math.max(0, 1.0 - prog)
        elseif f.mode == "inout" then
          if prog < 0.5 then
            f.alpha = math.min(1.0, prog * 2.0)
          else
            f.alpha = math.max(0, (1.0 - prog) * 2.0)
          end
        end
      end
    end

    -- Vignette transition
    if activeVignette and activeVignette.duration > 0 then
      local v = activeVignette
      v.elapsed = v.elapsed + dt
      local prog = math.min(1.0, v.elapsed / v.duration)
      v.alpha = v.startAlpha + (v.targetAlpha - v.startAlpha) * prog
      if v.elapsed >= v.duration then
        v.alpha = v.targetAlpha
        v.duration = 0
        if v.exiting then
          activeVignette = nil
        end
      end
    end

    -- Weather particles update
    if activeWeather then
      local w = activeWeather
      if w.duration > 0 and w.elapsed < w.duration then
        w.elapsed = w.elapsed + dt
        local prog = math.min(1.0, w.elapsed / w.duration)
        w.alpha = w.startAlpha + (w.targetAlpha - w.startAlpha) * prog
        if w.elapsed >= w.duration then
          w.alpha = w.targetAlpha
          w.duration = 0
          if w.exiting then
            activeWeather = nil
          end
        end
      end
      if activeWeather then
        for _, p in ipairs(activeWeather.particles) do
          if p.phase then
            p.phase = p.phase + dt * 2
          end
          local extraX = (p.phase and (activeWeather.weatherType == "leaves" or activeWeather.weatherType == "cherry_blossom"))
            and (math.sin(p.phase) * 8 * dt) or 0
          p.x = p.x + (p.vx * dt) + extraX
          p.y = p.y + (p.vy * dt)
          if p.x < 0 then p.x = p.x + 320 end
          if p.x > 320 then p.x = p.x - 320 end
          if p.y < 0 then p.y = p.y + 180 end
          if p.y > 180 then p.y = p.y - 180 end
        end
      end
    end

    -- 7. Sequence runner update
    if activeSequence and activeSequence.waitTimer > 0 then
      activeSequence.waitTimer = activeSequence.waitTimer - dt
      if activeSequence.waitTimer <= 0 then
        activeSequence.waitTimer = 0
        activeSequence.index = activeSequence.index + 1
        processSequence()
      end
    end

    -- 8. Battle handoff transition update
    if activeHandoff and activeHandoff.state == "transitioning" then
      local h = activeHandoff
      h.elapsed = h.elapsed + dt
      h.transitionProgress = math.min(1.0, h.duration > 0 and (h.elapsed / h.duration) or 1.0)
      if h.elapsed >= h.duration then
        h.state = "handed_off"
        h.transitionProgress = 1.0
        if internalHandoffCallbacks and type(internalHandoffCallbacks.onHandoff) == "function" then
          local ok, err = pcall(internalHandoffCallbacks.onHandoff, api.getBattleHandoff())
          if not ok then
            h.lastError = "handoff-error"
          end
        end
      end
    end
  end

  function api.diagnostics()
    local isHandoffActive = (activeHandoff and (activeHandoff.state == "prepared" or activeHandoff.state == "transitioning" or activeHandoff.state == "handed_off")) and true or false
    local active = (currentSceneId ~= nil)
      or (transition ~= nil)
      or (next(actors) ~= nil)
      or (activeBubble ~= nil)
      or (activeSubtitle ~= nil)
      or (next(activeEmotes) ~= nil)
      or (activeSequence ~= nil)
      or (activeShake ~= nil)
      or (activeTint.current.a > 0 or activeTint.target.a > 0)
      or (activeFlash ~= nil)
      or (activeVignette ~= nil)
      or (activeWeather ~= nil)
      or isHandoffActive

    local state = "inactive"
    if active then
      if currentSceneId == false then
        state = "plain"
      elseif currentSceneId ~= nil then
        state = "image"
      elseif transition and transition.fromId then
        state = (transition.fromId == false) and "plain" or "image"
      else
        state = "plain"
      end
    end

    local assetPath = nil
    if state == "image" and currentSceneId and registry[currentSceneId] then
      assetPath = registry[currentSceneId].path
    end

    local vw, vh = 0, 0
    if love and love.graphics and love.graphics.getDimensions then
      vw, vh = love.graphics.getDimensions()
    end

    local actorsDiag = {}
    for slot, _ in pairs(actors) do
      actorsDiag[slot] = api.getActor(slot)
    end

    local out = {
      active = active,
      state = state,
      sceneId = currentSceneId,
      underlay = currentUnderlay,
      assetPath = assetPath,
      transitionActive = (transition ~= nil),
      viewportWidth = vw,
      viewportHeight = vh,
      actors = actorsDiag,
      bubble = api.getBubble(),
      subtitle = api.getSubtitle(),
      emotes = api.getEmotes(),
      sequence = api.getSequence(),
      shake = api.getShake(),
      tint = api.getTint(),
      flash = api.getFlash(),
      vignette = api.getVignette(),
      weather = api.getWeather(),
      battleHandoff = api.getBattleHandoff(),
    }

    if transition then
      out.transitionType = transition.type
      out.transitionProgress = transition.duration > 0
        and math.min(1, transition.elapsed / transition.duration) or 1
      out.fromId = transition.fromId
      out.toId = transition.toId
      out.toActive = transition.toActive
    end

    return out
  end

  function api.draw()
    if not api.isActive() then return end
    if not love or not love.graphics then return end

    if transition and transition.startTime and love.timer and love.timer.getTime then
      local now = love.timer.getTime()
      transition.elapsed = math.max(transition.elapsed, now - transition.startTime)
      if transition.elapsed >= transition.duration then
        local wasHide = (transition.toActive == false)
        transition = nil
        if wasHide then
          currentSceneId = nil
          currentUnderlay = "transparent"
        end
      end
    end
    if not api.isActive() then return end

    local vw, vh = love.graphics.getDimensions()
    local scale = math.min(vw / 320, vh / 180)
    local renderW = math.floor(320 * scale)
    local renderH = math.floor(180 * scale)
    local offsetX = math.floor((vw - renderW) / 2)
    local offsetY = math.floor((vh - renderH) / 2)

    local shakeX = 0
    local shakeY = 0
    if activeShake then
      shakeX = activeShake.offsetX
      shakeY = activeShake.offsetY
    end
    local stageOffsetX = offsetX + math.floor(shakeX * scale)
    local stageOffsetY = offsetY + math.floor(shakeY * scale)

    local activeUnderlay = currentUnderlay
    if transition and transition.fromUnderlay and transition.toUnderlay then
      activeUnderlay = transition.toUnderlay
    end

    -- 1. Draw Underlay
    if activeUnderlay == "black" then
      love.graphics.setColor(0, 0, 0, 1)
      love.graphics.rectangle("fill", 0, 0, vw, vh)
    elseif activeUnderlay == "paper" then
      local pr, pg, pb, pa = getPalettePaperColor()
      love.graphics.setColor(pr, pg, pb, pa or 1)
      love.graphics.rectangle("fill", 0, 0, vw, vh)
    end

    -- 2. Draw Scene / Transition (transformed by stage offset)
    local r, g, b, a = love.graphics.getColor()

    local function drawImg(img, alpha)
      if not img then return end
      love.graphics.setColor(1, 1, 1, alpha or 1)
      love.graphics.draw(img, stageOffsetX, stageOffsetY, 0, scale, scale)
    end

    if transition then
      local t = transition.duration > 0 and math.min(1, transition.elapsed / transition.duration) or 1
      local transType = transition.type

      if transType == "crossfade" then
        if transition.fromImg then
          drawImg(transition.fromImg, 1 - t)
        end
        if transition.toImg then
          drawImg(transition.toImg, t)
        end
      elseif transType == "flash" then
        -- Render endpoint image based on midpoint
        if t < 0.5 then
          if transition.fromImg then drawImg(transition.fromImg, 1) end
        else
          if transition.toImg then drawImg(transition.toImg, 1) end
        end
        -- White flash peaking at t = 0.5
        local flashAlpha = (t < 0.5) and (t * 2) or ((1 - t) * 2)
        love.graphics.setColor(1, 1, 1, flashAlpha)
        love.graphics.rectangle("fill", stageOffsetX, stageOffsetY, renderW, renderH)
      end
    else
      local img = getImage(currentSceneId)
      if img then
        drawImg(img, 1)
      end
    end

    -- Advance actor transitions if driven by love.timer
    if love and love.timer and love.timer.getTime then
      local now = love.timer.getTime()
      local finishedSlots = {}
      for slot, actor in pairs(actors) do
        local t = actor.transition
        if t and t.startTime then
          t.elapsed = math.max(t.elapsed, now - t.startTime)
          local progress = t.duration > 0 and math.min(1, t.elapsed / t.duration) or 1
          if t.type == "fade" then
            actor.currentAlpha = t.startAlpha + (t.targetAlpha - t.startAlpha) * progress
          elseif t.type == "slide" then
            actor.currentX = t.startX + (t.targetX - t.startX) * progress
            actor.currentY = t.startY + (t.targetY - t.startY) * progress
          end
          if t.elapsed >= t.duration then
            if t.exiting then
              table.insert(finishedSlots, slot)
            else
              actor.currentAlpha = 1.0
              actor.currentX = actor.x
              actor.currentY = actor.y
              actor.transition = nil
            end
          end
        end
      end
      for _, slot in ipairs(finishedSlots) do
        actors[slot] = nil
      end
    end

    -- 2.5 Draw Actor Shadows (behind actors, above backdrop)
    if ShadowEngine then
      for slot, actor in pairs(actors) do
        local alpha = actor.currentAlpha or 1.0
        if actor.shadowState and actor.shadowState.enabled and alpha > 0 then
          local stageX = actor.currentX or actor.x
          local stageY = actor.currentY or actor.y
          local screenX = stageOffsetX + stageX * scale
          local screenY = stageOffsetY + stageY * scale
          ShadowEngine.renderShadowState(love.graphics, actor.shadowState, {
            x = screenX,
            y = screenY,
            scale = scale * actor.scale,
            mirror = actor.mirror,
            direction = actor.mirror and -1 or 1,
            alphaScale = alpha,
          })
        end
      end
    end

    -- 3. Draw Actors
    for slot, actor in pairs(actors) do
      local img = getActorImage(actor)
      local alpha = actor.currentAlpha or 1.0
      if img and alpha > 0 then
        local iw = (img.getWidth and img:getWidth()) or 0
        local ih = (img.getHeight and img:getHeight()) or 0
        if iw > 0 and ih > 0 then
          local stageX = actor.currentX or actor.x
          local stageY = actor.currentY or actor.y
          local screenX = stageOffsetX + stageX * scale
          local screenY = stageOffsetY + stageY * scale
          local sx = scale * actor.scale * (actor.mirror and -1 or 1)
          local sy = scale * actor.scale
          love.graphics.setColor(1, 1, 1, alpha)
          love.graphics.draw(img, screenX, screenY, 0, sx, sy, iw / 2, ih)
        end
      end
    end

    -- 4. Draw Weather Particles (behind tint/flash, in front of actors)
    if activeWeather and activeWeather.alpha > 0 then
      local w = activeWeather
      local wAlpha = w.alpha
      for _, p in ipairs(w.particles) do
        local px = stageOffsetX + math.floor(p.x * scale)
        local py = stageOffsetY + math.floor(p.y * scale)
        if w.weatherType == "rain" then
          love.graphics.setColor(0.7, 0.85, 1.0, 0.75 * wAlpha)
          local pLen = math.max(2, math.floor(p.size * scale))
          love.graphics.line(px, py, px - math.floor(2 * scale), py + pLen)
        elseif w.weatherType == "snow" then
          love.graphics.setColor(1, 1, 1, 0.85 * wAlpha)
          local pSz = math.max(1, math.floor(p.size * scale))
          love.graphics.rectangle("fill", px, py, pSz, pSz)
        elseif w.weatherType == "leaves" or w.weatherType == "cherry_blossom" then
          if w.weatherType == "cherry_blossom" then
            love.graphics.setColor(1, 0.7, 0.8, 0.8 * wAlpha)
          else
            love.graphics.setColor(0.4, 0.8, 0.3, 0.8 * wAlpha)
          end
          local pSz = math.max(2, math.floor(p.size * scale))
          love.graphics.rectangle("fill", px, py, pSz, pSz)
        elseif w.weatherType == "embers" then
          love.graphics.setColor(1, 0.5, 0.1, 0.85 * wAlpha)
          local pSz = math.max(1, math.floor(p.size * scale))
          love.graphics.rectangle("fill", px, py, pSz, pSz)
        elseif w.weatherType == "dust" then
          love.graphics.setColor(0.9, 0.9, 0.7, 0.45 * wAlpha)
          local pSz = math.max(1, math.floor(p.size * scale))
          love.graphics.rectangle("fill", px, py, pSz, pSz)
        end
      end
    end

    -- 5. Draw Ambient Tint Overlay
    if activeTint and activeTint.current.a > 0 then
      local tc = activeTint.current
      love.graphics.setColor(tc.r, tc.g, tc.b, tc.a)
      love.graphics.rectangle("fill", stageOffsetX, stageOffsetY, renderW, renderH)
    end

    -- 6. Draw Stage Flash (if scope == "stage")
    if activeFlash and activeFlash.scope == "stage" and activeFlash.alpha > 0 then
      love.graphics.setColor(activeFlash.r, activeFlash.g, activeFlash.b, activeFlash.alpha)
      love.graphics.rectangle("fill", stageOffsetX, stageOffsetY, renderW, renderH)
    end

    -- 7. Draw Vignette
    if activeVignette and activeVignette.alpha > 0 then
      local v = activeVignette
      love.graphics.setColor(v.r, v.g, v.b, v.alpha)
      if v.style == "letterbox" then
        local barH = math.floor(renderH * 0.12)
        love.graphics.rectangle("fill", stageOffsetX, stageOffsetY, renderW, barH)
        love.graphics.rectangle("fill", stageOffsetX, stageOffsetY + renderH - barH, renderW, barH)
      elseif v.style == "spotlight" then
        local borderSz = math.floor(16 * scale)
        love.graphics.rectangle("fill", stageOffsetX, stageOffsetY, renderW, borderSz)
        love.graphics.rectangle("fill", stageOffsetX, stageOffsetY + renderH - borderSz, renderW, borderSz)
        love.graphics.rectangle("fill", stageOffsetX, stageOffsetY, borderSz, renderH)
        love.graphics.rectangle("fill", stageOffsetX + renderW - borderSz, stageOffsetY, borderSz, renderH)
      elseif v.style == "dither" then
        local band = math.floor(12 * scale)
        love.graphics.rectangle("fill", stageOffsetX, stageOffsetY, renderW, band)
        love.graphics.rectangle("fill", stageOffsetX, stageOffsetY + renderH - band, renderW, band)
        love.graphics.rectangle("fill", stageOffsetX, stageOffsetY, band, renderH)
        love.graphics.rectangle("fill", stageOffsetX + renderW - band, stageOffsetY, band, renderH)
      end
    end

    -- 8. Draw Full-Screen Flash (if scope == "full")
    if activeFlash and activeFlash.scope == "full" and activeFlash.alpha > 0 then
      love.graphics.setColor(activeFlash.r, activeFlash.g, activeFlash.b, activeFlash.alpha)
      love.graphics.rectangle("fill", 0, 0, vw, vh)
    end

    -- 8b. Pre-battle transition animation
    if activeHandoff and activeHandoff.state == "transitioning" and activeHandoff.transitionProgress > 0 then
      local p = activeHandoff.transitionProgress
      local trans = activeHandoff.transition
      if trans == "flash" then
        local strobe = math.floor(activeHandoff.elapsed * 12) % 3
        if strobe == 0 then
          love.graphics.setColor(1, 1, 1, 0.9)
        elseif strobe == 1 then
          love.graphics.setColor(0, 0, 0, 0.9)
        else
          love.graphics.setColor(1, 0.2, 0.2, 0.9)
        end
        love.graphics.rectangle("fill", stageOffsetX, stageOffsetY, renderW, renderH)
      elseif trans == "blinds" then
        local numBars = 10
        local barH = renderH / numBars
        love.graphics.setColor(0, 0, 0, 1)
        for i = 0, numBars - 1 do
          local w = math.floor(renderW * p)
          local by = stageOffsetY + math.floor(i * barH)
          local bx = (i % 2 == 0) and stageOffsetX or (stageOffsetX + renderW - w)
          love.graphics.rectangle("fill", bx, by, w, math.ceil(barH))
        end
      elseif trans == "mosaic" or trans == "swirl" then
        local alpha = math.min(1.0, p * 1.2)
        love.graphics.setColor(0, 0, 0, alpha)
        local borderInset = math.floor(renderH * 0.5 * p)
        love.graphics.rectangle("fill", stageOffsetX, stageOffsetY, renderW, borderInset)
        love.graphics.rectangle("fill", stageOffsetX, stageOffsetY + renderH - borderInset, renderW, borderInset)
      end
    end

    -- 9. Top UI Layer (Emotes, Bubbles, Subtitles)
    local uiOffsetX = (activeShake and activeShake.shakeUI) and stageOffsetX or offsetX
    local uiOffsetY = (activeShake and activeShake.shakeUI) and stageOffsetY or offsetY

    -- 9a. Draw Emotes
    local nowTime = (love and love.timer and love.timer.getTime and love.timer.getTime()) or 0
    for targetKey, emote in pairs(activeEmotes) do
      local originX, originY
      if type(emote.target) == "string" and actors[emote.target] then
        originX, originY = api.getActorAnchor(emote.target, "top")
      elseif type(emote.target) == "table" then
        originX, originY = emote.target.x, emote.target.y
      end
      if originX and originY then
        local bounceOffset = emote.bounce and (math.sin(nowTime * 8) * 2) or 0
        local eX = uiOffsetX + originX * scale
        local eY = uiOffsetY + (originY - 8 + bounceOffset) * scale
        love.graphics.setColor(1, 1, 1, 0.95)
        local eSize = math.floor(10 * scale)
        love.graphics.rectangle("fill", eX - eSize / 2, eY - eSize / 2, eSize, eSize)
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.rectangle("line", eX - eSize / 2, eY - eSize / 2, eSize, eSize)
        local sym = "!"
        if emote.emoteType == "question" then sym = "?"
        elseif emote.emoteType == "dots" then sym = "..."
        elseif emote.emoteType == "sweat" then sym = "~"
        elseif emote.emoteType == "anger" then sym = "#"
        elseif emote.emoteType == "heart" then sym = "<3"
        elseif emote.emoteType == "music" then sym = "~"
        end
        love.graphics.print(sym, math.floor(eX - eSize / 4), math.floor(eY - eSize / 3), 0, scale, scale)
      end
    end

    -- 9b. Draw Bubble
    if activeBubble then
      local b = activeBubble
      local bAlpha = b.currentAlpha or 1.0
      local bScale = b.currentScale or 1.0
      if bAlpha > 0 and bScale > 0 then
        local bx = uiOffsetX + b.x * scale
        local by = uiOffsetY + b.y * scale
        local bw = b.width * scale * bScale
        local bh = b.height * scale * bScale

        local pr, pg, pb, pa = getPalettePaperColor()

        if b.hasTail and b.tailRootX and b.tailRootY and b.tailTargetX and b.tailTargetY then
          local rX = uiOffsetX + b.tailRootX * scale
          local rY = uiOffsetY + b.tailRootY * scale
          local tX = uiOffsetX + b.tailTargetX * scale
          local tY = uiOffsetY + b.tailTargetY * scale

          if b.style == "thought" then
            love.graphics.setColor(pr, pg, pb, bAlpha)
            local mid1X = rX + (tX - rX) * 0.4
            local mid1Y = rY + (tY - rY) * 0.4
            local mid2X = rX + (tX - rX) * 0.75
            local mid2Y = rY + (tY - rY) * 0.75
            love.graphics.circle("fill", mid1X, mid1Y, math.max(2, 3 * scale))
            love.graphics.circle("fill", mid2X, mid2Y, math.max(1, 2 * scale))
            love.graphics.setColor(0, 0, 0, bAlpha)
            love.graphics.circle("line", mid1X, mid1Y, math.max(2, 3 * scale))
            love.graphics.circle("line", mid2X, mid2Y, math.max(1, 2 * scale))
          else
            local tailW = math.max(4, 5 * scale)
            love.graphics.setColor(pr, pg, pb, bAlpha)
            love.graphics.polygon("fill", rX - tailW, rY, rX + tailW, rY, tX, tY)
            love.graphics.setColor(0, 0, 0, bAlpha)
            love.graphics.line(rX - tailW, rY, tX, tY)
            love.graphics.line(rX + tailW, rY, tX, tY)
          end
        end

        love.graphics.setColor(pr, pg, pb, bAlpha)
        love.graphics.rectangle("fill", bx, by, bw, bh)
        love.graphics.setColor(0, 0, 0, bAlpha)
        love.graphics.setLineWidth(math.max(1, math.floor(scale)))
        love.graphics.rectangle("line", bx, by, bw, bh)

        love.graphics.setColor(0, 0, 0, bAlpha)
        local pad = b.padding * scale
        for i, line in ipairs(b.lines) do
          local lineY = by + pad + (i - 1) * LINE_HEIGHT * scale
          love.graphics.print(line, math.floor(bx + pad), math.floor(lineY), 0, scale, scale)
        end
      end
    end

    -- 9c. Draw Subtitles (topmost cinematic narration)
    if activeSubtitle then
      local s = activeSubtitle
      local sAlpha = s.currentAlpha or 1.0
      if sAlpha > 0 then
        local subH = math.floor(22 * scale)
        local subY = uiOffsetY + math.floor((180 - 24) * scale)
        if s.position == "top" then
          subY = uiOffsetY + math.floor(4 * scale)
        elseif s.position == "center" then
          subY = uiOffsetY + math.floor((180 - 24) / 2 * scale)
        end

        if s.bar then
          love.graphics.setColor(0, 0, 0, 0.75 * sAlpha)
          love.graphics.rectangle("fill", uiOffsetX, subY, renderW, subH)
        end

        love.graphics.setColor(1, 1, 1, sAlpha)
        local textW = #s.text * CHAR_WIDTH * scale
        local subX = uiOffsetX + math.floor((renderW - textW) / 2)
        if s.align == "left" then
          subX = uiOffsetX + math.floor(8 * scale)
        elseif s.align == "right" then
          subX = uiOffsetX + renderW - textW - math.floor(8 * scale)
        end
        local textY = subY + math.floor((subH - LINE_HEIGHT * scale) / 2)
        love.graphics.print(s.text, math.floor(subX), math.floor(textY), 0, scale, scale)
      end
    end

    love.graphics.setColor(r, g, b, a)
  end

  return api
end

return BetterScenes
