-- Shared Shadow Engine for BetterBattle and BetterScenes
-- Pure-Lua engine: measurement caching, schema normalization, profile evaluation, and primitive rendering.

local ShadowEngine = {}

ShadowEngine.SHADOW_STYLE = "soft-feathered-oval"
ShadowEngine.SHADOW_GLOBAL_OPACITY = 1.423125

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

-- Measurements are cached by image/canvas reference and measurement inputs.
-- Resolved states remain live because profile and instance tables are mutable.
local measurementCache = setmetatable({}, { __mode = "k" })

ShadowEngine.measurementCache = measurementCache

function ShadowEngine.clearCache()
  for k in pairs(measurementCache) do measurementCache[k] = nil end
end

local function clamp(value, minimum, maximum)
  return math.max(minimum, math.min(maximum, value))
end

local function firstDefined(primary, fallback)
  if primary ~= nil then return primary end
  return fallback
end

local function configValue(config, key, alias)
  if config[key] ~= nil then return config[key] end
  if alias and config[alias] ~= nil then return config[alias] end
  return nil
end

local function copyTable(source)
  if type(source) ~= "table" then return source end
  local copy = {}
  for key, value in pairs(source) do copy[key] = value end
  return copy
end

local function imageDimensions(image)
  if not image then return nil, nil end
  local getDimensions = image.getDimensions
  if type(getDimensions) == "function" then
    local ok, width, height = pcall(getDimensions, image)
    if ok then return width, height end
  end
  local getWidth, getHeight = image.getWidth, image.getHeight
  if type(getWidth) == "function" and type(getHeight) == "function" then
    local okW, width = pcall(getWidth, image)
    local okH, height = pcall(getHeight, image)
    if okW and okH then return width, height end
  end
  return nil, nil
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
    opacity = configValue(config, "opacity", "alpha"),
    opacityScale = configValue(config, "opacityScale"),
    color = configValue(config, "color"),
    grounding = configValue(config, "grounding"),
    anchorMode = configValue(config, "anchorMode"),
    anchorX = configValue(config, "anchorX"),
    manualAnchorX = configValue(config, "manualAnchorX"),
    manualContactY = configValue(config, "manualContactY"),
    baseWidth = configValue(config, "baseWidth"),
    baseHeight = configValue(config, "baseHeight"),
    widthScale = configValue(config, "widthScale"),
    heightScale = configValue(config, "heightScale"),
    offsetX = configValue(config, "offsetX"),
    offsetY = configValue(config, "offsetY"),
    rotationDegrees = configValue(config, "rotationDegrees"),
    bodyRegion = configValue(config, "bodyRegion"),
    shadowMode = configValue(config, "shadowMode"),
    innerRing = configValue(config, "innerRing"),
    middleRing = configValue(config, "middleRing"),
    soft = configValue(config, "soft"),
    sourceSpace = configValue(config, "sourceSpace"),
    shapeSpace = configValue(config, "shapeSpace"),
  }

  if config.wingShadows ~= nil then
    if config.wingShadows == false then
      norm.wingShadows = false
    elseif type(config.wingShadows) == "table" then
      local wings = {}
      for _, w in ipairs(config.wingShadows) do
        if type(w) == "table" then
          local wing = copyTable(w)
          wing.opacity = configValue(w, "opacity", "alpha")
          wings[#wings + 1] = wing
        end
      end
      norm.wingShadows = wings
    end
  end

  if config.shadowShapes == false then
    norm.shadowShapes = false
  elseif type(config.shadowShapes) == "table" then
    local shapes = {}
    for _, s in ipairs(config.shadowShapes) do
      if type(s) == "table" then
        local sh = {}
        for k, v in pairs(s) do sh[k] = v end
        sh.opacity = configValue(s, "opacity", "alpha")
        sh.width = configValue(s, "width", "w")
        sh.height = configValue(s, "height", "h")
        sh.soft = configValue(s, "soft")
        shapes[#shapes + 1] = sh
      end
    end
    norm.shadowShapes = shapes
  end

  return norm
end

--- Resolve the source-space anchor shared by every presentation consumer.
--- The returned coordinates remain in the caller's source-image space.
function ShadowEngine.resolveAnchor(footprint, opts)
  opts = opts or {}
  local sourceWidth = tonumber(opts.sourceWidth) or 0
  local sourceHeight = tonumber(opts.sourceHeight) or 0
  local originX = firstDefined(opts.originX, sourceWidth * 0.5)
  local originY = firstDefined(opts.originY, sourceHeight)
  local manualAnchorX = opts.manualAnchorX
  local manualContactY = opts.manualContactY

  if type(manualAnchorX) == "number"
      and type(manualContactY) == "number" then
    return {
      centerX = manualAnchorX,
      contactY = manualContactY,
      contactReliable = true,
      manual = true,
    }
  end

  if not footprint then
    return {
      centerX = originX,
      contactY = originY,
      contactReliable = false,
      fallback = true,
    }
  end

  local centerX = footprint.contactCenterX or footprint.centerX or originX
  local fullWidth = footprint.fullVisibleWidth or footprint.visibleWidth or 1
  local fullHeight = footprint.fullVisibleHeight or footprint.visibleHeight or 1
  local boundsCenter = footprint.boundsCenterX or footprint.centerX or originX
  local contactCoverage = (footprint.contactWidth or 0) / math.max(1, fullWidth)
  local contactOffset = math.abs(centerX - boundsCenter) / math.max(1, fullWidth)
  local minimumCoverage = firstDefined(opts.minimumContactCoverage, 0)
  local maximumOffset = firstDefined(opts.maximumContactOffset, 1)
  local contactReliable = contactCoverage >= minimumCoverage
    and contactOffset <= maximumOffset

  if opts.anchorMode == "body" then
    centerX = footprint.bodyCenterX or centerX
  elseif not contactReliable then
    if fullWidth >= fullHeight then
      centerX = boundsCenter
    else
      centerX = footprint.bodyCenterX
        or footprint.opaqueCentroidX
        or boundsCenter
    end
  end

  if type(opts.anchorX) == "number" then
    local visibleLeft = footprint.visibleLeft or 0
    local visibleRight = footprint.visibleRight or visibleLeft
    centerX = visibleLeft + (visibleRight - visibleLeft) * opts.anchorX
  end

  return {
    centerX = centerX,
    contactY = footprint.contactY or originY,
    contactReliable = contactReliable,
    manual = false,
  }
end

--- Resolve the automatic body ellipse in the caller's source coordinate space.
function ShadowEngine.resolveAutomaticBody(footprint, opts)
  opts = opts or {}
  local shape = opts.shape or ShadowEngine.SHADOW_SHAPE
  local fullWidth = footprint
    and (footprint.fullVisibleWidth or footprint.visibleWidth) or 32
  local fullHeight = footprint
    and (footprint.fullVisibleHeight or footprint.visibleHeight) or 32
  local majorExtent = math.max(fullWidth, fullHeight)
  local contactWidth = footprint and footprint.contactWidth or 16
  local sourceWidth = math.max(
    contactWidth * (opts.contactWidthScale or shape.contactWidthScale),
    fullWidth * (opts.spriteWidthScale or shape.bodyWidthScale),
    majorExtent * (opts.majorExtentScale or shape.bodyWidthScale))
  sourceWidth = clamp(sourceWidth,
    opts.minimumWidth or shape.minimumWidth,
    majorExtent * (opts.maximumBodyWidthScale or shape.maximumBodyWidthScale))
  local sourceHeight = clamp(
    sourceWidth * (opts.heightScalePolicy or shape.heightScale),
    opts.minimumHeight or shape.minimumHeight,
    opts.maximumHeight or shape.maximumHeight)
  local anchor = opts.anchor or footprint or { centerX = 0, contactY = 0 }
  local sourceX = anchor.centerX or 0
  local sourceY = anchor.contactY or 0
  local opacityScale = firstDefined(opts.opacityScale, ShadowEngine.SHADOW_GLOBAL_OPACITY)

  if opts.flying then
    sourceY = sourceY + (opts.flyingLift or shape.flyingLift)
    sourceWidth = sourceWidth * (opts.flyingWidthScale or shape.flyingWidthScale)
    sourceHeight = sourceHeight * (opts.flyingHeightScale or shape.flyingHeightScale)
    opacityScale = opacityScale * (opts.flyingAlphaScale or shape.flyingAlphaScale)
  end

  sourceX = sourceX + (opts.offsetX or 0)
  sourceY = sourceY + (opts.offsetY or 0)
  sourceWidth = math.max(opts.baseWidth or 0,
    sourceWidth * firstDefined(opts.widthScale, 1))
  sourceHeight = math.max(opts.baseHeight or 0,
    sourceHeight * firstDefined(opts.heightScale, 1))
  if footprint and footprint.automatic == true then
    local sizeScale = firstDefined(opts.sizeScale, 1)
    sourceWidth = sourceWidth * sizeScale
    sourceHeight = sourceHeight * sizeScale
  end

  return {
    x = sourceX,
    y = sourceY,
    width = sourceWidth,
    height = sourceHeight,
    alpha = opacityScale,
  }
end

--- Copy a shape and evaluate its optional dynamic callback consistently.
function ShadowEngine.evaluateShape(authored, context)
  local shape = copyTable(authored) or {}
  if type(authored) == "table" and type(authored.animate) == "function" then
    local ok, overrides = pcall(authored.animate, context or {})
    if ok and type(overrides) == "table" then
      for key, value in pairs(overrides) do shape[key] = value end
    end
  end
  return shape
end

--- Convert a footprint from image pixels into a declared source space.
function ShadowEngine.scaleMeasurement(footprint, scaleX, scaleY)
  if type(footprint) ~= "table" then return footprint end
  scaleX = tonumber(scaleX) or 1
  scaleY = tonumber(scaleY) or scaleX
  local scaled = copyTable(footprint)
  for _, key in ipairs({
      "centerX", "contactCenterX", "bodyCenterX", "visibleLeft",
      "visibleRight", "fullVisibleLeft", "fullVisibleRight",
      "boundsCenterX", "opaqueCentroidX",
    }) do
    if type(scaled[key]) == "number" then scaled[key] = scaled[key] * scaleX end
  end
  for _, key in ipairs({ "contactWidth", "visibleWidth", "fullVisibleWidth" }) do
    if type(scaled[key]) == "number" then
      scaled[key] = scaled[key] * math.abs(scaleX)
    end
  end
  for _, key in ipairs({ "contactY", "fullVisibleTop", "fullVisibleBottom" }) do
    if type(scaled[key]) == "number" then scaled[key] = scaled[key] * scaleY end
  end
  for _, key in ipairs({ "visibleHeight", "fullVisibleHeight" }) do
    if type(scaled[key]) == "number" then
      scaled[key] = scaled[key] * math.abs(scaleY)
    end
  end
  return scaled
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

--- Retrieves or measures a footprint using the shared measurement cache.
--- orientation may be { mirrorX = true }, -1, or legacy "player".
function ShadowEngine.getMeasurement(imageRef, region, orientation, alphaThreshold, cacheTag)
  if not imageRef then return nil end
  local threshold = alphaThreshold or 0.05
  local mirrorX = orientation == -1 or orientation == "player"
    or (type(orientation) == "table" and orientation.mirrorX == true)

  local regKey = "full"
  local normRegion = region
  if region then
    if mirrorX then
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
      mirrorX and "mirrored" or "normal")
  else
    regKey = mirrorX and "full:mirrored" or "full:normal"
  end

  local sig = regKey .. ":" .. tostring(threshold) .. ":" .. tostring(cacheTag or "stable")
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

--- Resolves profile, context, measurement, and instance data into geometry
--- relative to the source image's bottom-center origin. Consumers retain
--- ownership of stage/battle placement and final presentation controls.
function ShadowEngine.resolveShadowState(opts)
  opts = opts or {}
  local species = opts.species
  local context = opts.context or opts.side
  local image = opts.image
  local settings = opts.shadowSettings or rawget(_G, "betterBattleShadowSettings")
  if not settings then
    local ok, result = pcall(require, "better_battle_shadow_settings")
    if ok then settings = result end
  end

  local normCfg = ShadowEngine.normalizeConfig(opts.config)
  local schemaVersion = (settings and settings.schemaVersion) or 1
  local profileVersion = (settings and settings.profileVersion) or 1
  local profileId = species or "custom"

  if normCfg.enabled == false then
    return {
      enabled = false,
      mode = "disabled",
      species = species,
      context = context,
      profileId = profileId,
      profileVersion = profileVersion,
      schemaVersion = schemaVersion,
      shapes = {},
    }
  end

  local function value(key)
    if normCfg[key] ~= nil then return normCfg[key] end
    if species and settings and settings.value then
      return settings.value(species, context, key)
    end
    if settings and settings.defaults then return settings.defaults[key] end
    return nil
  end

  local imageWidth, imageHeight = imageDimensions(image)
  local profileEntry = species and settings and settings.species
    and settings.species[species] or nil
  local sourceSpace = opts.sourceSpace or normCfg.sourceSpace
  if sourceSpace == nil and profileEntry then
    sourceSpace = profileEntry.sourceSpace or settings.profileSpace
  end
  sourceSpace = type(sourceSpace) == "table" and copyTable(sourceSpace) or {}
  sourceSpace.width = tonumber(sourceSpace.width) or imageWidth or 0
  sourceSpace.height = tonumber(sourceSpace.height) or imageHeight or 0
  sourceSpace.originX = firstDefined(sourceSpace.originX, sourceSpace.width * 0.5)
  sourceSpace.originY = firstDefined(sourceSpace.originY, sourceSpace.height)

  local measurementScaleX = imageWidth and imageWidth > 0
    and sourceSpace.width / imageWidth or 1
  local measurementScaleY = imageHeight and imageHeight > 0
    and sourceSpace.height / imageHeight or 1
  local function toSourceMeasurement(measurement)
    if not measurement then return nil end
    if measurement.footprint then
      local sourceAnchor = measurement.anchor
      return {
        footprint = ShadowEngine.scaleMeasurement(
          measurement.footprint, measurementScaleX, measurementScaleY),
        anchor = sourceAnchor and {
          centerX = type(sourceAnchor.centerX) == "number"
            and sourceAnchor.centerX * measurementScaleX or nil,
          contactY = type(sourceAnchor.contactY) == "number"
            and sourceAnchor.contactY * measurementScaleY or nil,
        } or nil,
        reference = ShadowEngine.scaleMeasurement(
          measurement.reference, measurementScaleX, measurementScaleY),
      }
    end
    return ShadowEngine.scaleMeasurement(
      measurement, measurementScaleX, measurementScaleY)
  end

  local bodyRegion = value("bodyRegion")
  local footprint = toSourceMeasurement(opts.footprint
    or ShadowEngine.getMeasurement(
      image, bodyRegion, opts.sourceOrientation, opts.alphaThreshold, opts.measurementKey))

  local minimumCoverage = settings and settings.automaticBodyValue
    and settings.automaticBodyValue(species, context, "minimumContactCoverage") or 0
  local maximumOffset = settings and settings.automaticBodyValue
    and settings.automaticBodyValue(species, context, "maximumContactOffset") or 1
  local resolvedAnchor = ShadowEngine.resolveAnchor(footprint, {
    sourceWidth = sourceSpace.width,
    sourceHeight = sourceSpace.height,
    originX = sourceSpace.originX,
    originY = sourceSpace.originY,
    manualAnchorX = value("manualAnchorX"),
    manualContactY = value("manualContactY"),
    anchorMode = value("anchorMode"),
    anchorX = value("anchorX"),
    minimumContactCoverage = minimumCoverage,
    maximumContactOffset = maximumOffset,
  })
  local previousMeasurements = type(opts.measurementState) == "table"
    and opts.measurementState or {}
  local anchor = previousMeasurements.bodyAnchor or resolvedAnchor
  if footprint then footprint.contactReliable = anchor.contactReliable end
  local measurementState = {
    bodyAnchor = copyTable(anchor),
    shapes = {},
  }

  local shadowProfile = species and settings and settings.shadowProfile
    and settings.shadowProfile(species, context) or nil
  local authoredShapes = nil
  local shapeSpace = normCfg.shapeSpace
  local usingProfileShapes = false
  local resolvedMode
  if type(normCfg.shadowShapes) == "table" then
    authoredShapes = normCfg.shadowShapes
    shapeSpace = shapeSpace or "origin"
    resolvedMode = "customShapes"
  elseif normCfg.shadowShapes ~= false and shadowProfile then
    authoredShapes = shadowProfile.shapes
    shapeSpace = shapeSpace or "source"
    usingProfileShapes = true
    resolvedMode = "speciesProfile"
  elseif species then
    resolvedMode = "speciesAuto"
  elseif type(value("manualAnchorX")) == "number"
      and type(value("manualContactY")) == "number" then
    resolvedMode = "manual"
  else
    resolvedMode = "auto"
  end

  local grounding = value("grounding") or "grounded"
  local flying = grounding == "flying"
  local opacityScale = ShadowEngine.SHADOW_GLOBAL_OPACITY
    * (tonumber(value("opacityScale")) or 1)
  local configuredOpacity = value("opacity")
  if type(configuredOpacity) == "number" then
    opacityScale = opacityScale * (configuredOpacity / 0.075)
  end

  local shapes = {}
  if authoredShapes then
    for index, authored in ipairs(authoredShapes) do
      local enabled = not usingProfileShapes or not settings
        or not settings.shadowShapeEnabled
        or settings.shadowShapeEnabled(shadowProfile, authored)
      if enabled then
        local measurement = toSourceMeasurement(
          opts.shapeMeasurements and opts.shapeMeasurements[index])
        local needsMeasurement = authored.source == "detected"
          or (shadowProfile and shadowProfile.mode == "combined" and authored.detection)
        if needsMeasurement then
          local region = firstDefined(authored.region, bodyRegion)
          local measured = measurement and (measurement.footprint or measurement)
          if not measured then
            measured = toSourceMeasurement(ShadowEngine.getMeasurement(
              image, region, opts.sourceOrientation, opts.alphaThreshold,
              tostring(opts.measurementKey or "stable") .. ":shape:" .. tostring(index)))
          end
          if measured then
            local previous = previousMeasurements.shapes
              and previousMeasurements.shapes[index] or nil
            measurement = {
              footprint = measured,
              anchor = previous and previous.anchor
                or { centerX = measured.centerX, contactY = measured.contactY },
              reference = previous and previous.reference or measured,
            }
            measurementState.shapes[index] = measurement
          end
        end

        local shape = ShadowEngine.evaluateShape(authored, {
          sprite = opts.sprite,
          frame = opts.frame,
          side = context,
          context = context,
          species = species,
          measurement = measurement,
        })
        local measured = measurement and (measurement.footprint or measurement) or nil
        local available = shape.source == "manual" or measured ~= nil
        if available then
          local width = shape.width or value("baseWidth") or 16
          local height = shape.height or value("baseHeight") or 4.5
          local x, y = shape.x, shape.y

          if shape.source == "detected" and measured then
            if settings and settings.measuredDimensions then
              width, height = settings.measuredDimensions(
                species, context, shape, measured)
            else
              width = math.max(8, (measured.contactWidth or 1) * 1.30)
              height = width * 0.16
            end
            width = width * (shape.widthScale or 1)
            height = height * (shape.heightScale or 1)
            if shape.minWidth then width = math.max(shape.minWidth, width) end
            if shape.minHeight then height = math.max(shape.minHeight, height) end
            local measuredAnchor = measurement and measurement.anchor or measured
            x = firstDefined(x, measuredAnchor.centerX)
            y = firstDefined(y, measuredAnchor.contactY)
          end

          x = firstDefined(x, 0)
          y = firstDefined(y, 0)
          x = x + (shape.offsetX or 0) + (value("offsetX") or 0)
          y = y + (shape.offsetY or 0) + (value("offsetY") or 0)
          if shapeSpace == "source" then
            x = x - sourceSpace.originX
            y = y - sourceSpace.originY
          end
          width = width * (value("widthScale") or 1)
          height = height * (value("heightScale") or 1)

          local shapeOpacity = type(shape.opacity) == "number"
            and (shape.opacity / 0.075) or 1
          local shapeOpacityScale = tonumber(shape.opacityScale) or 1
          shapes[#shapes + 1] = {
            kind = shape.source or "manual",
            x = x,
            y = y,
            width = width,
            height = height,
            alpha = shapeOpacity * shapeOpacityScale * opacityScale,
            rotationDegrees = firstDefined(shape.rotationDegrees,
              value("rotationDegrees") or 0),
            innerRing = firstDefined(shape.innerRing, value("innerRing")),
            middleRing = firstDefined(shape.middleRing, value("middleRing")),
            soft = firstDefined(shape.soft, value("soft")) ~= false,
            color = firstDefined(shape.color, value("color")),
          }
        end
      end
    end
  else
    local spriteWidthScale = settings and settings.automaticBodyValue
      and settings.automaticBodyValue(species, context, "spriteWidthScale") or 0.44
    local majorExtentScale = settings and settings.automaticBodyValue
      and settings.automaticBodyValue(species, context, "majorExtentScale") or 0.44
    local sizeScale = settings and settings.automaticBodyValue
      and settings.automaticBodyValue(species, context, "sizeScale") or 1
    local body = ShadowEngine.resolveAutomaticBody(footprint, {
      anchor = anchor,
      flying = flying,
      spriteWidthScale = spriteWidthScale,
      majorExtentScale = majorExtentScale,
      offsetX = value("offsetX") or 0,
      offsetY = value("offsetY") or 0,
      baseWidth = value("baseWidth") or 12,
      baseHeight = value("baseHeight") or 3.75,
      widthScale = value("widthScale") or 1,
      heightScale = value("heightScale") or 1,
      sizeScale = sizeScale,
      opacityScale = opacityScale,
    })

    shapes[#shapes + 1] = {
      kind = "body",
      x = body.x - sourceSpace.originX,
      y = body.y - sourceSpace.originY,
      width = body.width,
      height = body.height,
      alpha = body.alpha,
      rotationDegrees = value("rotationDegrees") or 0,
      innerRing = value("innerRing"),
      middleRing = value("middleRing"),
      soft = value("soft") ~= false,
      color = value("color"),
    }
  end

  local wingSettings = normCfg.wingShadows
  if wingSettings == nil and species and settings and settings.wingShadows then
    wingSettings = settings.wingShadows(species, context)
  end
  if type(wingSettings) == "table" then
    for index, authoredWing in ipairs(wingSettings) do
      local wingMeasurement = toSourceMeasurement(opts.wingMeasurements
        and opts.wingMeasurements[index] or nil)
      local wing = ShadowEngine.evaluateShape(authoredWing, {
        sprite = opts.sprite,
        frame = opts.frame,
        side = context,
        context = context,
        species = species,
        measurement = wingMeasurement,
      })
      local wingFootprint = wingMeasurement
        and (wingMeasurement.footprint or wingMeasurement)
        or toSourceMeasurement(ShadowEngine.getMeasurement(
          image, wing.region, opts.sourceOrientation, opts.alphaThreshold,
          tostring(opts.measurementKey or "stable") .. ":wing:" .. tostring(index)))
      if wingFootprint then
        local width, height
        if settings and settings.measuredDimensions then
          width, height = settings.measuredDimensions(
            species, context, wing, wingFootprint)
        else
          width = math.max(8, (wingFootprint.contactWidth or 1) * 1.30)
          height = width * 0.16
        end
        width = width * (wing.widthScale or 1)
        height = height * (wing.heightScale or 1)
        local wingOpacity = type(wing.opacity) == "number"
          and (wing.opacity / 0.075) or 1
        shapes[#shapes + 1] = {
          kind = "wing",
          wingSide = index == 1 and "left" or "right",
          x = (wingFootprint.centerX or sourceSpace.originX)
            - sourceSpace.originX + (wing.offsetX or 0),
          y = anchor.contactY - sourceSpace.originY + (wing.offsetY or 0),
          width = width,
          height = height,
          alpha = wingOpacity * opacityScale,
          rotationDegrees = wing.rotationDegrees or 0,
          customRings = ShadowEngine.WING_SHADOW_RINGS,
          soft = true,
          color = firstDefined(wing.color, value("color")),
        }
      end
    end
  end

  return {
    enabled = true,
    mode = resolvedMode,
    species = species,
    context = context,
    profileId = profileId,
    profileVersion = profileVersion,
    schemaVersion = schemaVersion,
    footprint = footprint,
    anchor = anchor,
    sourceSpace = sourceSpace,
    measurementState = measurementState,
    grounding = grounding,
    shapes = shapes,
    rings = ShadowEngine.SHADOW_RINGS,
    color = value("color"),
    rawConfig = normCfg,
  }
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

--- Resolve one normalized shape into consumer presentation coordinates.
function ShadowEngine.transformShape(shape, transformOpts)
  transformOpts = transformOpts or {}
  local baseX = transformOpts.x or 0
  local baseY = transformOpts.y or 0
  local scaleX = transformOpts.scaleX or transformOpts.scale or 1
  local scaleY = transformOpts.scaleY or transformOpts.scale or 1
  local mirror = transformOpts.mirror == true
  local direction = transformOpts.direction
  if direction == nil then direction = mirror and -1 or 1 end
  direction = direction < 0 and -1 or 1
  local alphaScale = transformOpts.alphaScale
  if alphaScale == nil then alphaScale = 1 end

  return {
    x = baseX + (shape.x or 0) * scaleX * (mirror and -1 or 1),
    y = baseY + (shape.y or 0) * scaleY,
    width = (shape.width or 0) * math.abs(scaleX),
    height = (shape.height or 0) * math.abs(scaleY),
    alpha = (shape.alpha or 0) * alphaScale,
    direction = direction,
    rotationDegrees = shape.rotationDegrees or 0,
  }
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
  local drawn = {}
  for idx, shape in ipairs(shadowState.shapes) do
    local transformed = ShadowEngine.transformShape(shape, transformOpts)
    local finalX = transformed.x
    local finalY = transformed.y
    local finalW = transformed.width
    local finalH = transformed.height
    local finalAlpha = transformed.alpha
    local direction = transformed.direction
    local color = transformOpts.color or shape.color or shadowState.color

    if shape.soft ~= false then
      ShadowEngine.drawSoftShadow(g, finalX, finalY, finalW, finalH, finalAlpha,
        shape.innerRing, direction, shape.middleRing, shape.rotationDegrees,
        color, shape.customRings)
    else
      g.push("all")
      g.translate(finalX, finalY)
      g.rotate(math.rad(shape.rotationDegrees or 0) * direction)
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
