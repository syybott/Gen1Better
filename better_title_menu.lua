-- Keep the native title behind menu overlays, with independent UI scaling.
return function(deps)
  local PaletteFX = require("src.render.PaletteFX")
  local M = {}

  function M.isPanel(state)
    return state and (state.enhancedTitleMenu or state.enhancedTitleInfo)
  end

  function M.backgroundGame(game, title)
    local stack = setmetatable({ states = { title } }, { __index = game.stack })
    return setmetatable({ stack = stack }, { __index = game })
  end

  -- Scale the finished menu surface, after the engine's title fill mode has
  -- chosen its 100% size. The background uses separate native title metrics.
  function M.frameRects(renderer, rects, game)
    if not M.isPanel(game and game.stack and game.stack:top()) then
      return rects
    end
    local factor = deps.scaleFactor(game)
    if factor == 1 then return rects end
    local scale = rects.Up * factor
    rects.Up, rects.Ux, rects.Uy = scale,
      scale / rects.dpiX, scale / rects.dpiY
    rects.uvpw, rects.uvph = rects.uiw * rects.Ux,
      rects.uih * rects.Uy
    rects.uox = (rects.vx
      + math.floor((rects.pw - rects.uiw * scale) / 2)) / rects.dpiX
    rects.uoy = (rects.vy + math.max(0,
      math.floor((rects.ph - rects.uih * scale) / 2)
        - rects.lift)) / rects.dpiY
    return rects
  end

  local function removeTail(list, first)
    for i = #list, first, -1 do list[i] = nil end
  end

  -- Capture title pixels and their palette/sprite records together. Removing
  -- these records from the UI pass prevents Pikachu replaying over the menu.
  function M.capture(title, draw, zones)
    local renderer = title.game.renderer
    local layer = renderer.gen1BetterMenusTitleLayer
    if not layer then
      local canvas = love.graphics.newCanvas(160, 144)
      canvas:setFilter("nearest", "nearest")
      layer = { canvas = canvas }
      renderer.gen1BetterMenusTitleLayer = layer
    end
    layer.title = title
    local marks = PaletteFX.trueColorRects("ui")
    local redraws = PaletteFX.uiSpriteRedraws()
    local frameMarks = PaletteFX.gen1BetterMenusFrameMarks
    local frames = frameMarks and frameMarks.ui
    local firstMark, firstRedraw = #marks + 1, #redraws + 1
    local firstFrame = frames and #frames + 1
    local previousCanvas = love.graphics.getCanvas()
    local menuOpen = title.menuOpen
    local game = title.game
    love.graphics.push("all")
    local ok, err = pcall(function()
      love.graphics.setCanvas(layer.canvas)
      love.graphics.origin()
      love.graphics.setScissor()
      love.graphics.clear(0, 0, 0, 0)
      title.menuOpen = false
      -- Native title sprite helpers must see only the background, otherwise
      -- they suppress sprites that overlap an independently drawn menu.
      title.game = M.backgroundGame(game, title)
      draw(title)
    end)
    title.menuOpen = menuOpen
    title.game = game
    love.graphics.setCanvas(previousCanvas)
    love.graphics.pop()
    layer.zones = {}
    for _, zone in ipairs(PaletteFX.ensureZones(zones) or {}) do
      layer.zones[#layer.zones + 1] = zone
    end
    if PaletteFX.honorsTrueColor() then
      for i = firstMark, #marks do
        layer.zones[#layer.zones + 1] = marks[i]
      end
    end
    layer.redraws = {}
    for i = firstRedraw, #redraws do
      layer.redraws[#layer.redraws + 1] = redraws[i]
    end
    removeTail(marks, firstMark)
    removeTail(redraws, firstRedraw)
    if frames and frames ~= marks then removeTail(frames, firstFrame) end
    if not ok then
      layer.title = nil
      error(err, 0)
    end
    -- Only the menus remain in the main UI surface; the title is composited
    -- beneath them through the engine's existing world-override seam.
    love.graphics.clear(0, 0, 0, 0)
  end

  function M.compose(renderer, ctx, game)
    if not M.isPanel(game and game.stack and game.stack:top()) then return end
    local layer = renderer.gen1BetterMenusTitleLayer
    if not (layer and layer.title and layer.title.game == game) then return end
    local rects = deps.backdropRects(renderer)
    local canvas = layer.backdrop
    if not canvas or canvas:getWidth() ~= rects.pw
        or canvas:getHeight() ~= rects.ph then
      if canvas and canvas.release then canvas:release() end
      canvas = love.graphics.newCanvas(rects.pw, rects.ph)
      canvas:setFilter("nearest", "nearest")
      layer.backdrop = canvas
    end
    local previousCanvas = love.graphics.getCanvas()
    love.graphics.push("all")
    local ok, err = pcall(function()
      love.graphics.setCanvas(canvas)
      love.graphics.origin()
      love.graphics.setScissor()
      local colors = PaletteFX.effectiveColors(layer.zones[1]
        and layer.zones[1].colors or PaletteFX.GRAYS)
      local paper = colors and colors[1] or { 255, 255, 255 }
      love.graphics.clear(paper[1] / 255, paper[2] / 255,
        paper[3] / 255, 1)
      local scale = rects.Up
      local x = (rects.uox - rects.vux) * rects.dpiX
      local y = (rects.uoy - rects.vuy) * rects.dpiY
      love.graphics.setColor(1, 1, 1, 1)
      renderer:blitCanvas(layer.canvas, scale, scale, layer.zones,
        scale, scale, x, y, 0, 0, rects.pw, rects.ph, 1, 1)
      love.graphics.setShader()
      for _, redraw in ipairs(layer.redraws) do
        local clip = redraw.clip or { 0, 0, 160, 144 }
        love.graphics.setScissor(x + clip[1] * scale,
          y + clip[2] * scale, clip[3] * scale, clip[4] * scale)
        local color = redraw.color or { 1, 1, 1, 1 }
        love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
        local sx, sy = scale * (redraw.sx or 1),
          scale * (redraw.sy or 1)
        if redraw.quad then
          love.graphics.draw(redraw.image, redraw.quad,
            x + redraw.x * scale, y + redraw.y * scale, 0, sx, sy)
        else
          love.graphics.draw(redraw.image,
            x + redraw.x * scale, y + redraw.y * scale, 0, sx, sy)
        end
      end
      -- Match the engine's platform-specific override orientation.
      if renderer.mirrorsWorldOverride() then
        local flipped = layer.flipped
        if not flipped or flipped:getWidth() ~= rects.pw
            or flipped:getHeight() ~= rects.ph then
          if flipped and flipped.release then flipped:release() end
          flipped = love.graphics.newCanvas(rects.pw, rects.ph)
          flipped:setFilter("nearest", "nearest")
          layer.flipped = flipped
        end
        love.graphics.setCanvas(flipped)
        love.graphics.setScissor()
        love.graphics.clear(0, 0, 0, 0)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(canvas, 0, rects.ph, 0, 1, -1)
        canvas = flipped
      end
    end)
    love.graphics.setCanvas(previousCanvas)
    love.graphics.pop()
    if not ok then error(err, 0) end
    renderer:setWorldOverride(canvas)
  end

  local originalUpdate = deps.stack.update
  deps.stack.update = function(stack, dt)
    local top = stack:top()
    if M.isPanel(top) or (top and top.gen1BetterMenusTitleFlash) then
      for _, title in ipairs(stack.states or {}) do
        if getmetatable(title) == deps.TitleState and title.phase == "loop" then
          if title.yellowLayout then
            title:updateBlink()
          else
            title.timer = title.timer + 1
            title.blink = (title.blink + 1) % 60
            title:updateCycle()
          end
          break
        end
      end
    end
    return originalUpdate(stack, dt)
  end
  return M
end
