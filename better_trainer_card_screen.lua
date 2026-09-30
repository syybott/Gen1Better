-- Joined trainer information and badges, using the imported Gen 1 frame.
return function(compatibility, menuColors, menuPaper, portraitFor, badgePalette)
  local TrainerCard = require("src.ui.TrainerCard")
  local Badges = require("src.inventory.Badges")
  local Font = require("src.render.Font")
  local PaletteFX = require("src.render.PaletteFX")
  local tiny = assert(compatibility.tinyFont)
  local Card = {}
  Card.__index = Card
  Card.isOpaque = false

  local function gray(value)
    love.graphics.setColor(value, value, value, 1)
  end

  function Card:uiSize()
    local g = love.graphics
    local w, h
    if g.getPixelDimensions then w, h = g.getPixelDimensions()
    else w, h = g.getDimensions() end
    local scale = math.max(1, math.floor(math.min(w / 160, h / 176)))
    return 160, math.max(144, math.min(176, math.floor(h / scale / 16) * 16))
  end

  local function layout(card)
    local _, height = card:uiSize()
    local panelH = height / 2
    return { width = 160, height = height, panelH = panelH,
      portrait = { x = 110, y = 24, w = 40, h = panelH - 32 },
      cellH = (panelH - 32) / 2 }
  end

  local function badgePosition(l, i)
    local col, row = (i - 1) % 4, math.floor((i - 1) / 4)
    local iconOffsetY = math.floor((l.cellH - 16) / 2) - 1
    local gridH = l.cellH + math.max(9, iconOffsetY + 16)
    local gridY = l.panelH + 23
      + math.floor((l.panelH - 28 - gridH) / 2 + 0.5)
    local nx = 17 + col * 34
    local ny = gridY + row * l.cellH
    return nx + 8, ny + iconOffsetY, nx, ny
  end

  function Card:data()
    local save = self.game.save
    local caught = 0
    for _, owned in pairs(save.pokedex and save.pokedex.owned or {}) do
      if owned then caught = caught + 1 end
    end
    local seconds = math.max(0, math.floor(tonumber(save.playTime) or 0))
    return {
      name = save.player.name or "RED",
      id = ("%05d"):format(math.floor(tonumber(save.player.id) or 0) % 65536),
      money = tostring(math.max(0, math.floor(tonumber(save.money) or 0))),
      caught = tostring(caught),
      time = ("%d:%02d"):format(math.floor(seconds / 3600), math.floor(seconds / 60) % 60),
    }
  end

  local function textRight(text, right, y, maxWidth)
    text = tiny.fit(text, maxWidth or 80)
    tiny.draw(text, right - tiny.width(text), y, 0)
  end

  -- Use the game's existing money tile, aligned to the tiny digits' baseline.
  local function moneyRight(text, right, y)
    local x = right - tiny.width(text)
    gray(0)
    Font.drawCode(0xF0, x - 8, y - 2)
    tiny.draw(text, x, y, 0)
  end

  -- Bake palette-mapped portraits at source resolution, never at card size.
  -- True-color portraits can use their original image directly.
  local function portraitImage(card, image, quad, width, height)
    if card.stock.picTrueColor then return image, quad end
    local colors = menuColors(card.game)
    local key = { tostring(image) }
    for _, color in ipairs(colors) do
      key[#key + 1] = table.concat(color, ",")
    end
    key = table.concat(key, "/")
    if card.portraitKey ~= key then
      local shader = PaletteFX.shader()
      if not shader then return nil end
      if card.portraitCanvas then card.portraitCanvas:release() end
      local canvas = love.graphics.newCanvas(width, height)
      canvas:setFilter("nearest", "nearest")
      love.graphics.push("all")
      love.graphics.setCanvas(canvas)
      love.graphics.origin()
      love.graphics.setScissor()
      love.graphics.clear(0, 0, 0, 0)
      gray(1)
      love.graphics.setShader(shader)
      PaletteFX.sendColors(shader, colors)
      love.graphics.draw(image, quad, 0, 0)
      love.graphics.pop()
      card.portraitKey, card.portraitCanvas = key, canvas
    end
    return card.portraitCanvas, nil
  end

  function Card:portraitPlacement(width, height, rect)
    local renderer = self.game.renderer
    local up = renderer and renderer.uiScale and renderer:uiScale() or 1
    local fit = math.min(rect.w / width, rect.h / height)
    local displayScale = fit * up
    if displayScale >= 1 then displayScale = math.floor(displayScale) end
    local scale = displayScale / up
    return math.floor((rect.x + (rect.w - width * scale) / 2) * up + 0.5) / up,
      math.floor((rect.y + rect.h - height * scale) * up + 0.5) / up, scale
  end

  function Card:draw()
    local l, data = layout(self), self:data()
    gray(1)
    love.graphics.rectangle("fill", 0, 0, l.width, l.height)
    -- Two original patterned borders meet at the middle with no blank gap.
    self.stock:frameBox(0, 0, 20, l.panelH / 8)
    self.stock:frameBox(0, l.panelH / 8, 20, l.panelH / 8)
    gray(170 / 255)
    love.graphics.rectangle("fill", 5, 5, 72, 10)
    tiny.draw("TRAINER CARD", 9, 8, 0)
    textRight("ID NO. " .. data.id, 151, 8)

    local labels = { "NAME", "MONEY", "POKEDEX", "TIME" }
    local values = { data.name, data.money, data.caught, data.time }
    local step = math.floor((l.panelH - 40) / 3)
    for i, label in ipairs(labels) do
      local y = 22 + (i - 1) * step
      gray(170 / 255)
      love.graphics.rectangle("fill", 10, y, 3, 5)
      love.graphics.rectangle("fill", 16, y + 7, 86, 1)
      tiny.draw(label, 16, y, 0)
      if i == 2 then moneyRight(values[i], 102, y)
      else textRight(values[i], 102, y, 54) end
    end

    -- Subtle horizontal stripes behind the portrait, colored by the menu.
    local rect = l.portrait
    gray(170 / 255)
    for y = 0, rect.h - 1, 3 do
      local dy = (y + 0.5 - rect.h / 2) / (rect.h / 2)
      local half = math.floor(rect.w / 2 * math.sqrt(math.max(0, 1 - dy * dy)))
      love.graphics.rectangle("fill", rect.x + rect.w / 2 - half, rect.y + y, half * 2, 1)
    end
    if self.stock.pic then
      local image, quad, width, height = portraitFor(self.stock)
      if image and width and height and width > 0 and height > 0 then
        local x, y, scale = self:portraitPlacement(width, height, rect)
        local replay, replayQuad = portraitImage(self, image, quad, width, height)
        if replay then
          PaletteFX.markUiSpriteRedraw(replay, replayQuad, x, y,
            { sx = scale, sy = scale, clip = { rect.x, rect.y, rect.w, rect.h } })
        else
          gray(1)
          love.graphics.draw(image, quad, x, y, 0, scale, scale)
        end
      end
    end

    tiny.draw("BADGES", 80 - tiny.width("BADGES") / 2, l.panelH + 12, 0)
    if self.stock.circle then
      gray(1)
      love.graphics.draw(self.stock.circle, 58, l.panelH + 10)
      love.graphics.draw(self.stock.circle, 94, l.panelH + 10)
    end
    gray(85 / 255)
    love.graphics.rectangle("fill", 5, l.panelH + 22, 150, 1)
    local badges = Badges.list(self.game.data)
    for i = 1, math.min(8, #badges) do
      local x, y, nx, ny = badgePosition(l, i)
      gray(170 / 255)
      love.graphics.rectangle("fill", nx, ny, 7, 9)
      tiny.draw(tostring(i), nx + 2, ny + 2, 0)
      local owned = self.game.save.inventory[Badges.itemFor(badges[i])]
      local sheet = owned and self.stock.badges or self.stock.faces
      if sheet and sheet.quads[i - 1] then
        gray(1)
        love.graphics.draw(sheet.img, sheet.quads[i - 1], x, y)
      end
    end
    gray(1)
  end

  function Card:sgbPalettes()
    local l = layout(self)
    local base = menuColors(self.game)
    local paper = menuPaper(self.game) or base
    local zones = { { colors = base, x = 0, y = 0, w = l.width, h = l.height } }
    for _, y in ipairs({ 0, l.panelH }) do
      zones[#zones + 1] = { colors = paper, x = 5, y = y + 5, w = 150, h = l.panelH - 10 }
    end
    zones[#zones + 1] = { colors = base, x = 5, y = 5, w = 72, h = 10 }
    local badges = Badges.list(self.game.data)
    for i = 1, math.min(8, #badges) do
      if self.game.save.inventory[Badges.itemFor(badges[i])] then
        local x, y = badgePosition(l, i)
        local badgeColors = badgePalette(i)
        local panelBadgeColors = {
          paper[1], badgeColors[2], badgeColors[3], badgeColors[4],
          gen1BetterMenusOwned = true,
        }
        zones[#zones + 1] = { colors = panelBadgeColors, x = x, y = y, w = 16, h = 16 }
      end
    end
    return zones
  end

  function Card:update(dt)
    if self.game.input:wasPressed("a") or self.game.input:wasPressed("b") then
      if self.portraitCanvas then self.portraitCanvas:release() end
      self.portraitCanvas, self.portraitKey = nil, nil
    end
    return self.stock:update(dt)
  end

  return { new = function(game, opts)
    return setmetatable({ game = game, stock = TrainerCard.new(game, opts),
      betterTrainerCardUI = true }, Card)
  end }
end
