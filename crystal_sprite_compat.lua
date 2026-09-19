-- Optional compatibility for Crystal Animated Sprites with Shiny Visuals.
-- Loaded only when that mod is active. The external mod is never modified.
return function(mod, handle)
  local Assets = require("src.render.Assets")
  local PaletteFX = require("src.render.PaletteFX")

  local MOD_ID = "crystal_animated_sprites_with_shiny_visuals"
  local DATA_MODULE = "mods." .. MOD_ID .. ".animation_data"
  local MAX_FRAMES = 64
  local MAX_IMAGES = 300

  local exports = handle and handle.exports or {}
  local crystalBallTile = exports.ballTile
  local crystalBallShade = exports.ballShade
  local crystalBattleMono = exports.battleMono
  local crystalMonoDisplayColors = exports.monoDisplayColors

  if not handle or handle.id ~= MOD_ID then return nil end

  local okData, animationData = pcall(require, DATA_MODULE)
  if not okData or type(animationData) ~= "table" then
    mod.log:warn("Crystal sprite compatibility unavailable: animation_data")
    return nil
  end

  local imageCache = {}
  local imageCount = 0
  local ballSheetData
  local ballImages = {}

  local function loadImage(path)
    local image = imageCache[path]
    if image then return image end

    local ok, loaded = pcall(love.graphics.newImage, path)
    if not ok or not loaded then return nil end
    loaded:setFilter("nearest", "nearest")

    if imageCount >= MAX_IMAGES then
      imageCache = {}
      imageCount = 0
    end
    imageCache[path] = loaded
    imageCount = imageCount + 1
    return loaded
  end

  local function pathInfo(path)
    if type(path) ~= "string" then return nil end
    local normalized = path:gsub("\\", "/")
    local marker = MOD_ID .. "/assets/front/"
    local at = normalized:find(marker, 1, true)
    if not at then return nil end

    local relative = normalized:sub(at + #marker)
    local variant, dex =
      relative:match("^([^/]+)/([^/]+)/%d+%.png$")
    local base = normalized:match("^(.*)/%d+%.png$")
    if not (variant and dex and base) then return nil end
    return base .. "/", variant, dex
  end

  local function partyBall(mon)
    if type(crystalBallShade) ~= "function"
        or not love.image
        or type(love.image.newImageData) ~= "function"
        or not love.graphics
        or type(love.graphics.newImage) ~= "function" then
      return nil
    end

    local mono = false
    if type(crystalBattleMono) == "function" then
      local ok, value = pcall(crystalBattleMono)
      mono = ok and value == true
    end

    local mode = tostring(PaletteFX.mode or "")
    local tile = 0
    if type(crystalBallTile) == "function" then
      local ok, value = pcall(crystalBallTile, mon)
      if ok and type(value) == "number" then tile = value end
    end
    local cacheKey = mode .. (mono and ":mono:" or ":color:") .. tile
    if ballImages[cacheKey] then
      return ballImages[cacheKey], not mono
    end

    if not ballSheetData then
      local ok, data = pcall(love.image.newImageData,
        "assets/generated/battle/balls.png")
      if not ok or not data then return nil end
      ballSheetData = data
    end

    local shades
    if mono and type(crystalMonoDisplayColors) == "function" then
      local ok, value = pcall(crystalMonoDisplayColors)
      if ok then shades = value end
    end

    local ok, image = pcall(function()
      local data = love.image.newImageData(8, 8)
      for py = 0, 7 do
        for px = 0, 7 do
          local r, g, b, a =
            ballSheetData:getPixel(tile * 8 + px, py)
          local color = crystalBallShade(
            shades, tile, px, py, r, a)
          if color then
            data:setPixel(px, py,
              color[1] / 255, color[2] / 255,
              color[3] / 255, a)
          else
            data:setPixel(px, py, r, g, b, a)
          end
        end
      end
      local result = love.graphics.newImage(data)
      if type(result.setFilter) == "function" then
        result:setFilter("nearest", "nearest")
      end
      return result
    end)

    if not ok or not image then return nil end
    ballImages[cacheKey] = image
    return image, not mono
  end

  local function caughtBall()
    return partyBall({ hp = 1 })
  end

  local function animationMode(screen)
    local options = screen and screen.game and screen.game.save
      and screen.game.save.options
    return options and options.crystalAnimations == "once"
      and "once" or "loop"
  end

  local function realSeconds(screen, dt)
    dt = tonumber(dt) or (1 / 60)
    local game = screen and screen.game
    local speed = game and type(game.logicSpeed) == "function"
      and game:logicSpeed() or 1
    if type(speed) ~= "number" or speed ~= speed or speed <= 0 then
      speed = 1
    end
    return dt / speed
  end

  local function makeState(screen, path, trueColor)
    local base, variant, dex = pathInfo(path)
    if not base then return nil end

    local frames = {}
    for index = 1, MAX_FRAMES do
      local candidate = base .. ("%03d.png"):format(index)
      if index > 1 and not Assets.exists(candidate) then break end
      frames[#frames + 1] = candidate
    end
    if #frames <= 1 then return nil end

    local source = animationData[variant]
      and animationData[variant][dex]
    if not source then
      source = animationData.normal and animationData.normal[dex]
    end

    local durations = {}
    for index = 1, #frames do
      durations[index] = tonumber(source and source[index]) or 100
    end

    return {
      base = base,
      variant = variant,
      dex = dex,
      trueColor = trueColor == true,
      frames = frames,
      durations = durations,
      frame = 1,
      elapsed = 0,
      done = false,
      mode = animationMode(screen),
    }
  end

  local compat = {}

  compat.caughtBall = caughtBall
  compat.partyBall = partyBall

  function compat.current(screen, mon, path, trueColor)
    if not (screen and mon and path) then return nil end

    local base = pathInfo(path)
    if not base then return nil end

    local states = screen.__gen1BetterMenusCrystalSprites
    if not states then
      states = setmetatable({}, { __mode = "k" })
      screen.__gen1BetterMenusCrystalSprites = states
    end

    local state = states[mon]
    if not state or state.base ~= base
        or state.trueColor ~= (trueColor == true) then
      state = makeState(screen, path, trueColor)
      states[mon] = state
    end
    if not state then return nil end

    local framePath = state.frames[state.frame]
    local image = loadImage(framePath)
    if not image then return nil end
    return image, framePath, state.trueColor
  end

  function compat.update(screen, dt)
    local states = screen and screen.__gen1BetterMenusCrystalSprites
    if not states then return end

    local mode = animationMode(screen)
    local elapsed = realSeconds(screen, dt) * 1000

    for _, state in pairs(states) do
      if state.mode ~= mode then
        state.mode = mode
        state.frame = 1
        state.elapsed = 0
        state.done = false
      end

      if not state.done then
        state.elapsed = state.elapsed + elapsed
        local guard = 0
        while state.elapsed >=
            math.max(1, state.durations[state.frame] or 100)
            and guard < 50 and not state.done do
          state.elapsed = state.elapsed
            - math.max(1, state.durations[state.frame] or 100)
          state.frame = state.frame + 1
          if state.frame > #state.frames then
            if state.mode == "once" then
              state.frame = #state.frames
              state.done = true
            else
              state.frame = 1
            end
          end
          guard = guard + 1
        end
      end
    end
  end

  return compat
end
