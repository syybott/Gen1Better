-- Internal BetterBattle module. HP/XP drawing and private per-battle XP animation state.
-- Loaded once by better_battle_hud.lua; not a public consumer API.
return function(deps)
  local M = {}
  local Layout = assert(deps.layout)
  local Policy = assert(deps.policy)
  local Font = require("src.render.Font")
  local Growth = require("src.pokemon.Growth")
  local HudTiles = require("src.render.HudTiles")
  local PaletteFX = require("src.render.PaletteFX")
  local mod = deps.mod

  local EXP_GLINT = { 118 / 255, 190 / 255, 1, 1 }

  local EXP_GLINT_FRAMES = 14

  local EXP_BURST_FRAMES = 20

  local EXP_BURST_SPARKS = {
    { -1.00, 0.00, 1 },
    { -0.72, -0.72, 1 },
    { 0.00, -1.00, 2 },
    { 0.72, -0.72, 1 },
    { 1.00, 0.00, 1 },
    { 0.72, 0.72, 1 },
    { 0.00, 1.00, 2 },
    { -0.72, 0.72, 1 },
  }

  local xpStates = setmetatable({}, { __mode = "k" })

  function M.getBattleXpState(battle)
    if not battle then return {} end
    if not xpStates[battle] then xpStates[battle] = {} end
    return xpStates[battle]
  end

  local function expProgress(data, mon)
    local def = data and data.pokemon and mon and data.pokemon[mon.species]
    if not def then return 0, 1, 0, false end
    local level = math.max(1, math.floor(mon.level or 1))
    local cap = data.constants and data.constants.levelCap or 100
    if level >= cap then return 0, 0, 1, true end
    local floorExp = Growth.expForLevel(def.growthRate, level, data.growth_rates)
    local nextExp = Growth.expForLevel(def.growthRate, level + 1, data.growth_rates)
    local needed = math.max(1, nextExp - floorExp)
    local current = math.max(0, math.min(needed, (mon.exp or floorExp) - floorExp))
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
    return value < target and math.min(target, value + step) or math.max(target, value - step)
  end

  local function advanceExpDisplay(battle, maxPixels)
    local state = M.getBattleXpState(battle)
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

  local function drawExpGlint(state, x, y, width, mark, markDx, markDy)
    if not (state and state.stage == "glint" and state.glint) then return end
    local travel = width + 4
    local left = x - 2 + math.floor(travel * state.glint / math.max(1, EXP_GLINT_FRAMES - 1))
    local clipX = math.max(x, left)
    local clipRight = math.min(x + width, left + 4)
    if clipRight <= clipX then return end
    love.graphics.setShader()
    love.graphics.setColor(EXP_GLINT)
    love.graphics.rectangle("fill", clipX, y, clipRight - clipX, 2)
    if mark then
      PaletteFX.markTrueColor(clipX + (markDx or 0), y + (markDy or 0), clipRight - clipX, 2)
    end
  end

  local function drawExpBurst(state, x, y, width, mark, markDx, markDy)
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
      if mark then PaletteFX.markTrueColor(px + (markDx or 0), py + (markDy or 0), size, size) end
    end
  end

  local function shortNumber(value)
    if value < 1000 then return tostring(value) end
    if value < 1000000 then return tostring(math.floor(value / 1000 + 0.5)) .. "K" end
    return tostring(math.floor(value / 1000000 + 0.5)) .. "M"
  end

  function M.drawNativeHP(battle, battler, tx, ty, barType, segments, markColor, grayFill)
    HudTiles.drawHPBar(battle.data, tx, ty, {
      hp = Policy.shownHP(battler),
      stats = battler.mon.stats,
    }, barType, grayFill == true, segments)
    if markColor ~= false then PaletteFX.markTrueColor(tx * 8, ty * 8, (segments + 3) * 8, 8) end
  end

  -- A dark-HUD companion may whiten the native bar's dark tinted fill while
  -- it flips black glyphs. Re-seat just the two interior fill rows afterward
  -- with the same GREENBAR/YELLOWBAR/REDBAR palette decision as HudTiles.
  function M.drawSemanticHpFill(battle, battler, tx, ty, segments, pixels, markDx, markDy, fillDx)
    local hp = Policy.shownHP(battler)
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
    local name = px >= green and "GREENBAR" or px >= yellow and "YELLOWBAR" or "REDBAR"
    local colors = PaletteFX.pal(battle.data, name)
    local c = colors and colors[3]
    local fallback = name == "GREENBAR" and { 0, 189, 0 }
      or name == "YELLOWBAR" and { 247, 165, 0 }
      or { 247, 0, 0 }
    c = c or fallback
    love.graphics.setColor(c[1] / 255, c[2] / 255, c[3] / 255, 1)
    love.graphics.rectangle("fill", tx * 8 + 16 + (fillDx or 0), ty * 8 + 3, px, 2)
    PaletteFX.markTrueColor(tx * 8 + 16 + (markDx or 0), ty * 8 + 3 + (markDy or 0), px, 2)
  end

  local xpMarkImage

  local function getXpMarkImage()
    if xpMarkImage ~= nil then return xpMarkImage or nil end

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

  function M.drawExpProgress(
    battle,
    battler,
    x,
    y,
    width,
    barY,
    markColor,
    segments,
    barType,
    markDx,
    markDy
  )
    local tx = math.floor(x / 8)
    local ty = math.floor(y / 8)
    segments = math.max(1, math.floor(segments or 11))
    local maxPixels = segments * 8

    local fill, state = advanceExpDisplay(battle, maxPixels)

    local fakeMax = 48
    local fakeHp = math.floor(fakeMax * (fill / maxPixels) + 0.5)

    if fill > 0 then fakeHp = math.max(1, fakeHp) end

    HudTiles.drawHPBar(battle.data, tx, ty, {
      hp = fakeHp,
      stats = { hp = fakeMax },
    }, barType, false, segments)

    -- Replace HP green fill with EXP blue
    if fill > 0 then
      local fillShader = love.graphics.getShader()
      love.graphics.setShader()
      love.graphics.setColor(EXP_GLINT)
      love.graphics.rectangle("fill", tx * 8 + 16, ty * 8 + 3, fill, 2)
      love.graphics.setShader(fillShader)
    end

    -- Cover only the H portion of the stock HP label
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", tx * 8 + 1, ty * 8 + 2, 4, 4)

    -- Draw our custom X in the exact same spot
    local xpMark = getXpMarkImage()

    if xpMark then
      love.graphics.setColor(0, 0, 0, 1)
      love.graphics.draw(xpMark, tx * 8 + 1, ty * 8 + 2)
    end

    if markColor ~= false and fill > 0 then
      PaletteFX.markTrueColor(tx * 8 + 16 + (markDx or 0), ty * 8 + 3 + (markDy or 0), fill, 2)
    end

    drawExpGlint(state, tx * 8 + 16, ty * 8 + 3, maxPixels, markColor ~= false, markDx, markDy)
    drawExpBurst(state, tx * 8 + 16, ty * 8 + 3, maxPixels, markColor ~= false, markDx, markDy)
  end

  -- Classic colorized battles run their finished 160x144 background through
  -- a second, internal SGB zone pass before the renderer's normal frame pass.
  -- HP can enter that pass as native shade gray, but a deliberately blue EXP
  -- pixel cannot. Re-seat only its filled pixels immediately after the battle
  -- zone pass; this is still part of the original HUD draw, before pics and
  -- animations are composited.
  function M.drawClassicExpFill(battle)
    if not Policy.playerVisible(battle) then return end
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

  function M.drawWideHP(battle, battler, tx, ty)
    local padded = Layout.framePadding() > 0
    if padded then
      love.graphics.push()
      love.graphics.translate(2, 6)
    end
    M.drawNativeHP(
      battle,
      battler,
      tx,
      ty,
      Layout.WIDE_METER_CAP_TYPE,
      Layout.WIDE_METER_SEGMENTS,
      false
    )
    M.drawSemanticHpFill(
      battle,
      battler,
      tx,
      ty,
      Layout.WIDE_METER_SEGMENTS,
      nil,
      padded and 2 or 0,
      padded and 6 or 0
    )
    if padded then love.graphics.pop() end
  end

  return M
end
