-- FireRed-inspired frame art for Gen1Better.  Source PNGs stay untouched;
-- transparency and palette variants are built once, in memory.
return function(mod, menuPalette)
  local Font = require("src.render.Font")
  local PaletteFX = require("src.render.PaletteFX")
  local TextBox = require("src.render.TextBox")
  local root = mod.path .. "/assets/frames/"
  local stockDrawBox = Font.drawBox
  local sourceCache, imageCache = {}, {}
  local names = { og = {}, hybrid = {}, fr = {} }
  local choices = { { "DEFAULT", "og:default" } }
  local role
  local frameRects = {}
  local drawingText = false
  local drawingStockBox = false

  local function canvas()
    return love.graphics.getCanvas and love.graphics.getCanvas() or nil
  end

  local function rememberFrame(x, y, w, h, section, side)
    frameRects[#frameRects + 1] = {
      x = x, y = y, w = w, h = h, canvas = canvas(),
      top = section ~= "lower", bottom = section ~= "head",
      side = side or 8,
    }
  end

  local function paddedPosition(x, y, w)
    local current = canvas()
    for i = #frameRects, 1, -1 do
      local frame = frameRects[i]
      if frame.canvas == current and x >= frame.x and x < frame.x + frame.w
          and y >= frame.y and y < frame.y + frame.h then
        local left = frame.x + frame.side + 2
        local right = frame.x + frame.w - frame.side - 2
        local top = frame.top and frame.y + 10 or frame.y
        local bottom = frame.bottom and frame.y + frame.h - 10
          or frame.y + frame.h
        if w <= right - left and bottom - top >= 8 then
          return math.max(left, math.min(x, right - w)),
            math.max(top, math.min(y, bottom - 8))
        end
        break
      end
    end
    return x, y
  end

  -- Renderer:endFrame consults these PaletteFX accessors.  In Gen 1 it
  -- normally honors true-color marks only in Red++ mode; BetterFrames needs
  -- its border marks in every mode without enabling unrelated sprite marks.
  local marks = PaletteFX.gen1BetterMenusFrameMarks
  if not marks then
    marks = { ui = {}, world = {} }
    local originalRects = PaletteFX.trueColorRects
    local originalHonors = PaletteFX.honorsTrueColor
    local originalClear = PaletteFX.clearTrueColor
    function marks.add(x, y, w, h)
      local ui, world = originalRects("ui"), originalRects("world")
      local uiCount, worldCount = #ui, #world
      PaletteFX.markTrueColor(x, y, w, h)
      if #ui > uiCount then
        marks.ui[#marks.ui + 1] = ui[#ui]
      elseif #world > worldCount then
        marks.world[#marks.world + 1] = world[#world]
      end
    end
    PaletteFX.honorsTrueColor = function()
      return originalHonors() or #marks.ui > 0 or #marks.world > 0
    end
    PaletteFX.trueColorRects = function(pass)
      if originalHonors() then return originalRects(pass) end
      return marks[pass] or {}
    end
    PaletteFX.clearTrueColor = function(...)
      if marks.resetFrameRects then marks.resetFrameRects() end
      for _, pass in ipairs({ "ui", "world" }) do
        for i = #marks[pass], 1, -1 do marks[pass][i] = nil end
      end
      return originalClear(...)
    end
    function marks.cover(x, y, w, h)
      local function clip(list)
        local oldCount = #list
        for i = oldCount, 1, -1 do
          local rect = list[i]
          local x1, y1 = math.max(x, rect.x), math.max(y, rect.y)
          local x2 = math.min(x + w, rect.x + rect.w)
          local y2 = math.min(y + h, rect.y + rect.h)
          if x1 < x2 and y1 < y2 then
            table.remove(list, i)
            local pieces = {
              { rect.x, rect.y, rect.w, y1 - rect.y },
              { rect.x, y2, rect.w, rect.y + rect.h - y2 },
              { rect.x, y1, x1 - rect.x, y2 - y1 },
              { x2, y1, rect.x + rect.w - x2, y2 - y1 },
            }
            for _, piece in ipairs(pieces) do
              if piece[3] > 0 and piece[4] > 0 then
                list[#list + 1] = { colors = false, x = piece[1],
                  y = piece[2], w = piece[3], h = piece[4] }
              end
            end
          end
        end
      end
      clip(marks.ui)
      if originalHonors() then clip(originalRects("ui")) end
    end
    PaletteFX.gen1BetterMenusFrameMarks = marks
  end
  marks.resetFrameRects = function()
    for i = #frameRects, 1, -1 do frameRects[i] = nil end
  end

  -- Visible source RGB -> the corresponding BGR555 value written by the IPS,
  -- expanded to 8-bit channels.  Frame 2 keeps its supplied source palette.
  local frPatch = {
    box1 = {
      ["156:156:173"] = { 156, 156, 172 },
      ["66:66:82"] = { 65, 65, 82 },
      ["206:82:0"] = { 205, 82, 0 },
      ["231:231:231"] = { 230, 230, 230 },
      ["255:165:90"] = { 255, 164, 90 },
    },
    box3 = {
      ["80:88:88"] = { 82, 90, 90 },
      ["208:72:56"] = { 213, 74, 57 },
      ["240:104:72"] = { 246, 106, 74 },
      ["248:182:165"] = { 255, 180, 164 },
    },
    box4 = {
      ["80:88:88"] = { 41, 41, 57 },
      ["240:160:136"] = { 246, 164, 139 },
      ["240:200:80"] = { 246, 205, 82 },
      ["248:227:165"] = { 255, 230, 164 },
      ["224:120:120"] = { 230, 123, 123 },
    },
    box5 = {
      ["74:66:66"] = { 41, 41, 57 },
      ["198:123:0"] = { 197, 123, 0 },
      ["255:239:99"] = { 255, 238, 98 },
      ["255:206:0"] = { 255, 205, 0 },
      ["255:248:176"] = { 255, 255, 180 },
      ["231:156:16"] = { 230, 156, 16 },
    },
    box6 = {
      ["40:48:40"] = { 41, 41, 57 },
      ["208:224:184"] = { 213, 230, 189 },
      ["80:184:63"] = { 82, 189, 57 },
      ["144:208:120"] = { 148, 213, 123 },
    },
    box7 = {
      ["40:48:40"] = { 41, 41, 57 },
      ["88:112:200"] = { 90, 115, 205 },
      ["172:185:227"] = { 172, 189, 230 },
      ["96:64:120"] = { 98, 65, 123 },
      ["248:248:248"] = { 255, 255, 255 },
      ["160:72:96"] = { 164, 74, 98 },
      ["192:192:208"] = { 197, 197, 213 },
      ["232:80:80"] = { 238, 82, 82 },
    },
    box8 = {
      ["64:48:120"] = { 65, 49, 123 },
      ["40:48:56"] = { 41, 41, 57 },
      ["40:32:80"] = { 41, 32, 82 },
      ["80:64:136"] = { 82, 65, 139 },
      ["163:150:205"] = { 164, 148, 205 },
      ["160:104:240"] = { 164, 106, 246 },
      ["200:64:168"] = { 205, 65, 172 },
      ["96:72:168"] = { 98, 74, 172 },
      ["112:64:144"] = { 115, 65, 148 },
    },
    box9 = {
      ["224:64:144"] = { 230, 65, 148 },
      ["64:64:64"] = { 41, 41, 57 },
      ["200:40:120"] = { 205, 41, 123 },
      ["152:192:152"] = { 156, 197, 156 },
      ["160:104:32"] = { 164, 106, 32 },
      ["248:152:8"] = { 255, 156, 8 },
      ["80:120:80"] = { 82, 123, 82 },
      ["72:88:72"] = { 74, 90, 74 },
      ["152:32:96"] = { 156, 32, 98 },
    },
    box10 = {
      ["231:222:173"] = { 230, 222, 172 },
      ["140:66:16"] = { 139, 65, 16 },
      ["99:41:0"] = { 98, 41, 0 },
      ["198:189:140"] = { 197, 189, 139 },
      ["115:66:8"] = { 115, 65, 8 },
    },
  }

  local function fireRedColor(name, r, g, b)
    local entry = frPatch[name] and frPatch[name][r .. ":" .. g .. ":" .. b]
    if entry then return entry[1], entry[2], entry[3] end
    return r, g, b
  end

  local function list(branch)
    local found = {}
    local ok, items = pcall(love.filesystem.getDirectoryItems, root .. branch)
    if not ok or type(items) ~= "table" then return found end
    for _, filename in ipairs(items) do
      local number = filename:match("^box(%d+)%.png$")
      if number and not (branch == "hybrid" and tonumber(number) == 6) then
        found[#found + 1] = { name = "box" .. number, number = tonumber(number) }
      end
    end
    table.sort(found, function(a, b) return a.number < b.number end)
    return found
  end

  for _, branch in ipairs({ "og", "hybrid", "fr" }) do
    names[branch] = list(branch)
    for i, item in ipairs(names[branch]) do
      choices[#choices + 1] = { branch:upper() .. " " .. i,
        branch .. ":" .. item.name }
    end
  end

  local function source(branch, name)
    local key = branch .. "/" .. name
    if sourceCache[key] then return sourceCache[key] end
    local path = root .. key .. ".png"
    local ok, data = pcall(love.image.newImageData, path)
    if not ok or not data then
      mod.log:warn("BetterFrames could not load %s: %s", path, tostring(data))
      return nil
    end
    sourceCache[key] = data
    return data
  end

  local function rgb(data, x, y)
    local r, g, b = data:getPixel(x, y)
    return math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5),
      math.floor(b * 255 + 0.5)
  end

  local function isKey(data, x, y, name)
    local r, g, b = rgb(data, x, y)
    if name == "boxnormal" or name == "boxsign" then
      return r == 112 and g == 200 and b == 160
    end
    return r == 181 and g == 230 and b == 29
  end

  local function mix(a, b, weight)
    return math.floor(a * (1 - weight) + b * weight + 0.5)
  end

  -- The four menu colors are control points, not a four-color limit.  Every
  -- distinct shade in Hybrid receives a corresponding color between them.
  local function themeShade(palette, gray)
    local position = math.max(0, math.min(3, gray * 3 / 255))
    local segment = math.min(2, math.floor(position))
    local weight = position - segment
    local dark, light = palette[4 - segment], palette[3 - segment]
    return mix(dark[1], light[1], weight),
      mix(dark[2], light[2], weight),
      mix(dark[3], light[3], weight)
  end

  local function paletteKey(palette)
    local parts = {}
    for i = 1, 4 do
      local color = palette[i]
      parts[i] = table.concat(color, ",")
    end
    return table.concat(parts, ";")
  end

  local function prepare(branch, name, palette)
    local key = branch .. "/" .. name
      .. (branch == "hybrid" and ("/" .. paletteKey(palette)) or "")
    if imageCache[key] then return imageCache[key] end
    local src = source(branch, name)
    if not src then return nil end
    local fr = branch ~= "og" and source("fr", name) or nil
    local width, height = src:getDimensions()
    if fr and (fr:getWidth() ~= width or fr:getHeight() ~= height) then
      mod.log:warn("BetterFrames dimensions differ for %s", name)
      return nil
    end
    local data = love.image.newImageData(width, height)
    local shades, counts = {}, {}
    if branch == "hybrid" and fr and name ~= "box1" then
      for y = 0, height - 1 do
        for x = 0, width - 1 do
          if not isKey(fr, x, y, name) then
            local r, g, b = rgb(fr, x, y)
            local id = r .. ":" .. g .. ":" .. b
            local gray = select(1, rgb(src, x, y))
            shades[id] = (shades[id] or 0) + gray
            counts[id] = (counts[id] or 0) + 1
          end
        end
      end
    end
    for y = 0, height - 1 do
      for x = 0, width - 1 do
        local keyed = fr and isKey(fr, x, y, name)
        if branch == "og" then
          local _, _, _, alpha = src:getPixel(x, y)
          keyed = alpha == 0
        end
        if keyed then
          data:setPixel(x, y, 0, 0, 0, 0)
        else
          local r, g, b = rgb(src, x, y)
          if branch == "og" then
            local shade = math.floor((r + 42) / 85) * 85
            r, g, b = shade, shade, shade
          elseif branch == "fr" then
            r, g, b = fireRedColor(name, r, g, b)
          elseif branch == "hybrid" and fr then
            local sr, sg, sb = rgb(fr, x, y)
            if name == "box1" then
              if sr == 206 and sg == 82 and sb == 0 then
                r, g, b = palette[3][1], palette[3][2], palette[3][3]
              elseif sr == 255 and sg == 165 and sb == 90 then
                for channel = 1, 3 do
                  local value = mix(palette[2][channel], palette[1][channel], 0.5)
                  if channel == 1 then r = value
                  elseif channel == 2 then g = value else b = value end
                end
              else
                r, g, b = fireRedColor(name, sr, sg, sb)
              end
            elseif name == "box7" and (
                (sr == 232 and sg == 80 and sb == 80)
                or (sr == 160 and sg == 72 and sb == 96)
                or (sr == 96 and sg == 64 and sb == 120)
                or (sr == 248 and sg == 248 and sb == 248)
                or (sr == 192 and sg == 192 and sb == 208)) then
              r, g, b = fireRedColor(name, sr, sg, sb)
            else
              local id = sr .. ":" .. sg .. ":" .. sb
              r, g, b = themeShade(palette, shades[id] / counts[id])
            end
          end
          data:setPixel(x, y, r / 255, g / 255, b / 255, 1)
        end
      end
    end
    local image = love.graphics.newImage(data)
    image:setFilter("nearest", "nearest")
    local quads = {}
    for i = 0, width / 8 - 1 do
      quads[i] = love.graphics.newQuad(i * 8, 0, 8, 8, width, height)
    end
    local prepared = { image = image, data = data, width = width, height = height,
      quads = quads, cells = {}, opaqueRuns = {} }
    imageCache[key] = prepared
    return prepared
  end

  local function markOpaqueTile(art, index, x, y, coverEarlier, clipW, clipH)
    -- Transparent frame pixels expose the earlier screen. Marking a whole
    -- tile would replay those exposed pixels without their palette.
    local runs = art.opaqueRuns[index]
    if not runs then
      runs = {}
      local sourceX = (index % (art.width / 8)) * 8
      local sourceY = math.floor(index / (art.width / 8)) * 8
      for py = 0, 7 do
        local px = 0
        while px < 8 do
          local _, _, _, alpha = art.data:getPixel(sourceX + px, sourceY + py)
          if alpha == 0 then
            px = px + 1
          else
            local first = px
            repeat
              px = px + 1
              if px == 8 then break end
              _, _, _, alpha = art.data:getPixel(sourceX + px, sourceY + py)
            until alpha == 0
            local last = runs[#runs]
            if last and last.x == first and last.w == px - first
                and last.y + last.h == py then
              last.h = last.h + 1
            else
              runs[#runs + 1] = { x = first, y = py,
                w = px - first, h = 1 }
            end
          end
        end
      end
      art.opaqueRuns[index] = runs
    end
    for _, run in ipairs(runs) do
      local rx, ry = x + run.x, y + run.y
      local width = math.min(run.w, (clipW or 8) - run.x)
      local height = math.min(run.h, (clipH or 8) - run.y)
      if width > 0 and height > 0 then
        if coverEarlier then marks.cover(rx, ry, width, height) end
        marks.add(rx, ry, width, height)
      end
    end
  end

  local function tile(art, column, row, x, y, markBorder)
    local key = row * (art.width / 8) + column
    local quad = art.cells[key]
    if not quad then
      quad = love.graphics.newQuad(column * 8, row * 8, 8, 8,
        art.width, art.height)
      art.cells[key] = quad
    end
    love.graphics.draw(art.image, quad, x, y)
    if markBorder then markOpaqueTile(art, key, x, y) end
  end

  local function panelAxis(size)
    local segments = { { 0, 8, 0 } }
    local last = size - 8
    for offset = 8, last - 1, 8 do
      segments[#segments + 1] = { offset, math.min(8, last - offset), 1 }
    end
    segments[#segments + 1] = { last, 8, 2 }
    return segments
  end

  local function panelTile(art, column, row, x, y, width, height, markBorder)
    if width == 8 and height == 8 then
      tile(art, column, row, x, y, markBorder)
      return
    end
    local index = row * (art.width / 8) + column
    local key = index .. ":" .. width .. ":" .. height
    local quad = art.cells[key]
    if not quad then
      quad = love.graphics.newQuad(column * 8, row * 8, width, height,
        art.width, art.height)
      art.cells[key] = quad
    end
    love.graphics.draw(art.image, quad, x, y)
    if markBorder then
      markOpaqueTile(art, index, x, y, nil, width, height)
    end
  end

  local function stripTile(art, index, x, y, markBorder, coverEarlier)
    love.graphics.draw(art.image, art.quads[index], x, y)
    if markBorder then markOpaqueTile(art, index, x, y, coverEarlier) end
  end

  local function drawNumbered(art, x, y, tw, th, section, markBorder)
    for row = 0, th - 1 do
      local sourceRow = row == 0 and 0 or row == th - 1 and 2 or 1
      if section == "head" then sourceRow = row == 0 and 0 or 1 end
      if section == "lower" then sourceRow = row == th - 1 and 2 or 1 end
      for col = 0, tw - 1 do
        local sourceCol = col == 0 and 0 or col == tw - 1 and 2 or 1
        local edge = col == 0 or col == tw - 1
          or (row == 0 and section ~= "lower")
          or (row == th - 1 and section ~= "head")
        tile(art, sourceCol, sourceRow, x + col * 8, y + row * 8,
          markBorder and edge)
      end
    end
  end

  local function drawStrip(art, name, x, y, tw, th, markBorder)
    if name == "boxnormal" then
      for col = 0, tw - 1 do
        stripTile(art, col == 0 and 1 or col == tw - 1 and 3 or 2,
          x + col * 8, y, markBorder)
        stripTile(art, col == 0 and 15 or col == tw - 1 and 17 or 16,
          x + col * 8, y + (th - 1) * 8, markBorder)
      end
      for row = 1, th - 2 do
        stripTile(art, 5, x - 8, y + row * 8, markBorder, true)
        stripTile(art, 9, x + tw * 8, y + row * 8, markBorder, true)
        for col = 0, tw - 1 do
          stripTile(art, col == 0 and 6 or col == tw - 1 and 8 or 7,
            x + col * 8, y + row * 8,
            markBorder and (col == 0 or col == tw - 1))
        end
      end
    else
      for row = 0, th - 1 do
        local base = row == 0 and 0 or row == th - 1 and 14 or 5
        for col = 0, tw - 1 do
          local index = col == 0 and base or col == 1 and base + 1
            or col == tw - 2 and base + 3 or col == tw - 1 and base + 4
            or base + 2
          local side = name == "boxsign" and (col < 2 or col >= tw - 2)
            or (col == 0 or col == tw - 1)
          stripTile(art, index, x + col * 8, y + row * 8,
            markBorder and (row == 0 or row == th - 1 or side))
        end
      end
    end
  end

  local api = { names = names, choices = choices }

  function api.current()
    local value = mod.options and mod.options:get("better_frames") or "og:default"
    if value == "og:default" or value == "og:preview" then
      return "og", "default"
    end
    local branch, name
    if type(value) == "string" then
      branch, name = value:match("^(%a+):(box%d+)$")
    end
    if branch and names[branch] then
      for _, item in ipairs(names[branch]) do
        if item.name == name then return branch, name end
      end
    end
    return "og", "default"
  end

  function api.active()
    return true
  end

  function api.entries(branch)
    local result = {}
    if branch == "og" then
      result[1] = { label = "DEFAULT", value = "og:default" }
    end
    for i, item in ipairs(names[branch] or {}) do
      result[#result + 1] = { label = tostring(i),
        value = branch .. ":" .. item.name }
    end
    return result
  end

  -- BetterOptions panes use pixel geometry rather than an 8-pixel tile grid.
  -- Keep the corners at the existing pane bounds and crop the final edge tile.
  function api.drawPanel(x, y, width, height)
    local branch, name = api.current()
    if name == "default" or width < 16 or height < 16 then return false end
    local art = prepare(branch, name, menuPalette())
    if not art or art.width ~= 24 or art.height ~= 24 then return false end
    local columns, rows = panelAxis(width), panelAxis(height)
    marks.cover(x, y, width, height)
    love.graphics.push("all")
    love.graphics.setColor(1, 1, 1, 1)
    for _, row in ipairs(rows) do
      for _, column in ipairs(columns) do
        local edge = row[3] ~= 1 or column[3] ~= 1
        panelTile(art, column[3], row[3], x + column[1], y + row[1],
          column[2], row[2], branch ~= "og" and edge)
      end
    end
    love.graphics.pop()
    return true
  end

  function api.drawBox(tx, ty, tw, th, fill, explicitRole, section)
    local branch, name = api.current()
    if tw < 3 or th < 3 or type(fill) == "table" then
      drawingStockBox = true
      stockDrawBox(tx, ty, tw, th, fill)
      drawingStockBox = false
      return false
    end
    if name == "default" then
      local x, y = tx * 8, ty * 8
      marks.cover(x, y, tw * 8, th * 8)
      drawingStockBox = true
      stockDrawBox(tx, ty, tw, th, fill)
      drawingStockBox = false
      rememberFrame(x, y, tw * 8, th * 8, section)
      return true
    end
    local kind = explicitRole or (role and role.tx == tx and role.ty == ty
      and role.tw == tw and role.th == th and role.kind)
    local artName = kind == "normal" and "boxnormal"
      or kind == "sign" and "boxsign" or name
    local palette = menuPalette()
    local art = prepare(branch, artName, palette)
    if not art then
      drawingStockBox = true
      stockDrawBox(tx, ty, tw, th, fill)
      drawingStockBox = false
      return false
    end
    local x, y = tx * 8, ty * 8
    -- A foreground box hides earlier borders. Their true-color redraws
    -- must not replay the foreground text or paper without its palette.
    marks.cover(x, y, tw * 8, th * 8)
    love.graphics.push("all")
    love.graphics.setColor(1, 1, 1, 1)
    if art.width == 24 then
      drawNumbered(art, x, y, tw, th, section, branch ~= "og")
    else
      drawStrip(art, artName, x, y, tw, th, branch ~= "og")
    end
    love.graphics.pop()
    rememberFrame(x, y, tw * 8, th * 8, section,
      artName == "boxsign" and 16 or 8)
    return true
  end

  function api.drawJoined(x, y, height, section)
    local branch, name = api.current()
    if name == "default" then return false end
    local palette = menuPalette()
    local art = prepare(branch, name, palette)
    if not art then return false end
    love.graphics.push("all")
    love.graphics.setColor(1, 1, 1, 1)
    drawNumbered(art, x, y, 16, height / 8, section, branch ~= "og")
    love.graphics.pop()
    rememberFrame(x, y, 128, height, section)
    return true
  end

  Font.drawBox = function(tx, ty, tw, th, fill)
    return api.drawBox(tx, ty, tw, th, fill)
  end
  local stockDraw = Font.draw
  local stockDrawCode = Font.drawCode
  Font.draw = function(value, x, y)
    if not api.active() then return stockDraw(value, x, y) end
    x, y = paddedPosition(x, y, Font.width(value))
    drawingText = true
    local result = stockDraw(value, x, y)
    drawingText = false
    return result
  end
  Font.drawCode = function(code, x, y)
    if not drawingText and not drawingStockBox and api.active() then
      x, y = paddedPosition(x, y, Font.advanceOf(code))
    end
    return stockDrawCode(code, x, y)
  end
  local stockArrowPos = TextBox.arrowPos
  TextBox.arrowPos = function(self)
    local x, y = stockArrowPos(self)
    if api.active() and not self:isGold() then return x - 2, y end
    return x, y
  end
  local stockTextBoxDraw = TextBox.draw
  TextBox.draw = function(self, ...)
    local previous = role
    role = { kind = "normal", tx = self.boxTx, ty = self.boxTy,
      tw = self.boxTw, th = self.boxTh }
    local result = stockTextBoxDraw(self, ...)
    role = previous
    return result
  end
  return api
end
