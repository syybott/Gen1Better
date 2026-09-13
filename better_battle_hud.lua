return function(mod, menuColors, useStockOgMenuPalette, battleUiMode,
    compatibility)
  local Font = require("src.render.Font")
  local Growth = require("src.pokemon.Growth")
  local HudTiles = require("src.render.HudTiles")
  local Assets = require("src.render.Assets")
  local PaletteFX = require("src.render.PaletteFX")
  local Runtime = require("src.mods.Runtime")
  local Sprites = require("src.pokemon.Sprites")
  local Strings = require("src.core.Strings")
  local BattleState = require("src.battle.BattleState")
  local WideBattle = require("src.battle.WideBattle")

  local unpack = table.unpack or unpack

  local EXP_GLINT = { 118 / 255, 190 / 255, 1, 1 }
  local EXP_GLINT_FRAMES = 14
  local EXP_BURST_FRAMES = 20
  local EXP_BURST_SPARKS = {
    { -1.00,  0.00, 1 },
    { -0.72, -0.72, 1 },
    {  0.00, -1.00, 2 },
    {  0.72, -0.72, 1 },
    {  1.00,  0.00, 1 },
    {  0.72,  0.72, 1 },
    {  0.00,  1.00, 2 },
    { -0.72,  0.72, 1 },
  }
  local xpStates = setmetatable({}, { __mode = "k" })

  local function getBattleXpState(battle)
    if not battle then return {} end
    if not xpStates[battle] then
      xpStates[battle] = {}
    end
    return xpStates[battle]
  end

  local exposedStatuses = setmetatable({}, { __mode = "k" })
  local CAUGHT_ROW = { { hp = 1 } }
  local RED_CAUGHT_BALL = {
    "..kkk..",
    ".krrrk.",
    "krrrrrk",
    "kkkwkkk",
    "kwwwwwk",
    ".kwwwk.",
    "..kkk..",
  }
  local RED_CAUGHT_COLORS = {
    k = { 0, 0, 0 },
    r = { 224, 48, 48 },
    w = { 255, 255, 255 },
  }
  local GENDER_MOD_ID = "gender_mod"
  local STAGED_GENDER_SCRATCH_X = 0
  local STAGED_GENDER_SCRATCH_Y = 87
  local STAGED_GENDER_CAPTURE_SIZE = 9
  local NATIVE_STAGED_GENDER_X_NUDGE = 1
  local stagedGenderCaptureDepth = 0
  local nativeStagedHudDepth = 0
  local nativeStagedOverlayDepth = 0
  local nativeStagedHudOwner = false
  compatibility = compatibility or {}
  local crystalSprites = compatibility.crystalSprites
  local crystalExports = compatibility.crystalExports or {}
  local tinyFont = compatibility.tinyFont or {}
  local STAGED_COMPANIONS = {
    "DRAMATIC_SHAPE",
    "BATTLE_ART_VOXEL_FORK",
    "DRAMALESS_SHAPE",
  }
  local hudGame
  local providerStates = setmetatable({}, { __mode = "k" })
  local betterBattleApi = {}

  local function battleModeValue()
    local mode
    if type(battleUiMode) == "function" then
      local ok, value = pcall(battleUiMode)
      if ok then mode = value end
    end
    if mode == nil then
      local ok, value = pcall(mod.options.get, mod.options,
        "modern_battle_ui")
      mode = ok and value or "on"
    end
    if mode == true or mode == nil then return "on" end
    if mode == false then return "off" end
    return mode
  end

  local function wideSettingsSelected(game)
    local options = game and game.save and game.save.options
    return options and options.battleLayout == "wide" or false
  end

  local function extendedSettingsSelected(game)
    local options = game and game.save and game.save.options
    return options and options.battleHud == "extended" or false
  end

  local function stagedLayout(battle)
    return battle and (rawget(battle, "dramaticShapeShot") ~= nil
      or battle.letterboxWhite == false) or false
  end

  local function knownActiveProvider(battle)
    if not stagedLayout(battle) then return nil end
    local exports = battle and battle.game and battle.game.mods
      and battle.game.mods.exports or {}
    for _, id in ipairs(STAGED_COMPANIONS) do
      if type(exports[id]) == "table" then
        return { id = id, active = true, betterBattle = false }
      end
    end
    return {
      id = "detected-3d-battle-provider",
      active = true,
      betterBattle = false,
    }
  end

  local function activeProvider(battle)
    if not battle then return nil end
    local frame = tonumber(battle.frame) or 0
    local cached = providerStates[battle]
    if cached and cached.frame == frame then return cached.claim end

    local known = knownActiveProvider(battle)
    local context = {
      game = battle.game,
      battle = battle,
      provider = known and known.id or nil,
      detected = known ~= nil,
      defaultClaim = known,
    }
    local claim = known
    if Runtime.wantsHook("bettermenus.betterbattle_provider") then
      claim = Runtime.call("bettermenus.betterbattle_provider",
        function(ctx) return ctx.defaultClaim end, context)
    end

    if claim == true then
      claim = {
        id = context.provider or "custom-battle-provider",
        active = true,
        betterBattle = true,
      }
    elseif claim == false then
      claim = known
    elseif type(claim) ~= "table" or claim.active ~= true then
      claim = nil
    else
      claim = {
        id = tostring(claim.id or context.provider
          or "custom-battle-provider"),
        active = true,
        betterBattle = claim.betterBattle == true,
      }
    end

    providerStates[battle] = { frame = frame, claim = claim }
    return claim
  end

  local function effectiveBattleMode(battle)
    local mode = battleModeValue()
    if mode ~= "on" then return mode end
    local provider = activeProvider(battle)
    if provider and not provider.betterBattle then return "mod" end
    return "on"
  end

  local function setting(battle)
    if effectiveBattleMode(battle) ~= "on" then return false end
    local game = battle and battle.game or hudGame
    return wideSettingsSelected(game)
      and extendedSettingsSelected(game)
  end

  local function inversePalette()
    local ok, value = pcall(mod.options.get, mod.options, "inverse")
    return ok and value == true
  end

  local function caughtIndicatorStyle()
    local ok, value = pcall(mod.options.get, mod.options, "pokedex_indicator")
    return ok and value or "default"
  end

  local function clearInverseArtifacts(rects)
    if not inversePalette() then return end
    local colors = PaletteFX.effectiveColors(menuColors())
    local c = colors and colors[1] or { 28, 51, 79 }
    local r, g, b, a = love.graphics.getColor()
    local shader = love.graphics.getShader()
    love.graphics.setShader()
    love.graphics.setColor(c[1] / 255, c[2] / 255, c[3] / 255, 1)
    for _, rect in ipairs(rects) do
      love.graphics.rectangle("fill", rect[1], rect[2], rect[3], rect[4])
      PaletteFX.markTrueColor(rect[1], rect[2], rect[3], rect[4])
    end
    love.graphics.setShader(shader)
    love.graphics.setColor(r, g, b, a)
  end

  local function wideLayout(battle)
    if not (battle and type(battle.wideLayout) == "function") then
      return false
    end
    local ok, wide = pcall(battle.wideLayout, battle)
    return ok and wide == true
  end

  local function stockWideExtended(battle)
    if not battle or effectiveBattleMode(battle) ~= "off"
        or not wideLayout(battle)
        or type(battle.extendedHUD) ~= "function" then
      return false
    end
    local ok, extended = pcall(battle.extendedHUD, battle)
    return ok and extended == true
  end

  local function shownHP(battler)
    local mon = battler and battler.mon
    return math.max(0, math.floor((battler and battler.shownHP)
      or (mon and mon.hp) or 0))
  end

  local function battleColorMode(battle)
    if not (battle and type(battle.colorMode) == "function") then
      return false
    end
    local ok, enabled = pcall(battle.colorMode, battle)
    return ok and enabled == true
  end

  local function fitName(value, pixels)
    local text = tostring(value or "")
    if Font.width(text) <= pixels then return text end
    while #text > 0 and Font.width(text .. ".") > pixels do
      text = text:sub(1, -2)
    end
    return text .. "."
  end

  local function statusText(battle, battler)
    local status = battler
      and (battler.shownStatus or exposedStatuses[battler])
    if not status then return nil end
    if type(battle.statusLabel) == "function" then
      local ok, label = pcall(battle.statusLabel, battle, { status = status })
      if ok and label then return tostring(label) end
    end
    return tostring(status)
  end

  local function expProgress(data, mon)
    local def = data and data.pokemon and mon and data.pokemon[mon.species]
    if not def then return 0, 1, 0, false end
    local level = math.max(1, math.floor(mon.level or 1))
    local cap = data.constants and data.constants.levelCap or 100
    if level >= cap then return 0, 0, 1, true end
    local floorExp = Growth.expForLevel(def.growthRate, level,
      data.growth_rates)
    local nextExp = Growth.expForLevel(def.growthRate, level + 1,
      data.growth_rates)
    local needed = math.max(1, nextExp - floorExp)
    local current = math.max(0, math.min(needed,
      (mon.exp or floorExp) - floorExp))
    return current, needed, current / needed, false
  end

  local function expPixelTarget(battle, maxPixels)
    local mon = battle and battle.player and battle.player.mon
    if not mon then return 0 end
    local _, _, ratio = expProgress(battle.data, mon)
    ratio = math.max(0, math.min(1, ratio or 0))
    local pixels = math.floor(maxPixels * ratio + 0.5)
    return ratio > 0 and math.max(1, pixels) or 0
  end

  local function approach(value, target)
    if value == target then return value end
    local distance = math.abs(target - value)
    local step = math.max(1, math.ceil(distance / 6))
    return value < target and math.min(target, value + step)
      or math.max(target, value - step)
  end

  local function advanceExpDisplay(battle, maxPixels)
    local state = getBattleXpState(battle)
    local mon = battle and battle.player and battle.player.mon
    local target = expPixelTarget(battle, maxPixels)
    if state.owner ~= mon or state.shown == nil then
      state.owner = mon
      state.shown = target
      state.level = mon and mon.level or 0
      state.wraps = 0
      state.stage = "steady"
      state.glint = nil
      state.burst = nil
      state.frame = battle and battle.frame or 0
      return state.shown, state
    end

    local frame = battle and battle.frame or 0
    if state.frame == frame then return state.shown, state end
    state.frame = frame

    local level = mon and mon.level or state.level
    if level > state.level then
      state.wraps = state.wraps + level - state.level
      state.stage = "finish"
    elseif level < state.level then
      state.wraps = 0
      state.stage = "steady"
      state.shown = target
    end
    state.level = level

    if state.burst ~= nil then
      state.burst = state.burst + 1
      if state.burst >= EXP_BURST_FRAMES then state.burst = nil end
    end

    if state.stage == "finish" then
      state.shown = approach(state.shown, maxPixels)
      if state.shown == maxPixels then
        state.stage = "glint"
        state.glint = 0
        state.burst = 0
      end
    elseif state.stage == "glint" then
      state.glint = state.glint + 1
      if state.glint >= EXP_GLINT_FRAMES then
        state.wraps = math.max(0, state.wraps - 1)
        state.glint = nil
        if mon and mon.level >= (battle.data.constants.levelCap or 100) then
          state.shown = maxPixels
          state.stage = "steady"
        else
          state.shown = 0
          state.stage = state.wraps > 0 and "finish" or "settle"
        end
      end
    elseif state.stage == "settle" then
      state.shown = approach(state.shown, target)
      if state.shown == target then state.stage = "steady" end
    else
      state.shown = approach(state.shown, target)
    end
    return state.shown, state
  end

  local function drawExpGlint(state, x, y, width, mark)
    if not (state and state.stage == "glint" and state.glint) then return end
    local travel = width + 4
    local left = x - 2 + math.floor(travel * state.glint
      / math.max(1, EXP_GLINT_FRAMES - 1))
    local clipX = math.max(x, left)
    local clipRight = math.min(x + width, left + 4)
    if clipRight <= clipX then return end
    love.graphics.setShader()
    love.graphics.setColor(EXP_GLINT)
    love.graphics.rectangle("fill", clipX, y, clipRight - clipX, 2)
    if mark then PaletteFX.markTrueColor(clipX, y, clipRight - clipX, 2) end
  end

  local function drawExpBurst(state, x, y, width, mark)
    if not (state and state.burst) then return end
    local age = state.burst
    local centerX = x + width
    local centerY = y + 1
    local radius = 2 + math.floor(age / 2)
    local fade = math.max(0, 1 - age / EXP_BURST_FRAMES)
    love.graphics.setShader()
    love.graphics.setColor(EXP_GLINT[1], EXP_GLINT[2], EXP_GLINT[3], fade)
    for _, spark in ipairs(EXP_BURST_SPARKS) do
      local px = math.floor(centerX + spark[1] * radius + 0.5)
      local py = math.floor(centerY + spark[2] * radius + 0.5)
      local size = spark[3]
      love.graphics.rectangle("fill", px, py, size, size)
      if mark then PaletteFX.markTrueColor(px, py, size, size) end
    end
  end

  local function shortNumber(value)
    if value < 1000 then return tostring(value) end
    if value < 1000000 then
      return tostring(math.floor(value / 1000 + 0.5)) .. "K"
    end
    return tostring(math.floor(value / 1000000 + 0.5)) .. "M"
  end

  local function isCaught(battle, battler)
    if caughtIndicatorStyle() == "off" then return false end
    if battle.kind ~= "wild" then return false end
    local owned = battle.game and battle.game.save
      and battle.game.save.pokedex and battle.game.save.pokedex.owned
    local species = battler and battler.mon and battler.mon.species
    return species ~= nil and owned and owned[species] == true or false
  end

  local function drawDefaultCaughtBall(battle, x, y)
    if crystalSprites
        and type(crystalSprites.caughtBall) == "function" then
      local ok, image, trueColor =
        pcall(crystalSprites.caughtBall, battle)
      if ok and image then
        local palette = PaletteFX.effectiveColors(menuColors())
        local background = palette and palette[1]
          or { 255, 255, 255 }

        local shader = love.graphics.getShader()
        love.graphics.setShader()
        love.graphics.setColor(
          background[1] / 255,
          background[2] / 255,
          background[3] / 255,
          1)
        love.graphics.rectangle("fill", x, y, 8, 8)
        love.graphics.setShader(shader)

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(image, x, y)
        if trueColor then
          PaletteFX.markTrueColor(x, y, 8, 8)
        end
        return true
      end
    end

    if type(battle.drawCaughtBall) == "function" then
      love.graphics.setColor(1, 1, 1, 1)
      battle:drawCaughtBall(x, y)
      return true
    end

    if type(battle.drawBallRow) == "function" then
      love.graphics.setColor(1, 1, 1, 1)
      battle:drawBallRow(CAUGHT_ROW, x, y, 8)
      return true
    end

    return false
  end

  local function drawCaughtBall(battle, x, y, exact)
    if not exact then
      x = x + 54
      y = y - 1
    end
    local g = love.graphics
    local sx, sy, sw, sh = g.getScissor()
    g.setScissor(x, y, 8, 8)
    if caughtIndicatorStyle() == "red" then
      local shader = g.getShader()
      g.setShader()
      local palette = PaletteFX.effectiveColors(menuColors())
      local background = palette and palette[1] or { 255, 255, 255 }
      g.setColor(background[1] / 255, background[2] / 255,
        background[3] / 255, 1)
      g.rectangle("fill", x, y, 8, 8)
      for py, row in ipairs(RED_CAUGHT_BALL) do
        for px = 1, #row do
          local color = RED_CAUGHT_COLORS[row:sub(px, px)]
          if color then
            local dotX, dotY = x + px, y + py - 1
            g.setColor(color[1] / 255, color[2] / 255, color[3] / 255, 1)
            g.rectangle("fill", dotX, dotY, 1, 1)
          end
        end
      end
      g.setShader(shader)
      PaletteFX.markTrueColor(x, y, 8, 8)
    else
      drawDefaultCaughtBall(battle, x, y)
    end
    if sx then g.setScissor(sx, sy, sw, sh) else g.setScissor() end
    g.setColor(1, 1, 1, 1)
  end

  local function drawNativeHP(battle, battler, tx, ty, barType, segments,
      markColor, grayFill)
    HudTiles.drawHPBar(battle.data, tx, ty, {
      hp = shownHP(battler),
      stats = battler.mon.stats,
    }, barType, grayFill == true, segments)
    if markColor ~= false then
      PaletteFX.markTrueColor(tx * 8, ty * 8, (segments + 3) * 8, 8)
    end
  end

  -- A dark-HUD companion may whiten the native bar's dark tinted fill while
  -- it flips black glyphs. Re-seat just the two interior fill rows afterward
  -- with the same GREENBAR/YELLOWBAR/REDBAR palette decision as HudTiles.
  local function drawSemanticHpFill(battle, battler, tx, ty, segments,
      pixels)
    local hp = shownHP(battler)
    local maxHp = battler.mon.stats.hp
    local shownPixels = tonumber(pixels)
    local px
    if shownPixels ~= nil then
      px = math.floor(math.max(0, shownPixels) * segments / 6)
    else
      px = maxHp > 0 and math.floor(hp * segments * 8 / maxHp) or 0
    end
    px = math.min(segments * 8, math.max(0, px))
    if hp > 0 then px = math.max(1, px) end
    if px <= 0 then return end
    local green = math.ceil(27 * segments / 6)
    local yellow = math.ceil(10 * segments / 6)
    local name = px >= green and "GREENBAR"
      or px >= yellow and "YELLOWBAR" or "REDBAR"
    local colors = PaletteFX.pal(battle.data, name)
    local c = colors and colors[3]
    local fallback = name == "GREENBAR" and { 0, 189, 0 }
      or name == "YELLOWBAR" and { 247, 165, 0 }
      or { 247, 0, 0 }
    c = c or fallback
    love.graphics.setColor(c[1] / 255, c[2] / 255, c[3] / 255, 1)
    love.graphics.rectangle("fill", tx * 8 + 16, ty * 8 + 3, px, 2)
    PaletteFX.markTrueColor(tx * 8 + 16, ty * 8 + 3, px, 2)
  end

	local xpMarkImage

	local function getXpMarkImage()
	  if xpMarkImage ~= nil then
		return xpMarkImage or nil
	  end

	  local path = mod.path .. "/assets/xp_x.png"

	  local ok, img = pcall(love.graphics.newImage, path)

	  if not ok or not img then
		xpMarkImage = false
		return nil
	  end

	  img:setFilter("nearest", "nearest")

	  xpMarkImage = img
	  return img
	end

  -- Add a real EXP row directly above the HUD's native lower rule. Keep each
  -- native font tile on the integer pixel grid, but use a compact seven-pixel
  -- advance so the three glyphs fit beside the full-size numeric readout.
  -- The progress track spans the entire rule so its unfilled portion seats
  -- into the existing black line.
  local function drawExpMark(x, y)
    for i, glyph in ipairs({ "E", "X", "P" }) do
      Font.draw(glyph, x + (i - 1) * 7, y)
    end
  end

local function drawExpProgress(battle, battler, x, y, width, barY,
  markColor, segments, barType)

  local tx = math.floor(x / 8)
  local ty = math.floor(y / 8)
  segments = math.max(1, math.floor(segments or 11))
  local maxPixels = segments * 8

  local fill, state = advanceExpDisplay(battle, maxPixels)

  local fakeMax = 48
  local fakeHp = math.floor(fakeMax * (fill / maxPixels) + 0.5)

  if fill > 0 then
    fakeHp = math.max(1, fakeHp)
  end

  HudTiles.drawHPBar(battle.data, tx, ty, {
    hp = fakeHp,
    stats = { hp = fakeMax },
  }, barType, false, segments)

  -- Replace HP green fill with EXP blue
  if fill > 0 then
    local fillShader = love.graphics.getShader()
    love.graphics.setShader()
    love.graphics.setColor(EXP_GLINT)
    love.graphics.rectangle(
      "fill",
      tx * 8 + 16,
      ty * 8 + 3,
      fill,
      2
    )
    love.graphics.setShader(fillShader)
  end

  -- Cover only the H portion of the stock HP label
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.rectangle(
    "fill",
    tx * 8 + 1,
    ty * 8 + 2,
    4,
    4
  )

  -- Draw our custom X in the exact same spot
  local xpMark = getXpMarkImage()

  if xpMark then
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.draw(
      xpMark,
      tx * 8 + 1,
      ty * 8 + 2
    )
  end

  if markColor ~= false and fill > 0 then
    PaletteFX.markTrueColor(
      tx * 8 + 16,
      ty * 8 + 3,
      fill,
      2
    )
  end

  drawExpGlint(state, tx * 8 + 16, ty * 8 + 3, maxPixels,
    markColor ~= false)
  drawExpBurst(state, tx * 8 + 16, ty * 8 + 3, maxPixels,
    markColor ~= false)
end

  local function enemyVisible(battle)
    local enemy = battle.enemy
    if not enemy or battle.showEnemyTrainer or battle.enemySendingOut
        or battle.introBalls or enemy.fainted then return false end
    if type(battle.growInScale) == "function" then
      local ok, scale = pcall(battle.growInScale, battle, enemy)
      if ok and scale then return false end
    end
    return true
  end

  local function levelUpStatBoxVisible(battle)
    local stack = battle and battle.game and battle.game.stack
    local top = stack and stack:top()
    return top and getmetatable(top) == BattleState.StatBox
      and top.gen1BetterMenusWide
  end

  local function playerVisible(battle)
    if levelUpStatBoxVisible(battle) then return false end
    return battle.player ~= nil and not battle.safari and not battle.demo
      and not battle.showPlayerBack
  end

  -- Classic colorized battles run their finished 160x144 background through
  -- a second, internal SGB zone pass before the renderer's normal frame pass.
  -- HP can enter that pass as native shade gray, but a deliberately blue EXP
  -- pixel cannot. Re-seat only its filled pixels immediately after the battle
  -- zone pass; this is still part of the original HUD draw, before pics and
  -- animations are composited.
  local function drawClassicExpFill(battle)
    if not playerVisible(battle) then return end
    local fill, state = advanceExpDisplay(battle, 80)
    if fill <= 0 and state.stage ~= "glint" then return end
    if fill > 0 then
      local fillShader = love.graphics.getShader()
      love.graphics.setShader()
      love.graphics.setColor(EXP_GLINT)
      love.graphics.rectangle("fill", 64, 90, fill, 1)
      love.graphics.setShader(fillShader)
      PaletteFX.markTrueColor(64, 90, fill, 1)
    end
    drawExpGlint(state, 64, 90, 80, true)
    drawExpBurst(state, 64, 90, 80, true)
  end

  local function drawStagedSemanticHpFills(battle)
    if enemyVisible(battle) then
      drawSemanticHpFill(battle, battle.enemy, 2, 2, 6)
    end
    if playerVisible(battle) then
      drawSemanticHpFill(battle, battle.player, 10, 8, 6)
    end
  end

  local function layoutFor(battle)
    if not battle or battle.blankForAskName
        or (battle.introSlide or 0) > 0 then return nil end
    -- Staged/3-D providers own their detached HUD texture.  They still pass
    -- through BetterMenus palette coverage even when BetterBattle is OFF or
    -- has yielded to the provider, so install the bridge independently of
    -- the BetterBattle layout gate.
    if stagedLayout(battle) then return "staged" end
    if setting(battle) and wideLayout(battle) then return "wide" end
    return nil
  end

  local function drawStatus(battle, battler, levelX, y)
    local text = statusText(battle, battler)
    if not text then return end
    love.graphics.setColor(0, 0, 0, 1)
    Font.draw(text, levelX - Font.width(text) - 4, y)
  end

  local function drawStatusAt(battle, battler, x, y)
    local text = statusText(battle, battler)
    if not text then return end
    love.graphics.setColor(0, 0, 0, 1)
    Font.draw(text, x, y)
  end

  local function drawStatusAfterLevel(battle, battler, levelValueX, y,
      rightEdge)
    local text = statusText(battle, battler)
    if not text then return end
    local x = levelValueX + Font.width(tostring(battler.mon.level)) + 4
    if rightEdge then x = math.min(x, rightEdge - Font.width(text)) end
    love.graphics.setColor(0, 0, 0, 1)
    Font.draw(text, x, y)
  end

  local function drawSmallLevelL(x, y)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", x, y + 2, 2, 5)
    love.graphics.rectangle("fill", x + 2, y + 6, 2, 1)
    return 6
  end

  local function drawLevel(battler, x, y)
    local labelWidth = drawSmallLevelL(x, y)
    love.graphics.setColor(0, 0, 0, 1)
    Font.draw(tostring(battler.mon.level), x + labelWidth, y)
  end

  local function nameX(tx, name)
    local count = #Font.split(name or "")
    return tx * 8 + (count <= 2 and 16 or count <= 4 and 8 or 0)
  end

  local function caughtBallX(name, x, maxNamePixels)
    local label = maxNamePixels and fitName(name, maxNamePixels)
      or tostring(name or "")
    return x + Font.width(label) + 2
  end

  local function drawPlayerUnderline(y)
    HudTiles.tile(0x73, 144, y - 16)
    HudTiles.tile(0x73, 144, y - 8)
    HudTiles.tile(0x77, 144, y)
    for i = 8, 17 do HudTiles.tile(0x76, i * 8, y) end
    HudTiles.tile(0x6F, 56, y)
  end

  -- The stock player HUD uses five 8px rows and spends its last row on the
  -- curve. Grow that same shape upward by one tile and leftward by two,
  -- leaving its
  -- lower and right edges fixed so it still meets Dramatic Shape's anchors.
  -- The extra row creates genuine EXP space; the extra width lets the native
  -- font keep a gap between the EXP label and current/required readout.
  local function drawStagedPlayerHud(battle, markColor, grayFill)
    local battler = battle.player
    love.graphics.setColor(0, 0, 0, 1)
    Font.draw(fitName(battler.name, 64), 80, 48)
    drawStatusAt(battle, battler, 80, 56)
    drawLevel(battler, 112, 56)
    drawNativeHP(battle, battler, 10, 8, 1, 6, markColor, grayFill)
    Font.draw(("%3d/%3d"):format(shownHP(battler), battler.mon.stats.hp),
      88, 72)
    drawPlayerUnderline(88)
    drawExpProgress(battle, battler, 64, 80, 80, 90, markColor)
  end

  local function clearStagedPlayerHud()
    local g = love.graphics
    if type(g.setBlendMode) == "function" then
      g.setBlendMode("replace", "premultiplied")
    end
    g.setColor(0, 0, 0, 0)
    g.rectangle("fill", 56, 48, 104, 48)
    if type(g.setBlendMode) == "function" then g.setBlendMode("alpha") end
  end

  -- These coordinates are the engine's original 160x144 HUD coordinates.
  -- This function is called while Dramatic Shape's native HUD texture is the
  -- active canvas, before that texture is snapped to the window edges.
  local function drawStagedHudContent(battle, alreadyCleared, markColor,
      grayFill)
    if enemyVisible(battle) then
      drawStatusAfterLevel(battle, battle.enemy, 40, 8, 88)
      drawNativeHP(battle, battle.enemy, 2, 2, nil, 6, markColor, grayFill)
      if isCaught(battle, battle.enemy) then
        local x = nameX(1, battle.enemy.name)
        drawCaughtBall(battle, caughtBallX(battle.enemy.name, x), 0)
      end
    end
    if playerVisible(battle) then
      if not alreadyCleared then clearStagedPlayerHud() end
      drawStagedPlayerHud(battle, markColor, grayFill)
    end
  end

  local inkShader
  local function shaderForInk()
    if inkShader ~= nil then return inkShader end
    if not love.graphics.newShader then return nil end
    local ok, shader = pcall(love.graphics.newShader, [[
      vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
        vec4 pixel = Texel(tex, tc);
        return vec4(color.rgb, pixel.a * color.a);
      }
    ]])
    inkShader = ok and shader or false
    return ok and shader or nil
  end

  local function genderCompatibility(game)
    local exports = (game and game.mods and game.mods.exports)
      or (Runtime and Runtime.mods and Runtime.mods.exports)
    local api = exports and exports[GENDER_MOD_ID]
    local hud = api and api.BattleHUD
    if type(hud) ~= "table" then return nil, nil end
    return api, hud
  end

  local function battlerGenderInfo(battle, battler)
    local api = genderCompatibility(battle and battle.game)
    if not (api and type(api.genderOf) == "function") then return nil, nil end
    local mon = battler and battler.mon
    if not (mon and type(mon) == "table" and mon.species) then return nil, nil end
    local okGender, gender = pcall(api.genderOf, mon)
    if not okGender then return nil, nil end
    local okSymbol, symbol = pcall(api.symbol or function(g)
      return g == "M" and "♂" or g == "F" and "♀" or "⚲"
    end, gender)
    if not okSymbol or type(symbol) ~= "string" or symbol == "" then return nil, nil end
    return gender, symbol, api
  end

  local function drawBattleGender(battle, battler, x, y)
    local gender, symbol, api = battlerGenderInfo(battle, battler)
    if not symbol then return end

    local state = api.state and api.state(gender) or (type(gender) == "table" and gender.state or gender)
    x, y = math.floor(x), math.floor(y)

    -- Genderless (e.g. Mew) follows the menu palette system naturally.
    -- Drawing it as a standard black glyph into the HUD canvas allows the
    -- palette shader pass to shade it to darkest ink (pal[4]) on menu paper (pal[1]).
    -- No trueColor exemption or background rectangle is used, eliminating any
    -- fractional scissor seams around the glyph.
    if state ~= "M" and state ~= "F" then
      love.graphics.push("all")
      love.graphics.setColor(0, 0, 0, 1)
      Font.draw(symbol, x, y)
      love.graphics.pop()
      return
    end

    local pal = PaletteFX.effectiveColors(menuColors()) or menuColors()
    local bg = pal and pal[1] and { pal[1][1] / 255, pal[1][2] / 255, pal[1][3] / 255, 1 } or { 1, 1, 1, 1 }

    local color = state == "M" and { 32 / 255, 104 / 255, 224 / 255, 1 }
      or { 248 / 255, 72 / 255, 152 / 255, 1 }
    if type(api.palette) == "function" then
      local okPalette, exported = pcall(api.palette, gender)
      if okPalette and type(exported) == "table" then color = exported end
    end

    -- For Male and Female, fill the background with a 1-pixel bleed so the
    -- subpixel scissor expansion of the trueColor pass samples the menu
    -- paper color instead of the raw unshaded canvas white.
    love.graphics.setColor(bg[1], bg[2], bg[3], 1)
    love.graphics.rectangle("fill", x - 1, y - 1, 10, 10)

    love.graphics.push("all")
    local shader = shaderForInk()
    if shader then love.graphics.setShader(shader) end
    love.graphics.setColor(color[1] or 0, color[2] or 0, color[3] or 0, color[4] or 1)
    Font.draw(symbol, x, y)
    love.graphics.pop()

    local okP, PaletteFX = pcall(require, "src.render.PaletteFX")
    if okP and PaletteFX and PaletteFX.markTrueColor then
      PaletteFX.markTrueColor(x, y, 8, 8)
    end
  end

  local function drawStockGenderBackplates(battle)
    local _, hud = genderCompatibility(battle and battle.game)
    if not (hud and type(hud.wideGenderXY) == "function") then return end

    local colors = PaletteFX.effectiveColors(menuColors()) or menuColors()
    local paper = colors and colors[1] or { 255, 255, 255 }

    local function draw(side, battler)
      if not battler or battler.shownStatus then return end
      local _, symbol = battlerGenderInfo(battle, battler)
      if not symbol then return end

      local level = battler.mon and battler.mon.level or 1
      local ok, x, y = pcall(hud.wideGenderXY, side, level)
      if not ok or type(x) ~= "number" or type(y) ~= "number" then
        return
      end

      x, y = math.floor(x), math.floor(y)
      love.graphics.setShader()
      love.graphics.setColor(
        paper[1] / 255, paper[2] / 255, paper[3] / 255, 1)
      love.graphics.rectangle("fill", x - 1, y - 1, 10, 10)
    end

    if enemyVisible(battle) then
      draw("enemy", battle.enemy)
    end
    if playerVisible(battle) then
      draw("player", battle.player)
    end
  end

-- Both framed panels use the same meter geometry.
-- Two frame tiles and two label tiles leave 13 track tiles.
-- The cap's visible pixel sits immediately after the track.
local WIDE_PANEL_TILES = 17
local WIDE_METER_SEGMENTS = WIDE_PANEL_TILES - 4
local WIDE_METER_CAP_TYPE = 0

local function drawWideHP(battle, battler, tx, ty)
  drawNativeHP(battle, battler, tx, ty,
    WIDE_METER_CAP_TYPE, WIDE_METER_SEGMENTS, false)
  drawSemanticHpFill(battle, battler, tx, ty,
    WIDE_METER_SEGMENTS)
end

local function renderWideEnemy(battle)
  if not enemyVisible(battle) then return false end
  local battler = battle.enemy
  local name = tostring(battler.name or "")
  local _, hasGender = battlerGenderInfo(battle, battler)
  love.graphics.setColor(0, 0, 0, 1)
  Font.drawBox(21, 4, WIDE_PANEL_TILES, 4)
  local nameWidth = Font.draw(name, 176, 40)
  if hasGender then
    drawBattleGender(battle, battler, 176 + nameWidth + 2, 40)
  end
  drawStatus(battle, battler, hasGender and 256 or 264, 40)
  drawLevel(battler, 264, 40)
  if isCaught(battle, battler) then
    drawCaughtBall(battle, 288, 40, true)
  end
  drawWideHP(battle, battler, 22, 6)
  return true
end

local function renderWidePlayer(battle)
  if not playerVisible(battle) then return false end
  local battler = battle.player
  local _, hasGender = battlerGenderInfo(battle, battler)
  love.graphics.setColor(0, 0, 0, 1)
  Font.drawBox(0, 4, WIDE_PANEL_TILES, 6)
  local nameWidth = Font.draw(tostring(battler.name or ""), 8, 40)
  if hasGender then
    drawBattleGender(battle, battler, 8 + nameWidth + 2, 40)
  end
  drawStatus(battle, battler, hasGender and 88 or 96, 40)
  drawLevel(battler, 96, 40)
  drawWideHP(battle, battler, 1, 6)
  local hpText = ("%3d/%3d"):format(
    shownHP(battler), battler.mon.stats.hp)
  local hpWidth = type(tinyFont.width) == "function"
    and tinyFont.width(hpText) or Font.width(hpText)
  if type(tinyFont.draw) == "function" then
    tinyFont.draw(hpText, 128 - hpWidth, 56, 0)
  else
    Font.draw(hpText, 128 - Font.width(hpText), 56)
  end
  drawExpProgress(battle, battler, 8, 64,
    WIDE_METER_SEGMENTS * 8, 74, nil,
    WIDE_METER_SEGMENTS, WIDE_METER_CAP_TYPE)
  return true
end

	local CRYSTAL_OPPONENT_CROPS = {
	  agatha={14,7,32,28,false}, beauty={12,7,32,28,false},
	  biker={10,0,32,28,false}, birdkeeper={12,0,32,28,false},
	  blackbelt={12,0,32,28,false}, blaine={14,1,32,28,false},
	  brock={12,0,32,28,false}, bruno={12,1,32,28,false},
	  bugcatcher={14,10,32,28,false}, burglar={12,9,32,28,false},
	  channeler={12,2,32,28,false}, cooltrainerf={14,2,32,28,false},
	  cooltrainerm={15,0,32,28,false}, cueball={12,4,32,28,false},
	  engineer={10,5,32,28,false}, erika={16,5,32,28,false},
	  fisher={12,1,32,28,false}, gambler={13,7,32,28,false},
	  gentleman={13,0,32,28,false}, giovanni={11,0,32,28,false},
	  hiker={12,1,32,28,false}, jessie_james={12,0,32,28,false},
	  ["jr.trainerf"]={12,2,32,28,false}, ["jr.trainerm"]={12,3,32,28,false},
	  juggler={14,0,32,28,false}, koga={13,6,32,28,false},
	  lance={13,0,32,28,false}, lass={13,0,32,28,false},
	  lorelei={12,5,32,28,false}, ["lt.surge"]={16,5,32,28,false},
	  misty={12,0,32,28,false}, pokemaniac={12,0,32,28,false},
	  ["prof.oak"]={12,0,32,28,false}, psychic={18,0,32,28,false},
	  rival1={14,0,32,28,false}, rival2={14,2,32,28,false},
	  rival3={11,2,32,28,false}, rocker={14,1,32,28,false},
	  rocket={14,0,32,28,false}, sabrina={19,0,32,28,false},
	  sailor={16,0,32,28,false}, scientist={14,0,32,28,false},
	  supernerd={14,10,32,28,false}, swimmer={14,4,32,28,false},
	  tamer={10,0,32,28,false}, youngster={10,3,32,28,false},
	}
	local CRYSTAL_PLAYER_CROPS = {
	  blue_flip={14,2,32,28,true}, gold_flip={12,0,32,28,true},
	  james={12,0,32,28,false}, jessie={12,0,32,28,false},
	  kris_flip={14,0,32,28,true}, leaf={12,0,32,28,true},
	  leaf_flip={12,0,32,28,true}, red={14,1,32,28,false},
	  silver_flip={10,0,32,28,true},
	}
	local headImages = {}
	local headQuads = setmetatable({}, { __mode = "k" })

	local function normalizedPath(path)
	  return tostring(path or ""):gsub("\\", "/"):lower()
	end

	local function basename(path)
	  return normalizedPath(path):match("([^/]+)%.png$")
	end

	local function isCrystalPath(path)
	  local id = normalizedPath(compatibility.crystalModId)
	  local value = normalizedPath(path)
	  local marker = id ~= "" and (id .. "/assets/") or nil
	  return marker ~= nil and value:find(marker, 1, true) ~= nil
	end

	local function loadHeadImage(path)
	  if type(path) ~= "string" or path == "" or not Assets.exists(path) then
	    return nil
	  end
	  if headImages[path] ~= nil then return headImages[path] or nil end
	  local ok, image = pcall(love.graphics.newImage, path)
	  if not ok or not image then headImages[path] = false; return nil end
	  image:setFilter("nearest", "nearest")
	  headImages[path] = image
	  return image
	end

  local function playerHead(battle)
    local path = Sprites.playerPath(battle.data, "front", {
      kind = "battle", battle = battle,
    })
    if not isCrystalPath(path) then return nil end
    local crop = CRYSTAL_PLAYER_CROPS[basename(path)]
      or CRYSTAL_OPPONENT_CROPS[basename(path)]
    if not crop then return nil end
    return loadHeadImage(path), crop, true
  end

  local function opponentHead(battle)
    local image = battle and battle.trainerPic
    if not image or type(crystalExports.isCrystalImage) ~= "function"
        or not crystalExports.isCrystalImage(image) then return nil end
    local path
    if type(image.getFilename) == "function" then
      local ok, value = pcall(image.getFilename, image)
      if ok then path = value end
    end
    -- Never infer a link opponent's portrait from the local player's choice.
    if battle.kind == "link" then
      local crop = path and (CRYSTAL_PLAYER_CROPS[basename(path)]
        or CRYSTAL_OPPONENT_CROPS[basename(path)])
      return crop and image or nil, crop, true
    end
    local source = BattleState.trainerPicPath(
      battle.data, battle.trainer, battle.oppClass, battle.partyIndex)
    local name = type(crystalExports.trainerPicName) == "function"
      and crystalExports.trainerPicName(source) or basename(source)
    local crop = CRYSTAL_OPPONENT_CROPS[basename(path)]
      or CRYSTAL_OPPONENT_CROPS[name]
    return crop and image or nil, crop, true
  end

	local function drawHeadImage(image, crop, x, y, trueColor)
	  if not (image and crop) then return end
    local key = table.concat({
      crop[1], crop[2], crop[3], crop[4], tostring(crop[5]),
    }, ":")
	  local cached = headQuads[image]
	  if not cached or cached.key ~= key then
	    local ok, quad = pcall(love.graphics.newQuad,
	      crop[1], crop[2], crop[3], crop[4],
	      image:getWidth(), image:getHeight())
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
	  if sx then love.graphics.setScissor(sx, sy, sw, sh)
	  else love.graphics.setScissor() end
	  if trueColor then PaletteFX.markTrueColor(x, y, 32, 24) end
	end

  -- Use Crystal's supplied 8x8 party-ball art when available. The row still
  -- follows the stock six-slot draw behavior and caller-provided spacing.
  -- Without Crystal, call the engine's native drawBallRow unchanged.
  local function drawPartyRow(battle, party, x, y, dx, nativeRow)
    if crystalSprites and type(crystalSprites.partyBall) == "function" then
      local images = {}
      for i = 1, 6 do
        local ok, image, trueColor =
          pcall(crystalSprites.partyBall, party and party[i])
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
          love.graphics.setColor(
            paper[1] / 255, paper[2] / 255, paper[3] / 255, 1)
          love.graphics.rectangle("fill", px - 1, y - 1, 10, 10)
          love.graphics.setColor(1, 1, 1, 1)
          love.graphics.draw(item.image, px, y)
          if item.trueColor then
            PaletteFX.markTrueColor(px, y, 8, 8)
          end
        end
        return
      end
    end

    local row = nativeRow or battle.drawBallRow
    if type(row) == "function" then
      row(battle, party, x, y, dx)
    end
  end

	local function headPanelsVisible(battle)
	  if not battle or battle.safari or battle.demo or battle.oakDemo
	      or battle.blankForAskName or battle.fieldCleared or battle.result
	      or battle.showPlayerBack
	      or battle.showEnemyTrainer or battle.enemySendingOut
	      or battle.growIn or battle.shrinkOut then return false end
	  if battle.introBalls then
	    return battle.player ~= nil
	  end
	  if (battle.introSlide or 0) > 0 then return false end
	  return battle.player ~= nil
	end

	local function renderHeadPanels(battle, nativeRow)
	  if not headPanelsVisible(battle) then return false, false end
	  love.graphics.setColor(0, 0, 0, 1)
	  love.graphics.push()
	  love.graphics.translate(0, 1)
	  Font.drawBox(0, 0, 16, 4)
  love.graphics.pop()
  local playerImage, playerCrop, playerTrueColor = playerHead(battle)
  drawHeadImage(playerImage, playerCrop, 8, 3, playerTrueColor)
	  drawPartyRow(
	    battle,
	    battle.playerParty or battle.game.save.party,
	    48, 16, 9, nativeRow)

	  local enemyDrawn = battle.kind == "trainer" or battle.kind == "link"
	  if enemyDrawn then
	    love.graphics.push()
	    love.graphics.translate(0, 1)
	    Font.drawBox(22, 0, 16, 4)
	    love.graphics.pop()
	    drawPartyRow(battle, battle.enemyParty, 233, 16, -9, nativeRow)
	    local image, crop, trueColor = opponentHead(battle)
	    drawHeadImage(image, crop, 264, 2, trueColor)
	  end
	  return true, enemyDrawn
	end

	  local PLAYER_MESSAGE_WIDTH = 112
	  local WIDE_MESSAGE_WIDTH = 288
	  local MESSAGE_VISIBLE_LINES = 2


	  -- Message rows are tagged at the point where battle actions enqueue them.
	  -- This keeps pane ownership stable while the queue advances through
	  -- animation/hold rows (where transient battle fields are unavailable).
	  local function routeQueuedMessages(methodName, destinationFor)
	    local original = BattleState[methodName]
	    if type(original) ~= "function" then return end
	    BattleState[methodName] = function(battle, ...)
	      local existing = {}
	      for _, queued in ipairs(battle.queue or {}) do existing[queued] = true end
      local result = original(battle, ...)
      for _, queued in ipairs(battle.queue or {}) do
	        if not existing[queued] and queued.text and not queued._betterMessagePane then
	          queued._betterMessagePane = destinationFor(battle, ...)
	        end
	      end
	      return result
	    end
	  end

	  routeQueuedMessages("executeAction", function(_, user)
	    return user and user.isPlayer and "player" or "generic"
	  end)
	  routeQueuedMessages("onFaint", function() return "generic" end)
	  routeQueuedMessages("awardExp", function() return "center" end)
	  routeQueuedMessages("learnMove", function() return "center" end)
	  routeQueuedMessages("enemyMonFainted", function(battle)
	    return battle.result == "win" and "center" or "generic"
	  end)

	  local function displayedMessagePane(battle)
	    if battle.phase ~= "messages"
	        or battle.shown ~= battle._betterMessageShown
	        or #(battle.shown or {}) == 0 then
	      return nil
	    end
	    return battle._betterMessagePane
	  end

	  -- Reflow the engine's decoded message lines before the first glyph is
	  -- revealed. Player messages use the compact pane width; centered and
	  -- generic messages use the full available width.
	  local originalStartMessage = BattleState.startMessage
	  BattleState.startMessage = function(battle, item)
	    local active = setting(battle)
	    local destination = type(item) == "table" and item._betterMessagePane
	    if not destination then
	      if battle.kind == "wild" and battle.introBalls == true then
	        destination = "wild-intro"
	      elseif battle.enemySendingOut == true then
	        destination = "generic"
	      elseif battle.sendingOut == true then
	        destination = "player"
	      else
	        destination = "generic"
	      end
	    end
    local result = originalStartMessage(battle, item)
    battle._betterMessagePane = destination
    battle._betterMessageShown = active and battle.shown or nil
    if not active or destination == "generic" then
      return result
    end

	  local maxWidth = destination == "player"
	    and PLAYER_MESSAGE_WIDTH
	    or WIDE_MESSAGE_WIDTH

    local lines, total = {}, 0
    local groups, group = {}, nil

    -- The engine has already split stock text at its original narrow
    -- textbox width. Rejoin ordinary newline-separated chunks so the
    -- widened BetterMenus message pane can wrap them again.
    -- A line marked cont=true follows \v and must remain a separate
    -- continuation/page segment.
    local function appendSourceLine(line)
      if line.cont then
        if group then groups[#groups + 1] = group end
        group = {
          text = line.text or "",
          cont = true,
        }
      elseif not group then
        group = {
          text = line.text or "",
          cont = false,
        }
      elseif group.text == "" then
        group.text = line.text or ""
      elseif line.text and line.text ~= "" then
        group.text = group.text .. " " .. line.text
      end
    end

    for _, line in ipairs(battle.lines or {}) do
      appendSourceLine(line)
    end
    if group then groups[#groups + 1] = group end

    for _, group in ipairs(groups) do
      local text = group.text
      local groupCodes = Font.encode(text)
      local spans = Font.split(text)
      local first = 1

      repeat
        local width, last, space = 0, first - 1, nil

        for i = first, #spans do
          local span = spans[i]
          local advance = Font.advanceOf(span.code or Font.encode(" ")[1])
		  if width + advance > maxWidth then break end
		  width, last = width + advance, i
		  if text:sub(span.from, span.to) == " " then space = i end
        end

        if first <= #spans then last = math.max(first, last) end
        if last < #spans and space and space > first then last = space end
		local wrappedText = last >= first and text:sub(
          spans[first].from, spans[last].to) or ""
		local wrappedCodes = {}
		for i = first, last do
		  wrappedCodes[#wrappedCodes + 1] = groupCodes[i]
		end

		local continuation = first == 1 and group.cont or false

		-- A stock \v marker should only pause after a full two-line
		-- player pane. It must not pause after the first visual line
		-- when the second line still fits in the same pane.
		if continuation and (#lines % MESSAGE_VISIBLE_LINES) ~= 0 then
		  continuation = false
		end

		lines[#lines + 1] = {
		  text = wrappedText,
		  codes = wrappedCodes,
		  cont = continuation,
		}
		total = total + #wrappedCodes
		first = last + 1
      until first > #spans
    end

    battle.lines, battle.total = lines, total
    battle.shown, battle.lineIndex = {}, 0
    battle.scrollPx = nil
    battle:beginMsgLine()
    battle._betterMessageShown = battle.shown
    return result
  end

	local function drawShownMessageLines(
	    battle, x, y, width, lineCount, lineStep, clipHeight)
	  local g = love.graphics
	  lineStep = lineStep or 16
	  clipHeight = clipHeight or lineCount * lineStep

	  g.push("all")
	  g.intersectScissor(x, y, width, clipHeight)
	  g.setColor(0, 0, 0, 1)

	  if battle.scrollPx and battle.scrollPx > 0 then
	    battle.scrollPx = math.max(0, battle.scrollPx - 2)
	    if battle.scrollPx == 0 then battle.scrollPx = nil end
	  end

	  local off = battle.scrollPx or 0
	  for lineIndex, line in ipairs(battle.shown or {}) do
	    if lineIndex <= lineCount then
	      local lineX = x
	      local lineY = y + (lineIndex - 1) * lineStep + off

	      for _, code in ipairs(line) do
	        Font.drawCode(code, lineX, lineY)
	        lineX = lineX + Font.advanceOf(code)
	      end
	    end
	  end

	  g.pop()
	end

	local function drawBetterMessageBox(battle)
	  Font.drawBox(0, 13, 38, 5)

	  drawShownMessageLines(battle, 8, 112, 288,
	    MESSAGE_VISIBLE_LINES, 16, 24)

	  if (battle.msgWaiting or battle.msgPrompt)
	      and (battle.frame or 0) % 60 < 30 then
	    love.graphics.setColor(0, 0, 0, 1)
	    Font.drawCode(0xEE, 296, 132)
	  end

	  return 0, 104, 304, 40, "bottom"
	end

	local function battleMessageWidthTiles(battle)
	  local maxWidth = 0

	  for _, line in ipairs(battle.lines or {}) do
	    local width = 0
	    for _, code in ipairs(line.codes or {}) do
	      width = width + Font.advanceOf(code)
	    end
	    maxWidth = math.max(maxWidth, width)
	  end

	  return math.max(3, math.min(38, math.ceil(maxWidth / 8) + 2))
	end

	-- Centered, content-sized pane for wild intro and post-battle messages.
	local function drawCenteredMessageBox(battle)
	  local widthTiles = battleMessageWidthTiles(battle)
	  local lineCount = math.max(
	    1,
	    math.min(MESSAGE_VISIBLE_LINES, #(battle.lines or {}))
	  )
	  local heightTiles = lineCount * 2 + 1
	  local tx = math.floor((38 - widthTiles) / 2)
	  local ty = 18 - heightTiles
	  local clipHeight = lineCount == 1 and 8 or 24

	  love.graphics.setColor(0, 0, 0, 1)
	  Font.drawBox(tx, ty, widthTiles, heightTiles)

	  drawShownMessageLines(
	    battle,
	    (tx + 1) * 8,
	    (ty + 1) * 8,
	    (widthTiles - 2) * 8,
	    lineCount,
	    16,
	    clipHeight
	  )

	  if (battle.msgWaiting or battle.msgPrompt)
	      and (battle.frame or 0) % 60 < 30 then
	    love.graphics.setColor(0, 0, 0, 1)
	    Font.drawCode(
	      0xEE,
	      (tx + widthTiles - 1) * 8,
	      (ty + heightTiles) * 8 - 12
	    )
	  end

	  return tx * 8, ty * 8, widthTiles * 8, heightTiles * 8, "bottom"
	end

	-- Player send-out and move messages use the same compact pane as
	-- "What will <PLAYER POKEMON> do?".
	local function drawPlayerMessageBox(battle)
	  local tx, ty, tw, th = 22, 8, 16, 4

	  love.graphics.setColor(0, 0, 0, 1)
	  Font.drawBox(tx, ty, tw, th)

	  drawShownMessageLines(
	    battle,
	    (tx + 1) * 8,
	    (ty + 1) * 8,
	    (tw - 2) * 8,
	    MESSAGE_VISIBLE_LINES, 8, 16
	  )

	  if (battle.msgWaiting or battle.msgPrompt)
	      and (battle.frame or 0) % 60 < 30 then
	    love.graphics.setColor(0, 0, 0, 1)
	    Font.drawCode(0xEE, 296, 88)
	  end

	  return 176, 64, 128, 32, "top"
	end

  local function wrapWords(text, maxWidth)
    local lines, line = {}, ""
    for word in tostring(text or ""):gmatch("%S+") do
      local candidate = line == "" and word or line .. " " .. word
      if line ~= "" and Font.width(candidate) > maxWidth then
        lines[#lines + 1] = line
        line = word
      else
        line = candidate
      end
    end
    if line ~= "" then lines[#lines + 1] = line end
    return lines
  end

  local function drawBetterCommandMenu(battle)
    Font.drawBox(22, 8, 16, 4)
	  love.graphics.setColor(0, 0, 0, 1)
	  if not battle.demo then
	    local who = battle.player and battle.player.name or ""
	    local prompt = Strings("What will") .. " "
	      .. tostring(who) .. Strings(" do?")
	    for i, line in ipairs(wrapWords(prompt, 112)) do
	      Font.draw(line, 184, 72 + (i - 1) * 8)
	    end
    end

	  if battle.safari then
	    love.graphics.setColor(1, 1, 1, 1)
	    love.graphics.rectangle("fill", 184, 72, 112, 16)
	    love.graphics.setColor(0, 0, 0, 1)
	    Font.draw(Strings("BALLx") .. tostring(battle.safari.balls), 184, 72)
	  end

	  love.graphics.push()
	  love.graphics.translate(0, -1)
	  Font.drawBox(22, 12, 16, 4)

	  if battle.safari then
	    Font.draw(Strings("BALL"), 192, 104)
	    Font.draw(Strings("BAIT"), 256, 104)
	    Font.draw(Strings("ROCK"), 192, 112)
	    Font.draw(Strings("RUN"), 256, 112)
	  else
	    Font.draw(Strings("FIGHT"), 192, 104)
	    Font.drawCode(0xE1, 256, 104)
	    Font.drawCode(0xE2, 264, 104)
	    Font.draw(Strings("ITEM"), 192, 112)
	    Font.draw(Strings("RUN"), 256, 112)
	  end

    local index = battle.menuIndex or 1
    if battle.demo then index = (battle.demoTimer or 0) <= 80 and 1 or 3 end
    local col, row = (index - 1) % 2, math.floor((index - 1) / 2)
	  Font.drawCode(0xED, col == 0 and 184 or 248, 104 + row * 8)
	  love.graphics.pop()
	  return 176, 64, 128, 64, "top"
  end

	local function tinyDraw(text, x, y)
	  if type(tinyFont.draw) == "function" then
	    return tinyFont.draw(text, x, y, 0)
	  end
	  love.graphics.setColor(0, 0, 0, 1)
	  Font.draw(tostring(text or ""), x, y)
	end

	local function tinyFit(text, width)
	  if type(tinyFont.fit) == "function" then return tinyFont.fit(text, width) end
	  return fitName(text, width)
	end

	local function typeAbbreviation(value)
	  if type(tinyFont.typeAbbreviation) == "function" then
	    return tinyFont.typeAbbreviation(value)
	  end
	  return tostring(value or ""):sub(1, 3):upper()
	end

  local function drawBetterMoveMenu(battle, moves, selected)
    Font.drawBox(22, 8, 16, 10)
    for i = 1, 4 do
      local move = moves and moves[i]
	    local y = 73 + (i - 1) * 12
      if move then
        local def = battle:moveDef(move) or battle.data.moves[move.id]
        local maxPP = def and ((def.pp or 0)
          + (move.ppUps or 0) * math.floor((def.pp or 0) / 5)) or 0
        tinyDraw(tinyFit(def and def.name or move.id or "", 56), 192, y)
        tinyDraw(typeAbbreviation(def and def.type), 252, y)
        tinyDraw(("%d/%d"):format(move.pp or 0, maxPP), 272, y)
      end
    end
    local cursor = math.max(1, math.min(4, selected or 1))
    love.graphics.setColor(0, 0, 0, 1)
	  Font.drawCode(0xED, 184, 72 + (cursor - 1) * 12)
	  if battle.moveSwapIndex and battle.moveSwapIndex ~= cursor then
	    Font.drawCode(0xEC, 184, 72 + (battle.moveSwapIndex - 1) * 12)
	  end
	  return 176, 64, 128, 80, "top"
  end

  -- WideBattle.navigate has no battle argument. Scope the list mapping to
  -- this battle's update only; command-menu and stock-grid input stay native.
  local inputBattle
  local originalUpdate = BattleState.update
  BattleState.update = function(battle, ...)
    local previous = inputBattle
    inputBattle = setting(battle) and battle or nil
    local ok, result = pcall(originalUpdate, battle, ...)
    inputBattle = previous
    if not ok then error(result, 0) end
    return result
  end
  local originalNavigate = WideBattle.navigate
  WideBattle.navigate = function(index, count, input)
    if inputBattle and (inputBattle.phase == "moveSelect"
        or inputBattle.phase == "mimicSelect") then
      if count < 1 then return nil end
      if input:wasPressed("up") then return (index - 2) % count + 1 end
      if input:wasPressed("down") then return index % count + 1 end
      if input:wasPressed("left") or input:wasPressed("right") then return index end
      return nil
    end
    return originalNavigate(index, count, input)
  end

	local function renderBetterBattleBottom(battle, visible)
	  if not visible then return nil end
	  if battle.phase == "menu" then return drawBetterCommandMenu(battle) end
	  if battle.phase == "messages" then
	    local destination = displayedMessagePane(battle)
	    if not destination
	        or not (battle.current or battle.animPlaying or battle.msgHold) then
	      return nil
	    end
	    if destination == "wild-intro" then
	      if not battle.current then return nil end
	      return drawCenteredMessageBox(battle)
	    elseif destination == "center" then
	      return drawCenteredMessageBox(battle)
	    elseif destination == "player" then
	      return drawPlayerMessageBox(battle)
	    end
	    return drawBetterMessageBox(battle)
	  end
	  if battle.phase == "moveSelect" then
	    return drawBetterMoveMenu(battle,
	      battle.player and battle.player.curMoves, battle.moveIndex)
	  end
	  if battle.phase == "mimicSelect" then
	    return drawBetterMoveMenu(battle, battle.mimicMoves, battle.mimicIndex)
	  end
	  return nil
	end

	local function anchorWideHud(battle, x, y, w, h, anchor, placement)
	  if not battle:extendedHUD() then return end

	  local stack = battle.game and battle.game.stack
	  if stack and stack.top and stack:top() ~= battle then return end

	  local renderer = battle.game and battle.game.renderer
	  if not (renderer and renderer.setBattleUIAnchor) then return end

	  x = x + (battle.extendedHUDOffsetX or 0)
	  y = y + (battle.extendedHUDOffsetY or 0)

	  local x2 = math.min(304, x + w)
	  local y2 = math.min(144, y + h)

	  x = math.max(0, x)
	  y = math.max(0, y)
	  w = x2 - x
	  h = y2 - y

	  if w > 0 and h > 0 then
		renderer:setBattleUIAnchor(x, y, w, h, anchor, placement)
	  end
	end

	local function battleIsTopState(battle)
	  local stack = battle and battle.game and battle.game.stack
	  return not (stack and stack.top) or stack:top() == battle
	end

  local BETTER_BATTLE_SCALE = 0.50 -- internal only; no options entry

  local function betterBattleGeometry(battle)
    local r = battle.game.renderer:frameRects()
    local step = math.max(1, math.floor(r.Up * BETTER_BATTLE_SCALE + 1e-6))
    local hudY = step / r.dpiY
    -- Leave the complete 48px player panel, including XP, below its feet.
    local playerGround = math.min(142, math.floor(
      (r.vuy + r.vuh - r.uoy - 50 * hudY) / r.Uy))
    return {
      playerGround = playerGround,
      enemyGround = playerGround - 32,
      playerShift = playerGround - 104,
      enemyShift = playerGround - 32 - 56,
    }
  end

  local function betterBattlePlacement(edge, gapX, gapY, fieldX, fieldY)
    return {
      owner = "betterbattle", scale = BETTER_BATTLE_SCALE,
      edge = edge, gapX = gapX or 0, gapY = gapY or 0,
      fieldX = fieldX, fieldY = fieldY,
    }
  end

	local function renderBetterBattleLayer(battle, bottomVisible, nativeRow)
    if not setting(battle) or not battleIsTopState(battle) then return false end
    local renderer = battle.game.renderer
    local geometry = betterBattleGeometry(battle)
    local marks = PaletteFX.trueColorRects("ui")
    local firstMark = #marks + 1
    local zones = { PaletteFX.zone(menuColors(), 0, 0, 37, 17) }
    local playerHeadDrawn, enemyHeadDrawn
    local enemyStatusDrawn, playerStatusDrawn
	  local bottomX, bottomY, bottomW, bottomH, bottomAnchor
    love.graphics.push("all")
    local ok, err = pcall(function()
	    playerHeadDrawn, enemyHeadDrawn = renderHeadPanels(battle, nativeRow)
	    enemyStatusDrawn = renderWideEnemy(battle)
	    playerStatusDrawn = renderWidePlayer(battle)
	    bottomX, bottomY, bottomW, bottomH, bottomAnchor =
	      renderBetterBattleBottom(battle, bottomVisible)
    end)
    love.graphics.pop()
    -- Semantic fills/icons mark canvas-local bounds. Move just this draw's
    -- marks into the HUD list, including on an error, never onto the field.
    for i = firstMark, #marks do
      if PaletteFX.honorsTrueColor() then zones[#zones + 1] = marks[i] end
    end
    for i = #marks, firstMark, -1 do marks[i] = nil end
    if not ok then error(err, 0) end
    renderer.gen1BetterBattleZones = zones
    renderer.battleHUDCanvas:setFilter("nearest", "nearest")

    if playerHeadDrawn then
      anchorWideHud(battle, 0, 0, 128, 32, "top",
        betterBattlePlacement("top-left", 4, -12))
    end
    if enemyHeadDrawn then
      anchorWideHud(battle, 176, 0, 128, 32, "topright",
        betterBattlePlacement("top-right", 4, -12))
    end
    if playerStatusDrawn then
	    anchorWideHud(battle, 0, 32, 136, 48, "bottom",
	      betterBattlePlacement("field", 0, 2, 52, geometry.playerGround))
    end
    if enemyStatusDrawn then
	    anchorWideHud(battle, 168, 32, 136, 32, "bottom",
	      betterBattlePlacement("field", 0, 2, 260, geometry.enemyGround))
	  end
	  	if bottomX then
	    local destination = displayedMessagePane(battle)
	    local placement
	    if destination == "wild-intro" or destination == "center" then
	      placement = betterBattlePlacement("center", 0, 0)
	    elseif bottomAnchor == "bottom" then
	      placement = betterBattlePlacement("center-bottom", 0, 0)
	    else
	      placement = betterBattlePlacement("top-left", 4, 20)
	    end
	    anchorWideHud(
	      battle, bottomX, bottomY, bottomW, bottomH,
	      bottomAnchor or "top", placement)
    end
    return true
  end

  -- Translate native pic/animation drawing, without resizing assets or
  -- changing battler coordinates/state. The existing engine methods retain
  -- send-out, recall, fainting, hit blink, capture and sprite-mod behavior.
  local function withBetterBattleField(battle, draw)
    local geometry = betterBattleGeometry(battle)
    local originalPics, originalAnim = battle.drawPicsLayer, battle.drawAnimLayer
    local ownPics, ownAnim = rawget(battle, "drawPicsLayer"),
      rawget(battle, "drawAnimLayer")
    local function shifted(dy, callback)
      local g = love.graphics
      local marks = PaletteFX.trueColorRects("ui")
      local first = #marks + 1
      local x, _, w = g.getScissor()
      g.push("all")
      -- Native WideBattle clips at FIELD_BOTTOM. The compact layout uses
      -- that formerly reserved message area for the Pokémon's lower rows.
      g.setScissor(x or 0, 0, w or 304, 144)
      g.translate(0, dy)
      local ok, result = pcall(callback)
      g.pop()
      for i = first, #marks do marks[i].y = marks[i].y + dy end
      if not ok then error(result, 0) end
      return result
    end
    battle.drawPicsLayer = function(self, slide, sx, sy, side, skipMenuClip)
      local dy = side == "player" and geometry.playerShift or geometry.enemyShift
      return shifted(dy, function()
        return originalPics(self, slide, sx, sy, side, skipMenuClip)
      end)
    end
    battle.drawAnimLayer = function(self, colorized)
      local sprites = self.lockedBall
      if self.animPlaying and self.animPlayer then
        local step = self.animPlayer.steps[self.animPlayer.stepIndex]
        sprites = step and step.sprites
      end
      local minX, maxX = math.huge, -math.huge
      for _, sprite in ipairs(sprites or {}) do
        minX, maxX = math.min(minX, sprite.x - 8), math.max(maxX, sprite.x)
      end
      local t = minX < math.huge
        and math.max(0, math.min(1, ((minX + maxX) / 2 - 40) / 80)) or 0
      local dy = math.floor(geometry.playerShift * (1 - t)
        + geometry.enemyShift * t + 0.5)
      return shifted(dy, function() return originalAnim(self, colorized) end)
    end
    local ok, result = pcall(draw)
    battle.drawPicsLayer, battle.drawAnimLayer = ownPics, ownAnim
    if not ok then error(result, 0) end
    return result
  end

  betterBattleApi.enabled = function(battle)
    return setting(battle)
  end
  betterBattleApi.modeFor = function(battle)
    return effectiveBattleMode(battle)
  end
  betterBattleApi.activeProvider = function(battle)
    return activeProvider(battle)
  end
  betterBattleApi.drawLayer = function(battle, bottomVisible)
    if bottomVisible == nil and battle
        and type(battle.bottomUIVisible) == "function" then
      local ok, visible = pcall(battle.bottomUIVisible, battle)
      bottomVisible = ok and visible == true or false
    end
    return renderBetterBattleLayer(battle, bottomVisible ~= false)
  end
  betterBattleApi.expPixels = function(battle)
    local state = getBattleXpState(battle)
    return math.max(0, math.floor(tonumber(state.shown) or 0))
  end
  mod.exports.betterBattle = betterBattleApi

	local function renderWide(battle)
	  if not battleIsTopState(battle) then return end

	  local function anchorHud(battle, x, y, w, h, anchor)
	    if not battle:extendedHUD() or not battleIsTopState(battle) then
		  return
	    end

	    local renderer = battle.game and battle.game.renderer
	    if not (renderer and renderer.setBattleUIAnchor) then
		  return
	    end

	    x = x + (battle.extendedHUDOffsetX or 0)
	    y = y + (battle.extendedHUDOffsetY or 0)

	    local x2 = math.min(304, x + w)
	    local y2 = math.min(144, y + h)

	    x = math.max(0, x)
	    y = math.max(0, y)

	    w = x2 - x
	    h = y2 - y

	    if w > 0 and h > 0 then
		  renderer:setBattleUIAnchor(x, y, w, h, anchor)
	    end
	  end

    local fx = battle.fx
    if fx and fx.flash and fx.flash > 0
        and (battle.frame or 0) % 4 < 2 then return end

    local sx = (fx and fx.shakeX) or 0
    local sy = (fx and fx.shakeY) or 0
    if sx == 0 and sy == 0 and fx and fx.shake and fx.shake > 0 then
      sx = (battle.frame or 0) % 4 < 2 and 2 or -2
    end
    love.graphics.push("all")
    if sx ~= 0 or sy ~= 0 then love.graphics.translate(sx, sy) end

	if not battle:extendedHUD() then
	  renderWideEnemy(battle, fx)
	  renderWidePlayer(battle)
	end

	love.graphics.pop()
	end
  -- Draw-time presentation shim: while the engine paints its own HUD, expose
  -- the native level instead of the mutually-exclusive status label. The
  -- matching renderer then adds that saved status just to the left. No panel
  -- pixels are cleared or replaced, preserving the frosted background.
  local function withNativeLevels(battle, shortenNames, draw)
    local restores = {}
    local result
    local function expose(battler, nameWidth)
      if not (battler and battler.shownStatus) then return end
      restores[#restores + 1] = {
        battler = battler,
        status = battler.shownStatus,
        name = battler.name,
      }
      exposedStatuses[battler] = battler.shownStatus
      battler.shownStatus = nil
      if nameWidth then battler.name = fitName(battler.name, nameWidth) end
    end

    expose(battle.enemy, shortenNames and 48 or nil)
    expose(battle.player, shortenNames and 40 or nil)

    local ok, err = pcall(function() result = draw() end)
    for i = #restores, 1, -1 do
      local item = restores[i]
      item.battler.shownStatus = item.status
      item.battler.name = item.name
      exposedStatuses[item.battler] = nil
    end
    if not ok then error(err, 0) end
    return result
  end

	local originalWideDraw = WideBattle.draw
	WideBattle.draw = function(battle, ...)
	  local betterBattle = setting(battle)
	  local stockExtended = stockWideExtended(battle)
	  if not betterBattle and not stockExtended then
		return originalWideDraw(battle, ...)
	  end
	  local args = { ... }

	  local originalStatusHUDVisible = rawget(battle, "statusHUDVisible")
	  local originalBottomUIVisible = rawget(battle, "bottomUIVisible")
	  local originalBallRow = battle.drawBallRow
	  local hadOwnBallRow = rawget(battle, "drawBallRow") ~= nil
	  local suppressIntroRows = betterBattle and battle.introBalls == true
	  if suppressIntroRows then
	    battle.drawBallRow = function() end
	  end
	  local bottomVisible = true
	  if type(battle.bottomUIVisible) == "function" then
	    local okVisible, visible = pcall(battle.bottomUIVisible, battle)
	    bottomVisible = okVisible and visible == true
	  end
	  local renderer = battle.game and battle.game.renderer
	  local originalEndBattleHUDPass =
		renderer and renderer.endBattleHUDPass or nil

	  if betterBattle then
		battle.statusHUDVisible = function()
		  return false
		end
		battle.bottomUIVisible = function()
		  return false
		end
	  end

	  if battle:extendedHUD()
		  and renderer
		and originalEndBattleHUDPass then
		renderer.endBattleHUDPass = function(self, previous)
		  if battleIsTopState(battle) then
		    if betterBattle then
		      renderBetterBattleLayer(
		        battle, bottomVisible, originalBallRow)
		    else
		      if enemyVisible(battle) then
		        drawSemanticHpFill(
		          battle, battle.enemy, 1, 2, 11, battle.enemy.shownPx)
		      end
		      if playerVisible(battle) then
		        drawSemanticHpFill(
		          battle, battle.player, 24, 9, 11,
		          battle.player.shownPx)
		      end
		    end
		  end
		  return originalEndBattleHUDPass(self, previous)
		end
	  end

	  local ok, result
	  if betterBattle then
		ok, result = pcall(function()
		  -- BetterBattle renders the widened status panels itself. Do not let
		  -- the native-HUD compatibility wrapper shorten those names before the
		  -- custom renderer sees them.
		  return withNativeLevels(battle, false, function()
          return withBetterBattleField(battle, function()
            return originalWideDraw(battle, unpack(args))
          end)
		  end)
		end)
	  else
		ok, result = pcall(function()
		  return originalWideDraw(battle, unpack(args))
		end)
	  end

	  if betterBattle then
	    battle.statusHUDVisible = originalStatusHUDVisible
	    battle.bottomUIVisible = originalBottomUIVisible
	  end
	  if suppressIntroRows then
	    if hadOwnBallRow then
	      battle.drawBallRow = originalBallRow
	    else
	      battle.drawBallRow = nil
	    end
	  end

	  if renderer and originalEndBattleHUDPass then
		renderer.endBattleHUDPass = originalEndBattleHUDPass
	  end

	  if not ok then
		error(result, 0)
	  end

	  return result
	end

  -- In the normal 160x144 renderer the battle sprites and native HUD share
  -- one canvas. Render the native HUD into a transparent 160x144 layer first,
  -- edit that layer in place, then composite it where the original draw would
  -- have happened. This keeps the game's own tiles and drawing order without
  -- clearing holes through the battlefield underneath the player panel.
  local originalClassicDrawHUDs = BattleState.drawHUDs
  local classicHudLayer

  local function getClassicHudLayer()
    local g = love.graphics
    if classicHudLayer then return classicHudLayer end
    if type(g.newCanvas) ~= "function" then return nil end
    local ok, layer = pcall(g.newCanvas, 160, 144)
    if not ok or not layer then return nil end
    if type(layer.setFilter) == "function" then
      layer:setFilter("nearest", "nearest")
    end
    classicHudLayer = layer
    return classicHudLayer
  end

  local function classicEnhancementActive(battle, slide)
    return setting(battle) and battle and slide == 0
      and not battle.blankForAskName
      and (battle.introSlide or 0) <= 0
      and not battle.introBalls
      and not wideLayout(battle)
      and not stagedLayout(battle)
  end

  local function drawClassicHud(battle, slide, args)
    local g = love.graphics
    if type(g.getCanvas) ~= "function" or type(g.setCanvas) ~= "function"
        or type(g.clear) ~= "function" or type(g.draw) ~= "function" then
      return originalClassicDrawHUDs(battle, slide, unpack(args))
    end
    local layer = getClassicHudLayer()
    if not layer then
      return originalClassicDrawHUDs(battle, slide, unpack(args))
    end

    local previous = g.getCanvas()
    local result
    local pushed = false
    local ok, err = xpcall(function()
      g.push("all")
      pushed = true
      g.setCanvas(layer)
      g.clear(0, 0, 0, 0)
      result = withNativeLevels(battle, false, function()
        local nativeResult = originalClassicDrawHUDs(battle, slide,
          unpack(args))
        drawStagedHudContent(battle, false, true, battleColorMode(battle))
        return nativeResult
      end)
      g.pop()
      pushed = false
      if previous then g.setCanvas(previous) else g.setCanvas() end

      g.push("all")
      pushed = true
      g.setColor(1, 1, 1, 1)
      g.draw(layer, 0, 0)
      g.pop()
      pushed = false
    end, function(err)
    return tostring(err)
  end)

    if pushed then pcall(g.pop) end
    if previous then g.setCanvas(previous) else g.setCanvas() end
    if not ok then error(err, 0) end
    return result
  end

  BattleState.drawHUDs = function(battle, slide, ...)
    local args = { ... }
    if not classicEnhancementActive(battle, slide) then
      return originalClassicDrawHUDs(battle, slide, unpack(args))
    end
    return drawClassicHud(battle, slide, args)
  end

  local originalClassicZonePass = BattleState.drawZonePass
  BattleState.drawZonePass = function(battle, ...)
    local result = originalClassicZonePass(battle, ...)
    if classicEnhancementActive(battle, 0) then
      drawClassicExpFill(battle)
    end
    return result
  end

  -- Gender Mod 0.3.5 anchors the player glyph to the stock level row at
  -- y=64. Our player panel moves that level row to y=56, so teach its public
  -- BattleHUD contract the new coordinate while this HUD is enabled. Its
  -- overlay also normally hides the glyph whenever a status is present;
  -- expose the level slot just for that draw because our layout shows both.
  local function installGenderBridge(game)
    local _, hud = genderCompatibility(game)
    if not hud or hud.battleInfoHudCoordinatesV10 then return end

    if type(hud.classicGenderXY) == "function" then
      local originalClassicXY = hud.classicGenderXY
      hud.classicGenderXY = function(side, level)
        local x, y = originalClassicXY(side, level)
        if setting() and (nativeStagedHudDepth > 0
            or nativeStagedOverlayDepth > 0) then
          -- The authored gender art ends two transparent pixels before the
          -- level glyph. At Battle Art's large integer scale that reads as a
          -- loose gap, so close it by one native pixel without resampling.
          x = x + NATIVE_STAGED_GENDER_X_NUDGE
          if side == "player" then
            -- Force the stock level row even if this bridge was hot-reloaded
            -- on top of an older Battle Info HUD coordinate wrapper.
            y = 64
          end
          return x, y
        end
        if setting() and side == "player" then
          -- Battle Art 1.8+ captures the stock HUD unchanged. Its player
          -- name is still on y=56 and its level is still on y=64, so moving
          -- the gender tile to our enhanced y=56 row would split the name.
          if stagedGenderCaptureDepth > 0 then
            return STAGED_GENDER_SCRATCH_X, STAGED_GENDER_SCRATCH_Y
          end
          y = 56
        end
        return x, y
      end
    end

    if type(hud.wideGenderXY) == "function" then
      local originalWideXY = hud.wideGenderXY
      hud.wideGenderXY = function(side, level)
        local x, y = originalWideXY(side, level)
        if setting() and side == "player" then y = 64 end
        return x, y
      end
    end

    if type(hud.drawOverlay) == "function" then
      local originalOverlay = hud.drawOverlay
      hud.drawOverlay = function(battle, ...)
        local betterBattle = setting(battle)
        local redirectStock = stockWideExtended(battle)
        if not betterBattle and not redirectStock then
          return originalOverlay(battle, ...)
        end
        if betterBattle and layoutFor(battle) == "wide" then
          return
        end
        local args = { ... }
        local saved = {}
        local renderer = battle and battle.game and battle.game.renderer
        local targetCanvas = redirectStock and renderer
          and renderer.battleHUDCanvas or nil
        local previousRendererCanvas = renderer and renderer.canvas
        if targetCanvas then renderer.canvas = targetCanvas end

        if targetCanvas then
          local g = love.graphics
          local previousCanvas = g.getCanvas and g.getCanvas() or nil
          g.push("all")
          g.setCanvas(targetCanvas)
          if g.origin then g.origin() end
          drawStockGenderBackplates(battle)
          g.pop()
          if previousCanvas then g.setCanvas(previousCanvas)
          else g.setCanvas() end
        end

        local nativeStagedOverlay = betterBattle
          and nativeStagedHudOwner
          and stagedLayout(battle)
        if betterBattle then
          for _, battler in pairs({ battle and battle.enemy,
              battle and battle.player }) do
            if battler and battler.shownStatus then
              saved[#saved + 1] = {
                battler = battler, status = battler.shownStatus,
              }
              battler.shownStatus = nil
            end
          end
        end
        local result
        if nativeStagedOverlay then
          -- Gender Mod draws a second coloured glyph after Battle Art has
          -- captured the HUD. Keep that pass on the same stock level row as
          -- the captured glyph instead of repainting it through the name.
          nativeStagedOverlayDepth = nativeStagedOverlayDepth + 1
        end
        local ok, err = xpcall(function()
          result = originalOverlay(battle, unpack(args))
        end, function(err)
		return tostring(err)
		end)
        if targetCanvas then renderer.canvas = previousRendererCanvas end
        if nativeStagedOverlay then
          nativeStagedOverlayDepth = math.max(0,
            nativeStagedOverlayDepth - 1)
        end
        for i = #saved, 1, -1 do
          saved[i].battler.shownStatus = saved[i].status
        end
        if not ok then error(err, 0) end
        return result
      end
    end

    hud.battleInfoHudCoordinatesV10 = true
    mod.log:info("attached HUD coordinates to Gender Mod")
  end

  local genderCellLayer

  local function withStagedGenderCapture(draw)
    stagedGenderCaptureDepth = stagedGenderCaptureDepth + 1
    local result
    local ok, err = xpcall(function()
      result = draw()
	end, function(err)
	  return tostring(err)
	end)
    stagedGenderCaptureDepth = math.max(0, stagedGenderCaptureDepth - 1)
    if not ok then error(err, 0) end
    return result
  end

  local function captureStagedGenderCell(battle, layer)
    local _, hud = genderCompatibility(battle and battle.game)
    if not (hud and type(hud.classicGenderXY) == "function"
        and hud.battleInfoHudCoordinatesV10
        and playerVisible(battle)) then return nil end
    local level = battle.player.mon and battle.player.mon.level or 1
    local okXY, targetX, targetY = pcall(hud.classicGenderXY,
      "player", level)
    if not okXY or type(targetX) ~= "number"
        or type(targetY) ~= "number" then
      return nil
    end

    local g = love.graphics
    if type(g.newCanvas) ~= "function" or type(g.clear) ~= "function"
        or type(g.draw) ~= "function" or type(g.getCanvas) ~= "function"
        or type(g.setCanvas) ~= "function" then return nil end
    if not genderCellLayer then
      -- The authored icon is 8x8. Dramatic Shape can add a one-pixel shadow
      -- down/right while baking the HUD, so retain that ninth edge too.
      local okCanvas, canvas = pcall(g.newCanvas,
        STAGED_GENDER_CAPTURE_SIZE, STAGED_GENDER_CAPTURE_SIZE)
      if not okCanvas or not canvas then return nil end
      if type(canvas.setFilter) == "function" then
        canvas:setFilter("nearest", "nearest")
      end
      genderCellLayer = canvas
    end

    local previous = g.getCanvas()
    g.push("all")
    g.setCanvas(genderCellLayer)
    g.clear(0, 0, 0, 0)
    g.setColor(1, 1, 1, 1)
    g.draw(layer, -STAGED_GENDER_SCRATCH_X,
      -STAGED_GENDER_SCRATCH_Y)
    g.pop()
    if previous then g.setCanvas(previous) else g.setCanvas() end
    return genderCellLayer, targetX, targetY
  end

  local function composeStagedTexture(battle, layer, inkPass)
    if not layer then return end
    local g = love.graphics
    if type(g.getCanvas) ~= "function" or type(g.setCanvas) ~= "function" then
      return
    end
    local previous = g.getCanvas()
    local genderCell, genderX, genderY =
      captureStagedGenderCell(battle, layer)
    g.push("all")
    g.setCanvas(layer)
    if genderCell then
      -- Gender Mod originally paints into a clean scratch cell so rebuilding
      -- the player HUD cannot copy name, underline or panel pixels along with
      -- its authored icon. Remove that staging cell before the band is moved.
      if type(g.setBlendMode) == "function" then
        g.setBlendMode("replace", "premultiplied")
      end
      g.setColor(0, 0, 0, 0)
      g.rectangle("fill", STAGED_GENDER_SCRATCH_X,
        STAGED_GENDER_SCRATCH_Y, STAGED_GENDER_CAPTURE_SIZE,
        STAGED_GENDER_CAPTURE_SIZE)
    end
    if type(g.setBlendMode) == "function" then g.setBlendMode("alpha") end
    if inkPass then
      -- Some Dramatic Shape forks bake white-on-dark HUD ink through a
      -- shader while creating the texture. Clear the original player block
      -- on the finished layer, then send our replacement glyphs through that
      -- same pass so they inherit the fork's current contrast treatment.
      if playerVisible(battle) then clearStagedPlayerHud() end
      inkPass(function() drawStagedHudContent(battle, true, false) end)
      drawStagedSemanticHpFills(battle)
    else
      drawStagedHudContent(battle, false, false)
    end
    if genderCell then
      g.setColor(1, 1, 1, 1)
      g.draw(genderCell, genderX, genderY)
    end
    g.pop()
    if previous then g.setCanvas(previous) else g.setCanvas() end
  end

  -- Staged battle providers publish their HUD as a separate transparent
  -- texture. Palette that texture in isolation so BetterMenus can cover the
  -- provider's panels without ever sending the battle scene or its sprites
  -- through the menu shader. Re-seat native HP fills afterward so their
  -- semantic green/yellow/red colors remain intact.
  local providerPaletteLayers = setmetatable({}, { __mode = "k" })
  local providerPaletteFailures = {}

  local function paletteProviderHudTexture(battle, layer, companionId)
    if not (layer and menuColors) then return layer end
    local g = love.graphics
    if type(g.newCanvas) ~= "function" or type(g.getCanvas) ~= "function"
        or type(g.setCanvas) ~= "function" or type(g.clear) ~= "function"
        or type(g.draw) ~= "function"
        or type(layer.getDimensions) ~= "function" then return layer end

    local shader = PaletteFX.shader()
    if not shader then return layer end
    local okSize, width, height = pcall(layer.getDimensions, layer)
    if not okSize or type(width) ~= "number" or type(height) ~= "number"
        or width <= 0 or height <= 0 then return layer end

    local record = providerPaletteLayers[layer]
    if not record or record.width ~= width or record.height ~= height then
      local okCanvas, canvas = pcall(g.newCanvas, width, height)
      if not okCanvas or not canvas then return layer end
      if type(canvas.setFilter) == "function" then
        canvas:setFilter("nearest", "nearest")
      end
      record = { canvas = canvas, width = width, height = height }
      providerPaletteLayers[layer] = record
    end

    local previous = g.getCanvas()
    local pushed = false
    local ok, err = xpcall(function()
      g.push("all")
      pushed = true
      g.setCanvas(record.canvas)
      g.clear(0, 0, 0, 0)
      if type(g.setBlendMode) == "function" then
        g.setBlendMode("replace", "premultiplied")
      end
      g.setColor(1, 1, 1, 1)
      PaletteFX.sendColors(shader, menuColors())
      g.setShader(shader)
      g.draw(layer, 0, 0)
      g.setShader()
      if type(g.setBlendMode) == "function" then g.setBlendMode("alpha") end
      drawStagedSemanticHpFills(battle)
      g.pop()
      pushed = false
      if previous then g.setCanvas(previous) else g.setCanvas() end
    end, function(message)
      return tostring(message)
    end)

    if pushed then pcall(g.pop) end
    if previous then g.setCanvas(previous) else g.setCanvas() end
    if not ok then
      local id = tostring(companionId or "battle provider")
      if not providerPaletteFailures[id] then
        providerPaletteFailures[id] = true
        mod.log:warn("could not palette %s HUD texture: %s", id, err)
      end
      return layer
    end
    return record.canvas
  end

  -- Dramatic Shape snapshots the original classic HUD into a 160x144 texture
  -- and then moves that texture to the window edges. Edit that texture before
  -- it is placed; staged battles never draw these additions afterward.
  local function installDramaticBridge(game, companionId)
    local exports = game and game.mods and game.mods.exports
    local api = exports and exports[companionId]
    local lib = api and api.lib
    if not (lib and type(lib.require) == "function") then return end
    local ok, overworld = pcall(lib.require, "OverworldBattle")
    if not ok or type(overworld) ~= "table"
        or type(overworld.hudTexture) ~= "function" then return end
    local innerHudTexture = overworld.hudTexture
    local innerSnapRects = overworld.snapRects
    local companionApi = exports and exports[companionId]
    local companionVersion = tostring(companionApi and companionApi.version
      or "0")
    local companionMajor, companionMinor = companionVersion:match(
      "^(%d+)%.(%d+)")
    local usesNativeStagedHud = companionId == "BATTLE_ART_VOXEL_FORK"
      and ((tonumber(companionMajor) or 0) > 1
        or ((tonumber(companionMajor) or 0) == 1
          and (tonumber(companionMinor) or 0) >= 8))
    if usesNativeStagedHud then nativeStagedHudOwner = true end
    if overworld.battleInfoHudTextureEditorV6 then return end

    -- Battle Art 1.8+ publishes and owns a complete snapped HUD pipeline.
    -- Repainting its private 160x144 capture through the older 1.7 bridge
    -- changes the block dimensions after the fork has already calculated its
    -- window-edge placement; in move selection that pulls names and HP bars
    -- back into the arena. Leave the fork's HUD capture and placement intact.
    -- The classic and engine-WIDE renderers remain enhanced below.
    if usesNativeStagedHud then
      overworld.hudTexture = function(liveBattle, ...)
        local args = { ... }
        nativeStagedHudDepth = nativeStagedHudDepth + 1
        local layer
        local okLayer, layerErr = xpcall(function()
          layer = innerHudTexture(liveBattle, unpack(args))
        end, function(err)
		return tostring(err)
		end)
        nativeStagedHudDepth = math.max(0, nativeStagedHudDepth - 1)
        if not okLayer then error(layerErr, 0) end
        if not setting(liveBattle) then
          return paletteProviderHudTexture(liveBattle, layer, companionId)
        end
        return layer
      end
      overworld.battleInfoHudTextureEditorV6 = true
      mod.log:info("preserving %s %s native staged HUD coordinates",
        companionId, companionVersion)
      return
    end

    -- Dramatic Shape normally frosts the stock 40px-tall player HUD. Our
    -- texture keeps the same bottom/right edges but grows upward by one tile
    -- and leftward by two, so extend only the matching panel rect while it is
    -- enabled. OFF immediately restores Dramatic Shape's untouched geometry.
    if type(innerSnapRects) == "function" then
      overworld.snapRects = function(shot)
        local rects, bandPlacement = innerSnapRects(shot)
        if setting() and rects and rects.player and shot then
          local placement = bandPlacement and bandPlacement.player
          if type(placement) == "table" then
            -- BATTLE_ART_VOXEL_FORK can scale the snapped HUD separately
            -- from the battle letterbox and reports that exact placement.
            local scale = placement.scale or shot.scale or 1
            rects.player[1] = (placement.x or 0) + 56 * scale
            rects.player[2] = placement.y
              or ((shot.ly or 0) + 48 * scale)
            rects.player[3] = 104 * scale
            rects.player[4] = 48 * scale
          else
            -- Upstream Dramatic Shape keeps the band at shot.scale. Grow the
            -- returned native panel left/up without assuming its absolute x.
            local scale = shot.scale or 1
            rects.player[1] = rects.player[1] - 16 * scale
            rects.player[2] = rects.player[2] - 8 * scale
            rects.player[3] = rects.player[3] + 16 * scale
            rects.player[4] = rects.player[4] + 8 * scale
          end
        end
        return rects, bandPlacement
      end
    end

    overworld.hudTexture = function(liveBattle, ...)
      local args = { ... }
      if not setting(liveBattle) then
        local layer = innerHudTexture(liveBattle, unpack(args))
        return paletteProviderHudTexture(liveBattle, layer, companionId)
      end
      installGenderBridge(liveBattle.game)
      local layer = withStagedGenderCapture(function()
        return withNativeLevels(liveBattle, false, function()
          return innerHudTexture(liveBattle, unpack(args))
        end)
      end)
      local inkPass
      if args[2] == true then
        local okHud, battleHud = pcall(lib.require, "BattleHud")
        if okHud and battleHud
            and type(battleHud.flipGlyphs) == "function" then
          inkPass = function(draw)
            return battleHud.flipGlyphs(160, 144, draw, args[3], nil,
              args[4])
          end
        end
      end
      composeStagedTexture(liveBattle, layer, inkPass)
      return layer
    end
    overworld.battleInfoHudTextureEditorV6 = true
    mod.log:info("attached staged HUD to %s", companionId)
  end

  local function installDramaticBridges(game)
    local attempted = {}
    for _, companionId in ipairs(STAGED_COMPANIONS) do
      attempted[companionId] = true
      installDramaticBridge(game, companionId)
    end
    local exports = game and game.mods and game.mods.exports or {}
    for companionId, api in pairs(exports) do
      if not attempted[companionId] and type(api) == "table"
          and api.lib and type(api.lib.require) == "function" then
        installDramaticBridge(game, companionId)
      end
    end
  end

  mod.events:on("game.ready", function(ev)
    hudGame = ev and ev.game
    installGenderBridge(hudGame)
    installDramaticBridges(hudGame)
  end)

local originalBattlePalettes = BattleState.sgbPalettes

BattleState.sgbPalettes = function(battle, ...)
  local zones = originalBattlePalettes(battle, ...) or {}
  -- BetterBattle supplies its palette directly to its HUD-canvas blit.
  -- Its atlas rectangles must never recolor the main Pokémon canvas.
  if setting(battle) then return zones end

  if not (battle and battle:wideLayout() and menuColors) then
    return zones
  end

  local palette = menuColors()
  local battleMode = effectiveBattleMode(battle)
  local betterBattle = setting(battle)

	-- BetterBattle owns five detached regions in the extended HUD canvas. The
	-- stock/provider regions remain untouched here; their palette coverage is
	-- supplied by the renderer hook below.
	if betterBattle and battle:extendedHUD() then
	  zones[#zones + 1] = PaletteFX.zone(palette, 0, 0, 15, 3)
	  zones[#zones + 1] = PaletteFX.zone(palette, 22, 0, 37, 3)
	  zones[#zones + 1] = PaletteFX.zone(palette, 0, 4, 16, 9)
	  zones[#zones + 1] = PaletteFX.zone(palette, 21, 4, 37, 7)
	  zones[#zones + 1] = PaletteFX.zone(palette, 0, 10, 37, 17)
	elseif not battle:extendedHUD() then
	  if enemyVisible(battle) then
		zones[#zones + 1] = PaletteFX.zone(palette, 0, 0, 15, 3)
	  end
	  if playerVisible(battle) then
		zones[#zones + 1] = PaletteFX.zone(palette, 23, 7, 37, 12)
	  end
	end

	-- The HUD panels use the menu palette, but HP and EXP fills are semantic
	-- colors. Re-blit only those two-pixel fills without the shade shader so
	-- inverse mode cannot turn green/blue into a menu shade. Keeping the
	-- opt-out this narrow also lets the custom XP X follow the menu palette.
  local function trueColorFill(battler, x, y, segments, pixels)
    local hp = shownHP(battler)
    local maxHp = battler.mon.stats.hp
    local shownPixels = tonumber(pixels)
    local px
    if shownPixels ~= nil then
      px = math.floor(math.max(0, shownPixels) * segments / 6)
    else
      px = maxHp > 0 and math.floor(hp * segments * 8 / maxHp) or 0
    end
    px = math.min(segments * 8, math.max(0, px))
    if hp > 0 then px = math.max(1, px) end
    if px > 0 then
      zones[#zones + 1] = { colors = false, x = x, y = y, w = px, h = 2 }
	  end
	end

	if betterBattle then
	  if enemyVisible(battle) then
		trueColorFill(battle.enemy, 208, 51, 11)
	  end
	  if playerVisible(battle) then
		trueColorFill(battle.player, 24, 51, 11)
		local state = getBattleXpState(battle)
		local px = state.shown or 0
		if px > 0 then
		  zones[#zones + 1] = {
			colors = false, x = 24, y = 67, w = px, h = 2,
		  }
		end
	  end
  elseif battleMode == "off" then
    -- Stock WIDE uses a 48-pixel animated HP value. Exempt only its
    -- two-pixel semantic fill from the BetterMenus palette.
    if enemyVisible(battle) then
      trueColorFill(battle.enemy, 24, 19, 11, battle.enemy.shownPx)
    end
    if playerVisible(battle) then
      trueColorFill(battle.player, 208, 75, 11, battle.player.shownPx)
    end
  else
    -- MOD provider HUDs retain their existing provider-owned exemption.
    if enemyVisible(battle) then
      zones[#zones + 1] = { colors = false, x = 8, y = 16, w = 112, h = 8 }
	  end
	  if playerVisible(battle) then
		zones[#zones + 1] = { colors = false, x = 192, y = 72, w = 112, h = 8 }
	  end
	end

	if levelUpStatBoxVisible(battle) then
	  zones[#zones + 1] = PaletteFX.zone(
		palette,
		27, 2,
		37, 11
	  )
	end

	return zones
	end

  mod.hooks:wrap("battle.overlay", function(next, battle)
    installGenderBridge(battle and battle.game)
    local layout = layoutFor(battle)
    if not layout then return next(battle) end
    if layout == "staged" then
      installDramaticBridges(battle.game)
      return next(battle)
    end
    next(battle)
    renderWide(battle)
  end, 50)
end
