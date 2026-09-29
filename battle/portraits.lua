-- Internal BetterBattle module. Trainer portraits, party rows, and private image/quad caches.
-- Loaded once by better_battle_hud.lua; not a public consumer API.
return function(deps)
  local M = {}
  local Layout = assert(deps.layout)
  local Policy = assert(deps.policy)
  local Assets = require("src.render.Assets")
  local BattleState = require("src.battle.BattleState")
  local Font = require("src.render.Font")
  local PaletteFX = require("src.render.PaletteFX")
  local Sprites = require("src.pokemon.Sprites")
  local compatibility = deps.compatibility
  local crystalExports = deps.compatibility.crystalExports or {}
  local crystalSprites = deps.compatibility.crystalSprites
  local menuColors = deps.menuColors

  local CRYSTAL_OPPONENT_CROPS = {
    agatha = { 14, 7, 32, 28, false },
    beauty = { 12, 7, 32, 28, false },
    biker = { 10, 0, 32, 28, false },
    birdkeeper = { 12, 0, 32, 28, false },
    blackbelt = { 12, 0, 32, 28, false },
    blaine = { 14, 1, 32, 28, false },
    brock = { 12, 0, 32, 28, false },
    bruno = { 12, 1, 32, 28, false },
    bugcatcher = { 14, 10, 32, 28, false },
    burglar = { 12, 9, 32, 28, false },
    channeler = { 12, 2, 32, 28, false },
    cooltrainerf = { 14, 2, 32, 28, false },
    cooltrainerm = { 15, 0, 32, 28, false },
    cueball = { 12, 4, 32, 28, false },
    engineer = { 10, 5, 32, 28, false },
    erika = { 16, 5, 32, 28, false },
    fisher = { 12, 1, 32, 28, false },
    gambler = { 13, 7, 32, 28, false },
    gentleman = { 13, 0, 32, 28, false },
    giovanni = { 11, 0, 32, 28, false },
    hiker = { 12, 1, 32, 28, false },
    jessie_james = { 12, 0, 32, 28, false },
    ["jr.trainerf"] = { 12, 2, 32, 28, false },
    ["jr.trainerm"] = { 12, 3, 32, 28, false },
    juggler = { 14, 0, 32, 28, false },
    koga = { 13, 6, 32, 28, false },
    lance = { 13, 0, 32, 28, false },
    lass = { 13, 0, 32, 28, false },
    lorelei = { 12, 5, 32, 28, false },
    ["lt.surge"] = { 16, 5, 32, 28, false },
    misty = { 12, 0, 32, 28, false },
    pokemaniac = { 12, 0, 32, 28, false },
    ["prof.oak"] = { 12, 0, 32, 28, false },
    psychic = { 18, 0, 32, 28, false },
    rival1 = { 14, 0, 32, 28, false },
    rival2 = { 14, 2, 32, 28, false },
    rival3 = { 11, 2, 32, 28, false },
    rocker = { 14, 1, 32, 28, false },
    rocket = { 14, 0, 32, 28, false },
    sabrina = { 19, 0, 32, 28, false },
    sailor = { 16, 0, 32, 28, false },
    scientist = { 14, 0, 32, 28, false },
    supernerd = { 14, 10, 32, 28, false },
    swimmer = { 14, 4, 32, 28, false },
    tamer = { 10, 0, 32, 28, false },
    youngster = { 10, 3, 32, 28, false },
  }

  local CRYSTAL_PLAYER_CROPS = {
    blue_flip = { 14, 2, 32, 28, true },
    gold_flip = { 12, 0, 32, 28, true },
    james = { 12, 0, 32, 28, false },
    jessie = { 12, 0, 32, 28, false },
    kris_flip = { 14, 0, 32, 28, true },
    leaf = { 12, 0, 32, 28, true },
    leaf_flip = { 12, 0, 32, 28, true },
    red = { 14, 1, 32, 28, false },
    silver_flip = { 10, 0, 32, 28, true },
  }

  local headImages = {}

  local headQuads = setmetatable({}, { __mode = "k" })

  local function normalizedPath(path) return tostring(path or ""):gsub("\\", "/"):lower() end

  local function basename(path) return normalizedPath(path):match("([^/]+)%.png$") end

  local function isCrystalPath(path)
    local id = normalizedPath(compatibility.crystalModId)
    local value = normalizedPath(path)
    local marker = id ~= "" and (id .. "/assets/") or nil
    return marker ~= nil and value:find(marker, 1, true) ~= nil
  end

  local function loadHeadImage(path)
    if type(path) ~= "string" or path == "" or not Assets.exists(path) then return nil end
    if headImages[path] ~= nil then return headImages[path] or nil end
    local ok, image = pcall(love.graphics.newImage, path)
    if not ok or not image then
      headImages[path] = false
      return nil
    end
    image:setFilter("nearest", "nearest")
    headImages[path] = image
    return image
  end

  local function playerHead(battle)
    local path = Sprites.playerPath(battle.data, "front", {
      kind = "battle",
      battle = battle,
    })
    if not isCrystalPath(path) then return nil end
    local crop = CRYSTAL_PLAYER_CROPS[basename(path)] or CRYSTAL_OPPONENT_CROPS[basename(path)]
    if not crop then return nil end
    return loadHeadImage(path), crop, true
  end

  local function opponentHead(battle)
    local image = battle and battle.trainerPic
    if
      not image
      or type(crystalExports.isCrystalImage) ~= "function"
      or not crystalExports.isCrystalImage(image)
    then
      return nil
    end
    local path
    if type(image.getFilename) == "function" then
      local ok, value = pcall(image.getFilename, image)
      if ok then path = value end
    end
    -- Never infer a link opponent's portrait from the local player's choice.
    if battle.kind == "link" then
      local crop = path
        and (CRYSTAL_PLAYER_CROPS[basename(path)] or CRYSTAL_OPPONENT_CROPS[basename(path)])
      return crop and image or nil, crop, true
    end
    local source =
      BattleState.trainerPicPath(battle.data, battle.trainer, battle.oppClass, battle.partyIndex)
    local name = type(crystalExports.trainerPicName) == "function"
        and crystalExports.trainerPicName(source)
      or basename(source)
    local crop = CRYSTAL_OPPONENT_CROPS[basename(path)] or CRYSTAL_OPPONENT_CROPS[name]
    return crop and image or nil, crop, true
  end

  local function drawHeadImage(image, crop, x, y, trueColor)
    if not (image and crop) then return end
    local key = table.concat({
      crop[1],
      crop[2],
      crop[3],
      crop[4],
      tostring(crop[5]),
    }, ":")
    local cached = headQuads[image]
    if not cached or cached.key ~= key then
      local ok, quad = pcall(
        love.graphics.newQuad,
        crop[1],
        crop[2],
        crop[3],
        crop[4],
        image:getWidth(),
        image:getHeight()
      )
      if not ok or not quad then return end
      cached = { key = key, quad = quad }
      headQuads[image] = cached
    end
    local sx, sy, sw, sh = love.graphics.getScissor()
    love.graphics.intersectScissor(x, y, 32, 24)
    local colors = PaletteFX.effectiveColors(menuColors()) or menuColors()
    local paper = colors and colors[1] or { 255, 255, 255 }
    love.graphics.setColor(paper[1] / 255, paper[2] / 255, paper[3] / 255, 1)
    love.graphics.rectangle("fill", x, y, 32, 24)
    love.graphics.setColor(1, 1, 1, 1)
    if crop[5] then
      love.graphics.draw(image, cached.quad, x + 32, y, 0, -1, 1)
    else
      love.graphics.draw(image, cached.quad, x, y)
    end
    if sx then
      love.graphics.setScissor(sx, sy, sw, sh)
    else
      love.graphics.setScissor()
    end
    if trueColor then PaletteFX.markTrueColor(x, y, 32, 24) end
  end

  -- Use Crystal's supplied 8x8 party-ball art when available. The row still
  -- follows the stock six-slot draw behavior and caller-provided spacing.
  -- Without Crystal, call the engine's native drawBallRow unchanged.
  local function drawPartyRow(battle, party, x, y, dx, nativeRow)
    if crystalSprites and type(crystalSprites.partyBall) == "function" then
      local images = {}
      for i = 1, 6 do
        local ok, image, trueColor = pcall(crystalSprites.partyBall, party and party[i])
        if not ok or not image then
          images = nil
          break
        end
        images[i] = {
          image = image,
          trueColor = trueColor == true,
        }
      end

      if images then
        local colors = PaletteFX.effectiveColors(menuColors())
        local paper = colors and colors[1] or { 255, 255, 255 }
        love.graphics.setColor(1, 1, 1, 1)
        for i = 1, 6 do
          local item = images[i]
          local px = x + (i - 1) * dx
          love.graphics.setColor(paper[1] / 255, paper[2] / 255, paper[3] / 255, 1)
          love.graphics.rectangle("fill", px - 1, y - 1, 10, 10)
          love.graphics.setColor(1, 1, 1, 1)
          love.graphics.draw(item.image, px, y)
          if item.trueColor then PaletteFX.markTrueColor(px, y, 8, 8) end
        end
        return
      end
    end

    local row = nativeRow or battle.drawBallRow
    if type(row) == "function" then row(battle, party, x, y, dx) end
  end

  function M.renderHeadPanels(battle, nativeRow)
    if not Policy.headPanelsVisible(battle) then return false, false end
    love.graphics.setColor(0, 0, 0, 1)
    Font.drawBox(0, 0, 16, 5)
    love.graphics.push("all")
    love.graphics.intersectScissor(8, 8, 112, 24)
    local playerImage, playerCrop, playerTrueColor = playerHead(battle)
    drawHeadImage(playerImage, playerCrop, 8 + Layout.framePadding(), 8, playerTrueColor)
    drawPartyRow(battle, battle.playerParty or battle.game.save.party, 48, 17, 9, nativeRow)
    love.graphics.pop()

    local enemyDrawn = battle.kind == "trainer" or battle.kind == "link"
    if enemyDrawn then
      love.graphics.push()
      love.graphics.translate(0, 1)
      Font.drawBox(22, 0, 16, 4)
      love.graphics.pop()
      drawPartyRow(battle, battle.enemyParty, 233, 16 - Layout.framePadding(), -9, nativeRow)
      local image, crop, trueColor = opponentHead(battle)
      drawHeadImage(image, crop, 264, 2, trueColor)
    end
    return true, enemyDrawn
  end

  return M
end
