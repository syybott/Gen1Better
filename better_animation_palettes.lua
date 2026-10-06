-- Palette repairs for overworld animations. Keep the original animation
-- clock/sequence and apply these only while BetterAnimations + ADVANCED run.
return function(mod)
  if mod.generation and mod.generation ~= 1 then return end
  local Assets = require("src.render.Assets")
  local PaletteFX = require("src.render.PaletteFX")
  local TileRenderer = require("src.render.TileRenderer")
  local GameVersion = require("src.core.GameVersion")
  local FLOWER, GRASS = 3, 44
  local paths = {
    "assets/generated/tilesets/flower1.png",
    "assets/generated/tilesets/flower2.png",
    "assets/generated/tilesets/flower3.png",
  }
  -- The moving blossoms dip into the leaf rows differently in each pose.
  -- These masks identify the stalk/leaves; other ink belongs to the blossom.
  local leaves = {
    { "........", "........", "........", "........", "........",
      "G......G", ".GGGGGG.", "...GG..." },
    { "........", "........", "........", "........", "GGG.....",
      ".GGG....", "..GGGGG.", "...GG..." },
    { "........", "........", "........", "........", "........",
      "GG.GG.GG", ".GGGGGG.", "...GG..." },
  }
  local red, pink = { 247, 82, 49 }, { 255, 156, 197 }
  local white, green = { 222, 255, 222 }, { 44, 99, 0 }
  local cache = setmetatable({}, { __mode = "k" })
  local retired = false

  local function marker(x, y, r)
    return (x == 0 or x == 7) and (y == 0 or y == 3 or y == 7)
      and r > 0.5 and r <= 0.83
  end

  local function flowers(renderer, anim)
    local spec = anim.spec
    if not (spec and spec.kind == "frames" and #anim.tiles == 1
        and anim.tiles[1] == FLOWER and spec.images and #spec.images == 3) then
      return nil
    end
    for i, path in ipairs(paths) do
      if spec.images[i] ~= path or Assets.resolve(path) ~= path then return nil end
    end
    local ctx = renderer.gbcCtx
    if Assets.resolve(ctx.imagePath) ~= ctx.imagePath then return nil end
    local group = PaletteFX.worldGroupAt(ctx.tilesetId, ctx.mapId, GRASS)
    local colors = group and ctx.groupColors[group + 1]
    if not colors then return nil end
    local atlas = Assets.imageData(ctx.imagePath)
    local gx, gy = (GRASS % ctx.perRow) * 8, math.floor(GRASS / ctx.perRow) * 8
    local textures = {}
    for i, path in ipairs(paths) do
      local source = Assets.imageData(path)
      local w, h = source:getDimensions()
      if w ~= 8 or h ~= 8 then return nil end
      local out = love.image.newImageData(8, 8)
      for y = 0, 7 do
        local left, right = 8, -1
        for x = 0, 7 do
          local r, g, b, a = source:getPixel(x, y)
          -- A different full-color/transparent asset keeps its own artwork.
          if a < 0.99 or math.abs(r - g) > 0.01 or math.abs(r - b) > 0.01 then
            return nil
          end
          if r <= 0.83 and not marker(x, y, r)
              and leaves[i][y + 1]:sub(x + 1, x + 1) ~= "G" then
            left, right = math.min(left, x), math.max(right, x)
          end
        end
        for x = 0, 7 do
          local r = source:getPixel(x, y)
          local color
          if leaves[i][y + 1]:sub(x + 1, x + 1) == "G" and r <= 0.5 then
            color = green
          elseif x >= left and x <= right then
            color = r > 0.83 and white or r > 0.5 and pink or red
          end
          if color then
            out:setPixel(x, y, color[1] / 255, color[2] / 255, color[3] / 255, 1)
          else
            -- Cover the static flower too: transparent foreground over the
            -- flower bed's grass, rather than over the old opaque tile.
            local gr, gg, gb, ga = atlas:getPixel(gx + x, gy + y)
            out:setPixel(x, y, TileRenderer.recolorSample(gr, gg, gb, ga, colors))
          end
        end
      end
      textures[i] = love.graphics.newImage(out)
      textures[i]:setFilter("nearest", "nearest")
    end
    return textures
  end

  -- Add future repairs here. Builders receive one renderer/animation entry
  -- and return corrected textures, or nil to leave that entry alone.
  local repairs = { flowers }
  local function corrected(renderer, anim)
    local entries = cache[renderer]
    if not entries then entries = {}; cache[renderer] = entries end
    if entries[anim] == nil then
      local found
      for _, build in ipairs(repairs) do
        local ok, textures = pcall(build, renderer, anim)
        if ok and textures then found = textures; break end
      end
      entries[anim] = found or false
    end
    return entries[anim] or nil
  end

  local function enabled(renderer)
    return not retired and GameVersion.generation() == 1
      and mod.options:get("better_animations") ~= false
      and PaletteFX.usesGbcPack() and not PaletteFX.customRamp
      and not PaletteFX.darkWorld() and not renderer.curBgp
      and renderer.gbcAtlas and renderer.gbcCtx
      and renderer.gbcCtx.tilesetId == "OVERWORLD"
  end

  local function pack(...) return { n = select("#", ...), ... } end
  local undo = {}
  local function wrap(name)
    local original = TileRenderer[name]
    local replacement = function(renderer, ...)
      if not enabled(renderer) then return original(renderer, ...) end
      local changes = {}
      for _, anim in ipairs(renderer.anims or {}) do
        local textures = corrected(renderer, anim)
        if textures then
          changes[#changes + 1] = { anim = anim, original = anim.textures,
            replacement = textures }
          anim.textures = textures
        end
      end
      if #changes == 0 then return original(renderer, ...) end
      local result = pack(pcall(original, renderer, ...))
      for _, change in ipairs(changes) do
        local anim = change.anim
        if anim.textures == change.replacement then
          anim.textures = change.original
          if anim.batch then
            local step = math.floor(TileRenderer.animClock() / anim.period)
              % #anim.sequence + 1
            anim.batch:setTexture(anim.textures[anim.sequence[step]])
          end
        end
      end
      if not result[1] then error(result[2], 0) end
      return unpack(result, 2, result.n)
    end
    TileRenderer[name] = replacement
    undo[#undo + 1] = function()
      if TileRenderer[name] == replacement then TileRenderer[name] = original end
    end
  end

  local previous = TileRenderer.__gen1BetterAnimationPalettes
  if previous then previous.retire() end
  local control = {}
  function control.retire()
    retired = true
    for i = #undo, 1, -1 do undo[i]() end
    cache = setmetatable({}, { __mode = "k" })
    if TileRenderer.__gen1BetterAnimationPalettes == control then
      TileRenderer.__gen1BetterAnimationPalettes = nil
    end
  end
  TileRenderer.__gen1BetterAnimationPalettes = control
  wrap("drawAnimated")
  wrap("drawTile")
  Assets.register(function() cache = setmetatable({}, { __mode = "k" }) end)
  return control
end
