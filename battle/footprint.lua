-- Internal BetterBattle module. Fallback sprite measurement; delegates to the shared shadow engine when installed.
-- Loaded once by better_battle_hud.lua; not a public consumer API.
return function(deps)
  local M = {}
  local betterBattleApi = deps.betterBattleApi

  -- Convert captured-layer measurements into the authored reference units.
  -- Copy the result so the detector's measurement remains unchanged.
  function M.inProfileSpace(footprint, transform)
    if not footprint or not transform then return footprint end
    local sx, sy = transform.scaleX, transform.scaleY
    if sx == 0 or sy == 0 then return nil end
    local result = {}
    for key, value in pairs(footprint) do result[key] = value end
    for _, key in ipairs({
      "centerX", "contactCenterX", "bodyCenterX", "visibleLeft",
      "visibleRight", "fullVisibleLeft", "fullVisibleRight",
      "boundsCenterX", "opaqueCentroidX",
    }) do
      if type(result[key]) == "number" then
        result[key] = (result[key] - transform.x) / sx
      end
    end
    for _, key in ipairs({ "contactY", "fullVisibleTop", "fullVisibleBottom" }) do
      if type(result[key]) == "number" then
        result[key] = (result[key] - transform.y) / sy
      end
    end
    for _, key in ipairs({ "contactWidth", "visibleWidth", "fullVisibleWidth" }) do
      if type(result[key]) == "number" then
        result[key] = result[key] / math.abs(sx)
      end
    end
    for _, key in ipairs({ "visibleHeight", "fullVisibleHeight" }) do
      if type(result[key]) == "number" then
        result[key] = result[key] / math.abs(sy)
      end
    end
    if sx < 0 then
      result.visibleLeft, result.visibleRight =
        result.visibleRight, result.visibleLeft
      result.fullVisibleLeft, result.fullVisibleRight =
        result.fullVisibleRight, result.fullVisibleLeft
    end
    if sy < 0 then
      result.fullVisibleTop, result.fullVisibleBottom =
        result.fullVisibleBottom, result.fullVisibleTop
    end
    return result
  end

  -- Measure the completed detached sprite, not its nominal 64x64 slot.
  -- The contact band determines vertical grounding. A separate torso
  -- window determines the stable body-center X anchor.
  function M.measureShadowFootprint(canvas, region)
    local shadowEngine = betterBattleApi and betterBattleApi.shadowEngine
    if shadowEngine and type(shadowEngine.measureFootprint) == "function" then
      return shadowEngine.measureFootprint(canvas, region)
    end

    -- Installation safety net. The normal BetterBattle path always uses the
    -- shared engine installed by better_battle_backdrops.lua.
    local g = love.graphics
    local ok, data = pcall(function()
      if type(g.readbackTexture) == "function" then return g.readbackTexture(canvas) end
      if type(canvas.newImageData) == "function" then return canvas:newImageData() end
    end)
    if not ok or not data then return nil end

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
          if alpha > 0.05 then
            x0, x1 = math.min(x0, x), math.max(x1, x)
            y0, y1 = math.min(y0, y), math.max(y1, y)
            fullXSum = fullXSum + x + 0.5
            fullPixelCount = fullPixelCount + 1
          end
        end
      end
      if x1 < x0 then
        data:release()
        return nil
      end
      fullLeft, fullRight = x0, x1
      fullTop, fullBottom = y0, y1
      local w, h = x1 - x0 + 1, y1 - y0 + 1
      left = math.max(x0, math.floor(x0 + w * region.left))
      right = math.min(x1, math.ceil(x0 + w * region.right) - 1)
      firstY = math.max(y0, math.floor(y0 + h * region.top))
      lastY = math.min(y1, math.ceil(y0 + h * region.bottom) - 1)
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
        if alpha > 0.05 then
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
      rows[y] = {
        count = count,
        longest = longest,
        left = rowLeft,
        right = rowRight,
      }
    end

    if absoluteBottom < 0 then
      data:release()
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
    local opaqueCentroidX = fullXSum / fullPixelCount
    local supportPixels = math.max(3, math.floor(visibleWidth * 0.08 + 0.5))
    local contactY = absoluteBottom

    -- Ignore a lowest row made only from isolated decorative pixels.
    for y = absoluteBottom, top, -1 do
      local row = rows[y]
      if row.count >= supportPixels and row.longest >= 2 then
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
        if alpha > 0.05 then samples[#samples + 1] = x end
      end
    end

    data:release()
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

  return M
end
