-- Shared Shadow Engine for BetterBattle and BetterScenes
-- Pure-Lua engine: measurement caching, schema normalization, profile evaluation, and primitive rendering.

local ShadowEngine = {}

ShadowEngine.SHADOW_STYLE = "soft-feathered-oval"
ShadowEngine.SHADOW_GLOBAL_OPACITY = 1.035

ShadowEngine.SHADOW_SHAPE = {
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

-- Existing BetterBattle ring constants preserved for zero visual drift
ShadowEngine.SHADOW_RINGS = {
  { scale = 1.00, alpha = 0.025 },
  { scale = 0.82, alpha = 0.050 },
  { scale = 0.64, alpha = 0.075 },
}

ShadowEngine.WING_SHADOW_RINGS = {
  { scale = 1.00, alpha = 0.012 },
  { scale = 0.90, alpha = 0.018 },
  { scale = 0.82, alpha = 0.022 },
}

-- Two-Tier Cache: Weakly keyed by image/canvas reference
local measurementCache = setmetatable({}, { __mode = "k" })
local resolvedCache = setmetatable({}, { __mode = "k" })

ShadowEngine.measurementCache = measurementCache
ShadowEngine.resolvedCache = resolvedCache

function ShadowEngine.clearCache()
  for k in pairs(measurementCache) do measurementCache[k] = nil end
  for k in pairs(resolvedCache) do resolvedCache[k] = nil end
end

local function clamp(value, minimum, maximum)
  return math.max(minimum, math.min(maximum, value))
end

local function serializeValue(v)
  local tv = type(v)
  if tv == "table" then
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local parts = {}
    for _, k in ipairs(keys) do
      parts[#parts + 1] = tostring(k) .. "=" .. serializeValue(v[k])
    end
    return "{" .. table.concat(parts, ",") .. "}"
  elseif tv == "function" or tv == "userdata" or tv == "thread" then
    return tv
  else
    return tostring(v)
  end
end

--- Normalizes incoming configuration, resolving top-level and nested aliases.
function ShadowEngine.normalizeConfig(config)
  if config == false then
    return { enabled = false }
  end
  if config == true or config == nil then
    return { enabled = true }
  end
  if type(config) ~= "table" then
    return { enabled = false }
  end

  local isEnabled = (config.enabled ~= false) and (config.shadow ~= false)
  local norm = {
    enabled = isEnabled,
    opacity = config.opacity or config.alpha or nil,
    opacityScale = config.opacityScale or nil,
    color = config.color or nil,
    grounding = config.grounding or nil,
    anchorMode = config.anchorMode or nil,
    anchorX = config.anchorX or nil,
    manualAnchorX = config.manualAnchorX or nil,
    manualContactY = config.manualContactY or nil,
    baseWidth = config.baseWidth or nil,
    baseHeight = config.baseHeight or nil,
    widthScale = config.widthScale or nil,
    heightScale = config.heightScale or nil,
    offsetX = config.offsetX or nil,
    offsetY = config.offsetY or nil,
    rotationDegrees = config.rotationDegrees or nil,
    bodyRegion = config.bodyRegion or nil,
    shadowMode = config.shadowMode or nil,
    innerRing = config.innerRing or nil,
    middleRing = config.middleRing or nil,
    soft = config.soft ~= false,
  }

  if config.wingShadows ~= nil then
    if config.wingShadows == false then
      norm.wingShadows = false
    elseif type(config.wingShadows) == "table" then
      local wings = {}
      for _, w in ipairs(config.wingShadows) do
        if type(w) == "table" then
          wings[#wings + 1] = {
            region = w.region,
            widthScale = w.widthScale,
            heightScale = w.heightScale,
            offsetX = w.offsetX,
            offsetY = w.offsetY,
            opacity = w.opacity or w.alpha or nil,
            rotationDegrees = w.rotationDegrees,
          }
        end
      end
      norm.wingShadows = wings
    end
  end

  if type(config.shadowShapes) == "table" then
    local shapes = {}
    for _, s in ipairs(config.shadowShapes) do
      if type(s) == "table" then
        local sh = {}
        for k, v in pairs(s) do sh[k] = v end
        sh.opacity = s.opacity or s.alpha or nil
        sh.width = s.width or s.w or nil
        sh.height = s.height or s.h or nil
        sh.soft = s.soft ~= false
        shapes[#shapes + 1] = sh
      end
    end
    norm.shadowShapes = shapes
  end

  return norm
end

--- Scans pixel alpha values to measure sprite footprint and contact line.
--- Guarantees caller-owned image data is never released; only temporary readbacks are released.
function ShadowEngine.measureFootprint(imageOrCanvas, region, alphaThreshold)
  if not imageOrCanvas then return nil end
  local threshold = alphaThreshold or 0.05

  local data = nil
  local shouldRelease = false
  local g = rawget(_G, "love") and love.graphics

  if type(imageOrCanvas.getDimensions) == "function" and type(imageOrCanvas.getPixel) == "function" then
    data = imageOrCanvas
    shouldRelease = false
  else
    local ok, res = pcall(function()
      if g and type(g.readbackTexture) == "function" then
        return g.readbackTexture(imageOrCanvas)
      end
      if type(imageOrCanvas.newImageData) == "function" then
        return imageOrCanvas:newImageData()
      end
      if type(imageOrCanvas.getData) == "function" then
        return imageOrCanvas:getData()
      end
    end)
    if ok and res then
      data = res
      shouldRelease = true
    end
  end

  if not data or type(data.getDimensions) ~= "function" or type(data.getPixel) ~= "function" then
    return nil
  end

  local width, height = data:getDimensions()
  local left, right, firstY, lastY = 0, width - 1, 0, height - 1
  local fullLeft, fullRight = width, -1
  local fullTop, fullBottom = height, -1
  local fullXSum, fullPixelCount = 0, 0

  if region then
    local x0, x1, y0, y1 = width, -1, height, -1
    for y = 0, height - 1 do
      for x = 0, width - 1 do
        local _, _, _, alpha = data:getPixel(x, y)
        if alpha and alpha > threshold then
          x0, x1 = math.min(x0, x), math.max(x1, x)
          y0, y1 = math.min(y0, y), math.max(y1, y)
          fullXSum = fullXSum + x + 0.5
          fullPixelCount = fullPixelCount + 1
        end
      end
    end
    if x1 < x0 then
      if shouldRelease and data.release then data:release() end
      return nil
    end
    fullLeft, fullRight = x0, x1
    fullTop, fullBottom = y0, y1
    local w, h = x1 - x0 + 1, y1 - y0 + 1
    left = math.max(x0, math.floor(x0 + w * (region.left or 0)))
    right = math.min(x1, math.ceil(x0 + w * (region.right or 1)) - 1)
    firstY = math.max(y0, math.floor(y0 + h * (region.top or 0)))
    lastY = math.min(y1, math.ceil(y0 + h * (region.bottom or 1)) - 1)
  end

  local minX, maxX = width, -1
  local top, absoluteBottom = height, -1
  local regionXSum, regionPixelCount = 0, 0
  local rows = {}

  for y = firstY, lastY do
    local count, longest, run = 0, 0, 0
    local rowLeft, rowRight = right + 1, left - 1
    for x = left, right do
      local _, _, _, alpha = data:getPixel(x, y)
      if alpha and alpha > threshold then
        count = count + 1
        run = run + 1
        longest = math.max(longest, run)
        minX, maxX = math.min(minX, x), math.max(maxX, x)
        rowLeft, rowRight = math.min(rowLeft, x), math.max(rowRight, x)
        top, absoluteBottom = math.min(top, y), math.max(absoluteBottom, y)
        regionXSum = regionXSum + x + 0.5
        regionPixelCount = regionPixelCount + 1
      else
        run = 0
      end
    end
    rows[y] = { count = count, longest = longest, left = rowLeft, right = rowRight }
  end

  if absoluteBottom < 0 then
    if shouldRelease and data.release then data:release() end
    return nil
  end

  if not region then
    fullLeft, fullRight = minX, maxX
    fullTop, fullBottom = top, absoluteBottom
    fullXSum, fullPixelCount = regionXSum, regionPixelCount
  end

  local visibleWidth = maxX - minX + 1
  local visibleHeight = absoluteBottom - top + 1
  local fullVisibleWidth = fullRight - fullLeft + 1
  local fullVisibleHeight = fullBottom - fullTop + 1
  local boundsCenterX = (fullLeft + fullRight + 1) / 2
  local opaqueCentroidX = (fullPixelCount > 0) and (fullXSum / fullPixelCount) or boundsCenterX
  local supportPixels = math.max(3, math.floor(visibleWidth * 0.08 + 0.5))
  local contactY = absoluteBottom

  for y = absoluteBottom, top, -1 do
    local row = rows[y]
    if row and row.count >= supportPixels and row.longest >= 2 then
      contactY = y
      break
    end
  end

  local contactHeight = contactY - top + 1
  local bandDepth = math.max(2, math.min(5, math.floor(contactHeight * 0.10 + 0.5)))
  local samples = {}

  for y = math.max(top, contactY - bandDepth + 1), contactY do
    for x = minX, maxX do
      local _, _, _, alpha = data:getPixel(x, y)
      if alpha and alpha > threshold then
        samples[#samples + 1] = x
      end
    end
  end

  if shouldRelease and data.release then data:release() end
  if #samples == 0 then return nil end
  table.sort(samples)

  local function sampleAt(fraction)
    local index = math.floor((#samples - 1) * fraction + 1.5)
    return samples[math.max(1, math.min(#samples, index))]
  end

  local contactLeft = sampleAt(0.15)
  local contactRight = sampleAt(0.85)
  local contactCenterX = (contactLeft + contactRight + 1) / 2

  local bodyCenters = {}
  local bodyPixelThreshold = math.max(2, math.floor(visibleWidth * 0.12 + 0.5))
  local bodyTop = top + math.floor(visibleHeight * 0.25)
  local bodyBottom = math.min(contactY - bandDepth, top + math.floor(visibleHeight * 0.75))

  if bodyBottom >= bodyTop then
    for y = bodyTop, bodyBottom do
      local row = rows[y]
      if row and row.count >= bodyPixelThreshold and row.longest >= 2 then
        bodyCenters[#bodyCenters + 1] = (row.left + row.right + 1) / 2
      end
    end
  end

  local bodyCenterX = contactCenterX
  if #bodyCenters > 0 then
    table.sort(bodyCenters)
    local middle = (#bodyCenters + 1) / 2
    if #bodyCenters % 2 == 1 then
      bodyCenterX = bodyCenters[math.ceil(middle)]
    else
      bodyCenterX = (bodyCenters[math.floor(middle)] + bodyCenters[math.ceil(middle)]) / 2
    end
  end

  return {
    automatic = true,
    centerX = contactCenterX,
    contactCenterX = contactCenterX,
    bodyCenterX = bodyCenterX,
    contactY = contactY + 0.5,
    contactWidth = math.max(1, contactRight - contactLeft + 1),
    visibleWidth = visibleWidth,
    visibleHeight = visibleHeight,
    visibleLeft = minX,
    visibleRight = maxX,
    fullVisibleWidth = fullVisibleWidth,
    fullVisibleHeight = fullVisibleHeight,
    fullVisibleLeft = fullLeft,
    fullVisibleRight = fullRight,
    fullVisibleTop = fullTop,
    fullVisibleBottom = fullBottom,
    boundsCenterX = boundsCenterX,
    opaqueCentroidX = opaqueCentroidX,
  }
end

--- Retrieves or measures sprite footprint using Tier 1 Measurement Cache.
function ShadowEngine.getMeasurement(imageRef, region, side, alphaThreshold)
  if not imageRef then return nil end
  local threshold = alphaThreshold or 0.05

  local regKey = "full"
  local normRegion = region
  if region then
    if side == "player" then
      normRegion = {
        left = 1 - (region.right or 1),
        right = 1 - (region.left or 0),
        top = region.top or 0,
        bottom = region.bottom or 1,
      }
    end
    regKey = string.format("%.3f:%.3f:%.3f:%.3f:%s",
      normRegion.left or 0, normRegion.right or 1,
      normRegion.top or 0, normRegion.bottom or 1,
      tostring(side or "default"))
  else
    regKey = "full:" .. tostring(side or "default")
  end

  local sig = regKey .. ":" .. tostring(threshold)
  local imgBucket = measurementCache[imageRef]
  if not imgBucket then
    imgBucket = {}
    measurementCache[imageRef] = imgBucket
  end

  if imgBucket[sig] ~= nil then
    return imgBucket[sig] or nil
  end

  local measured = ShadowEngine.measureFootprint(imageRef, normRegion, threshold)
  imgBucket[sig] = measured or false
  return measured
end

--- Resolves full shadow state telemetry and shape definitions.
function ShadowEngine.resolveShadowState(opts)
  opts = opts or {}
  local species = opts.species
  local side = opts.side or "enemy"
  local image = opts.image
  local settings = opts.shadowSettings or rawget(_G, "betterBattleShadowSettings")
  if not settings then
    local ok, res = pcall(require, "better_battle_shadow_settings")
    if ok then settings = res end
  end

  local normCfg = ShadowEngine.normalizeConfig(opts.config)
  if normCfg.enabled == false then
    return {
      enabled = false,
      mode = "disabled",
      species = species,
      profileId = species or "custom",
      profileVersion = settings and settings.profileVersion or 1,
      schemaVersion = settings and settings.schemaVersion or 1,
      shapes = {},
    }
  end

  local schemaVer = (settings and settings.schemaVersion) or 1
  local profileVer = (settings and settings.profileVersion) or 1
  local profileId = species or "custom"

  -- Tier 2: Comprehensive Resolved-State Signature
  local resSig = string.format("%s:%s:%d:%d:%s:%s:%s:%s:%s:%s:%s:%s:%s:%s:%s:%s:%s:%s:%s:%s:%s:%s:%s",
    tostring(species), tostring(side), profileVer, schemaVer,
    tostring(normCfg.manualAnchorX), tostring(normCfg.manualContactY),
    tostring(normCfg.anchorMode), tostring(normCfg.anchorX),
    tostring(normCfg.baseWidth), tostring(normCfg.baseHeight),
    tostring(normCfg.widthScale), tostring(normCfg.heightScale),
    tostring(normCfg.offsetX), tostring(normCfg.offsetY),
    tostring(normCfg.rotationDegrees), tostring(normCfg.opacity),
    tostring(normCfg.grounding), tostring(normCfg.shadowMode),
    tostring(normCfg.soft),
    serializeValue(normCfg.bodyRegion),
    serializeValue(normCfg.wingShadows),
    serializeValue(normCfg.shadowShapes),
    serializeValue(normCfg.innerRing) .. ":" .. serializeValue(normCfg.middleRing) .. ":" .. serializeValue(normCfg.color))

  if image then
    local resBucket = resolvedCache[image]
    if resBucket and resBucket[resSig] then
      return resBucket[resSig]
    end
  end

  local function val(key)
    if normCfg[key] ~= nil then return normCfg[key] end
    if species and settings and settings.value then
      return settings.value(species, side, key)
    end
    if settings and settings.defaults then
      return settings.defaults[key]
    end
    return nil
  end

  local bodyRegion = val("bodyRegion")
  local footprint = ShadowEngine.getMeasurement(image, bodyRegion, side)
  local shapes = {}

  -- Disambiguate mode labels
  local shadowProfile = (species and settings and settings.shadowProfile and settings.shadowProfile(species, side))
  local resolvedMode = "auto"
  if normCfg.shadowShapes then
    resolvedMode = "customShapes"
  elseif shadowProfile then
    resolvedMode = "speciesProfile"
  elseif species and settings and settings.species and settings.species[species] then
    resolvedMode = "speciesAuto"
  elseif species then
    resolvedMode = "speciesAuto"
  elseif normCfg.manualAnchorX or normCfg.manualContactY then
    resolvedMode = "manual"
  else
    resolvedMode = "auto"
  end

  local grounding = val("grounding") or "grounded"
  local flying = (grounding == "flying")
  local opacityScale = ShadowEngine.SHADOW_GLOBAL_OPACITY * (val("opacityScale") or 1)
  if normCfg.opacity then
    opacityScale = opacityScale * (normCfg.opacity / 0.075)
  end

  if normCfg.shadowShapes or (shadowProfile and shadowProfile.shapes) then
    local authoredShapes = normCfg.shadowShapes or shadowProfile.shapes
    for _, authored in ipairs(authoredShapes) do
      local shape = {}
      for k, v in pairs(authored) do shape[k] = v end

      local width = shape.width or val("baseWidth") or 16
      local height = shape.height or val("baseHeight") or 4.5
      local x = shape.x or 0
      local y = shape.y or 0

      if shape.source == "detected" and footprint then
        local sz = function(k)
          if shape.detectionSizing and shape.detectionSizing[k] ~= nil then
            return shape.detectionSizing[k]
          end
          if settings and settings.detectionSizing then
            return settings.detectionSizing(species, side, shape, k)
          end
          return ShadowEngine.SHADOW_SHAPE[k]
        end
        local mWidth = math.max(
          footprint.contactWidth * (sz("contactWidthScale") or 1.3),
          footprint.visibleWidth * (sz("bodyWidthScale") or 0.44))
        local minW = sz("minimumWidth")
        local maxW = sz("maximumWidthScale")
        if minW ~= false and minW then mWidth = math.max(minW, mWidth) end
        if maxW ~= false and maxW then mWidth = math.min(footprint.visibleWidth * maxW, mWidth) end
        local mHeight = mWidth * (sz("heightScale") or 0.16)
        width = mWidth * (shape.widthScale or 1)
        height = mHeight * (shape.heightScale or 1)
        if x == 0 and shape.x == nil then
          x = (footprint.centerX or 28) - 28
          if side == "player" then x = -x end
        end
        if y == 0 and shape.y == nil then
          y = (footprint.contactY or 56) - 56
        end
      end

      x = x + (shape.offsetX or 0) + (val("offsetX") or 0)
      y = y + (shape.offsetY or 0) + (val("offsetY") or 0)
      width = width * (shape.widthScale or 1) * (val("widthScale") or 1)
      height = height * (shape.heightScale or 1) * (val("heightScale") or 1)

      local shAlpha = (shape.opacity and (shape.opacity / 0.075) or 1) * opacityScale
      shapes[#shapes + 1] = {
        kind = shape.source or "manual",
        x = x,
        y = y,
        width = width,
        height = height,
        alpha = shAlpha,
        rotationDegrees = shape.rotationDegrees or val("rotationDegrees") or 0,
        innerRing = shape.innerRing or val("innerRing"),
        middleRing = shape.middleRing or val("middleRing"),
        soft = shape.soft ~= false,
      }
    end
  else
    -- Standard / Footprint body shadow
    local fullWidth = footprint and (footprint.fullVisibleWidth or footprint.visibleWidth) or 32
    local fullHeight = footprint and (footprint.fullVisibleHeight or footprint.visibleHeight) or 32
    local majorExtent = math.max(fullWidth, fullHeight)

    local spWScale = (settings and settings.automaticBodyValue and settings.automaticBodyValue(species, side, "spriteWidthScale")) or 0.44
    local majScale = (settings and settings.automaticBodyValue and settings.automaticBodyValue(species, side, "majorExtentScale")) or 0.44

    local contactW = footprint and footprint.contactWidth or 16
    local sourceWidth = math.max(
      contactW * ShadowEngine.SHADOW_SHAPE.contactWidthScale,
      fullWidth * spWScale,
      majorExtent * majScale)

    sourceWidth = clamp(sourceWidth,
      ShadowEngine.SHADOW_SHAPE.minimumWidth,
      majorExtent * ShadowEngine.SHADOW_SHAPE.maximumBodyWidthScale)
    local sourceHeight = clamp(
      sourceWidth * ShadowEngine.SHADOW_SHAPE.heightScale,
      ShadowEngine.SHADOW_SHAPE.minimumHeight,
      ShadowEngine.SHADOW_SHAPE.maximumHeight)

    local sourceX = 0
    local sourceY = 0

    if flying then
      sourceY = sourceY + ShadowEngine.SHADOW_SHAPE.flyingLift
      sourceWidth = sourceWidth * ShadowEngine.SHADOW_SHAPE.flyingWidthScale
      sourceHeight = sourceHeight * ShadowEngine.SHADOW_SHAPE.flyingHeightScale
      opacityScale = opacityScale * ShadowEngine.SHADOW_SHAPE.flyingAlphaScale
    end

    sourceX = sourceX + (val("offsetX") or 0)
    sourceY = sourceY + (val("offsetY") or 0)
    sourceWidth = math.max(val("baseWidth") or 12, sourceWidth * (val("widthScale") or 1))
    sourceHeight = math.max(val("baseHeight") or 3.75, sourceHeight * (val("heightScale") or 1))

    if footprint and footprint.automatic == true and settings and settings.automaticBodyValue then
      local bodyScale = settings.automaticBodyValue(species, side, "sizeScale") or 1
      sourceWidth = sourceWidth * bodyScale
      sourceHeight = sourceHeight * bodyScale
    end

    shapes[#shapes + 1] = {
      kind = "body",
      x = sourceX,
      y = sourceY,
      width = sourceWidth,
      height = sourceHeight,
      alpha = opacityScale,
      rotationDegrees = val("rotationDegrees") or 0,
      innerRing = val("innerRing"),
      middleRing = val("middleRing"),
      soft = val("soft") ~= false,
    }

    -- Wing Shadows
    local wingSettings = normCfg.wingShadows
    if wingSettings == nil and species and settings and settings.wingShadows then
      wingSettings = settings.wingShadows(species, side)
    end

    if wingSettings and type(wingSettings) == "table" then
      for wIdx, wing in ipairs(wingSettings) do
        local wingFootprint = ShadowEngine.getMeasurement(image, wing.region, side)
        local wWidth, wHeight = 12, 3.5
        if wingFootprint and settings and settings.measuredDimensions then
          wWidth, wHeight = settings.measuredDimensions(species, side, wing, wingFootprint)
        elseif wingFootprint then
          wWidth = math.max(8, wingFootprint.contactWidth * 1.30)
          wHeight = wWidth * 0.16
        end
        wWidth = wWidth * (wing.widthScale or 1)
        wHeight = wHeight * (wing.heightScale or 1)
        local wx = (wing.offsetX or 0)
        local wy = (wing.offsetY or 0)
        local wAlpha = (wing.opacity and (wing.opacity / 0.075) or 1) * opacityScale

        shapes[#shapes + 1] = {
          kind = "wing",
          wingSide = (wIdx == 1 and "left") or "right",
          x = wx,
          y = wy,
          width = wWidth,
          height = wHeight,
          alpha = wAlpha,
          rotationDegrees = wing.rotationDegrees or 0,
          customRings = ShadowEngine.WING_SHADOW_RINGS,
          soft = true,
        }
      end
    end
  end

  local state = {
    enabled = true,
    mode = resolvedMode,
    species = species,
    profileId = profileId,
    profileVersion = profileVer,
    schemaVersion = schemaVer,
    footprint = footprint,
    grounding = grounding,
    shapes = shapes,
    rings = ShadowEngine.SHADOW_RINGS,
    rawConfig = normCfg,
  }

  if image then
    local resBucket = resolvedCache[image]
    if not resBucket then
      resBucket = {}
      resolvedCache[image] = resBucket
    end
    resBucket[resSig] = state
  end

  return state
end

--- Feathered multi-ring oval rendering primitive.
--- directionOrSide: -1 or 1 (number), or legacy "player" (-1) / "enemy" (1).
function ShadowEngine.drawSoftShadow(g, x, y, width, height, alphaScale,
    innerRing, directionOrSide, middleRing, rotationDegrees, color, customRings)
  if not g or not g.ellipse then return end
  local rings = customRings or ShadowEngine.SHADOW_RINGS

  local direction = 1
  if type(directionOrSide) == "number" then
    direction = (directionOrSide < 0) and -1 or 1
  elseif directionOrSide == "player" then
    direction = -1
  end

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
    local tuning = (index == #rings and innerRing) or (index == 2 and middleRing)
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

--- Pure renderer for already-resolved shadowState with graphics state isolation.
--- transformOpts: x, y, scale, scaleX, scaleY, mirror, direction, alphaScale, color
function ShadowEngine.renderShadowState(g, shadowState, transformOpts)
  if not shadowState or not shadowState.enabled or not shadowState.shapes then
    return {}
  end
  if not g or not g.ellipse then return {} end

  local hasPush = (type(g.push) == "function") and (type(g.pop) == "function")
  if hasPush then
    pcall(g.push, "all")
  end

  transformOpts = transformOpts or {}
  local baseX = transformOpts.x or 0
  local baseY = transformOpts.y or 0
  local scaleX = transformOpts.scaleX or transformOpts.scale or 1
  local scaleY = transformOpts.scaleY or transformOpts.scale or 1
  local mirror = transformOpts.mirror or false
  local alphaMul = (transformOpts.alphaScale ~= nil) and transformOpts.alphaScale or 1
  local color = transformOpts.color or nil

  -- Pure geometric direction: explicitly supplied or derived from mirror
  local direction = transformOpts.direction or (mirror and -1 or 1)

  local drawn = {}
  for idx, shape in ipairs(shadowState.shapes) do
    local sx = shape.x * scaleX * (mirror and -1 or 1)
    local sy = shape.y * scaleY
    local finalX = baseX + sx
    local finalY = baseY + sy
    local finalW = shape.width * scaleX
    local finalH = shape.height * scaleY
    local finalAlpha = shape.alpha * alphaMul

    if shape.soft ~= false then
      ShadowEngine.drawSoftShadow(g, finalX, finalY, finalW, finalH, finalAlpha,
        shape.innerRing, direction, shape.middleRing, shape.rotationDegrees,
        color, shape.customRings)
    else
      g.push("all")
      g.translate(finalX, finalY)
      local dir = (mirror and -1 or 1) * direction
      g.rotate(math.rad(shape.rotationDegrees or 0) * dir)
      local cr, cg, cb = 0, 0, 0
      if type(color) == "table" then
        cr = tonumber(color[1] or color.r) or 0
        cg = tonumber(color[2] or color.g) or 0
        cb = tonumber(color[3] or color.b) or 0
      end
      g.setColor(cr, cg, cb, finalAlpha)
      g.ellipse("fill", 0, 0, finalW / 2, finalH / 2)
      g.pop()
    end

    drawn[#drawn + 1] = {
      shapeIndex = idx,
      x = finalX,
      y = finalY,
      width = finalW,
      height = finalH,
      alpha = finalAlpha,
    }
  end

  if hasPush then
    pcall(g.pop)
  end

  return drawn
end

return ShadowEngine
