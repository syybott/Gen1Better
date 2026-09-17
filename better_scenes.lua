
local BetterScenes = {}

local RESERVED_PREFIXES = { "gen1_", "better_", "system_" }
local VALID_TRANSITIONS = { cut = true, crossfade = true, flash = true }
local VALID_UNDERLAYS = { black = true, paper = true, transparent = true }

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
  local isSelfMod = options.isSelfMod or function() return false end
  local getPalettePaperColor = options.getPalettePaperColor or function() return 1, 1, 1, 1 end

  local registry = {}

  local currentSceneId = nil
  local currentUnderlay = "transparent"
  local transition = nil

  local loadedImages = {}

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
    return currentSceneId ~= nil or transition ~= nil
  end

  function api.update(dt)
    if not transition then return end
    dt = dt or 0
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

  function api.diagnostics()
    local active = (currentSceneId ~= nil) or (transition ~= nil)
    local state = "inactive"
    if active then
      if currentSceneId == false then
        state = "plain"
      elseif currentSceneId ~= nil then
        state = "image"
      elseif transition and transition.fromId then
        state = (transition.fromId == false) and "plain" or "image"
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

    local out = {
      active = active,
      state = state,
      sceneId = currentSceneId,
      underlay = currentUnderlay,
      assetPath = assetPath,
      transitionActive = (transition ~= nil),
      viewportWidth = vw,
      viewportHeight = vh,
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

    local activeUnderlay = currentUnderlay
    if transition and transition.fromUnderlay and transition.toUnderlay then
      activeUnderlay = transition.toUnderlay
    end

    if activeUnderlay == "black" then
      love.graphics.setColor(0, 0, 0, 1)
      love.graphics.rectangle("fill", 0, 0, vw, vh)
    elseif activeUnderlay == "paper" then
      local pr, pg, pb, pa = getPalettePaperColor()
      love.graphics.setColor(pr, pg, pb, pa or 1)
      love.graphics.rectangle("fill", 0, 0, vw, vh)
    end

    local r, g, b, a = love.graphics.getColor()

    local function drawImg(img, alpha)
      if not img then return end
      love.graphics.setColor(1, 1, 1, alpha or 1)
      love.graphics.draw(img, offsetX, offsetY, 0, scale, scale)
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
        if t < 0.5 then
          if transition.fromImg then drawImg(transition.fromImg, 1) end
        else
          if transition.toImg then drawImg(transition.toImg, 1) end
        end
        local flashAlpha = (t < 0.5) and (t * 2) or ((1 - t) * 2)
        love.graphics.setColor(1, 1, 1, flashAlpha)
        love.graphics.rectangle("fill", offsetX, offsetY, renderW, renderH)
      end
    else
      local img = getImage(currentSceneId)
      if img then
        drawImg(img, 1)
      end
    end

    love.graphics.setColor(r, g, b, a)
  end

  return api
end

return BetterScenes
