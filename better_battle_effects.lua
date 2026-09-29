-- Gen1Better animation presentation, using the original engine draw callback.
local Effects = {}
local OBJ_SHADES = {
  f0 = { 0, 3, 3 },   -- color 1 -> shade 0, colors 2/3 -> shade 3
  f0x = { 3, 0, 3 },  -- $f0 xor %00111100 = $cc (DoBallTossSpecialEffects,
                      -- engine/battle/animations.asm:685)
  e4 = { 1, 2, 3 },   -- identity
  e4x = { 2, 1, 3 },  -- $e4 xor %00111100 = $d8
  obp1 = { 3, 2, 1 }, -- $6c
}

local BALL_ANIMS = {
  TOSS_ANIM = true, GREATTOSS_ANIM = true, ULTRATOSS_ANIM = true,
  BLOCKBALL_ANIM = true, POOF_ANIM = true, HIDEPIC_ANIM = true,
  SHAKE_ANIM = true, SHOWPIC_ANIM = true,
}

local ANIM_TYPE_PALETTES = {
  NORMAL = "BROWNMON", FIGHTING = "REDMON", FLYING = "BLUEMON",
  POISON = "PURPLEMON", GROUND = "BROWNMON", ROCK = "BROWNMON",
  BUG = "GREENMON", GHOST = "PURPLEMON", FIRE = "REDMON",
  WATER = "CYANMON", GRASS = "GREENMON", ELECTRIC = "YELLOWMON",
  PSYCHIC = "PURPLEMON", ICE = "BLUEMON", DRAGON = "PURPLEMON",
}
local ANIM_SPECIAL_PALETTES = {
  TOSS_ANIM = "REDMON", GREATTOSS_ANIM = "REDMON",
  ULTRATOSS_ANIM = "YELLOWMON", BLOCKBALL_ANIM = "REDMON",
  SHAKE_ANIM = "REDMON", POOF_ANIM = "BLUEMON",
  BURN_PSN_ANIM = "PURPLEMON", SLP_ANIM = "BLUEMON",
  SLP_PLAYER_ANIM = "BLUEMON", CONF_ANIM = "PURPLEMON",
  CONF_PLAYER_ANIM = "PURPLEMON",
  PETAL_DANCE = "PINKMON", -- petals keep their own color, not grass green
}
local GUST_PALETTE = {
  { 255, 255, 255 },
  { 255, 255, 255 },
  { 144, 144, 144 },
  { 0, 0, 0 },
}
local BALL_BODY_ANIMS = {
  TOSS_ANIM = true, GREATTOSS_ANIM = true, ULTRATOSS_ANIM = true,
  BLOCKBALL_ANIM = true, SHAKE_ANIM = true,
}
function Effects.colors(battle, s)
  local PaletteFX = require("src.render.PaletteFX")
  local id = battle.animName
  local move = id and battle.data and battle.data.moves and battle.data.moves[id]
  local name = ANIM_SPECIAL_PALETTES[id]
    or (move and ANIM_TYPE_PALETTES[move.type]) or "YELLOWMON"
  local P = id == "GUST" and GUST_PALETTE
    or PaletteFX.effectiveColors(PaletteFX.pal(battle.data, name))
  if not P then return battle:animSpriteColors(s) end
  -- The hardware's $f0 map collapses most effect tiles to white/black.
  -- Wide true-color drawing uses the three source shades instead, while
  -- preserving OBP1's reversed shading and the ball-flicker swap.
  local key = s.obp or "f0"
  if key == "f0" then key = "e4"
  elseif key == "f0x" then key = "e4x" end
  local m = OBJ_SHADES[key] or OBJ_SHADES.e4
  if BALL_BODY_ANIMS[id] and key == "e4" then
    m = { 0, 2, 3 } -- white lower half, colored upper half, dark outline
  elseif BALL_BODY_ANIMS[id] and key == "e4x" then
    m = { 2, 0, 3 } -- preserve Master/Ultra ball palette flicker
  elseif id == "PETAL_DANCE" and key == "e4" then
    m = { 1, 1, 3 } -- the single-shade petal tile uses the lighter pink
  end
  local function c(shade)
    local col = P[shade + 1]
    if shade == 3 and not BALL_ANIMS[id] and id ~= "GUST" then
      -- Some effect tiles contain only the darkest ink.  Keep that ink dark
      -- but give it the effect's hue, so sparks and status marks colorize too.
      local hue = P[3]
      return { (hue[1] * 0.75 + col[1] * 0.25) / 255,
               (hue[2] * 0.75 + col[2] * 0.25) / 255,
               (hue[3] * 0.75 + col[3] * 0.25) / 255 }
    end
    return { col[1] / 255, col[2] / 255, col[3] / 255 }
  end
  return { c(m[1]), c(m[2]), c(m[3]) }
end

-- The stock animation player exposes effect events with their starting frame.
-- Keep the classification in the mod; never add fields to engine steps.
local fullFieldEffects = {
  SE_WATER_DROPLETS_EVERYWHERE = true,
  SE_PETALS_FALLING = true,
}
local stepCache = setmetatable({}, { __mode = "k" })
function Effects.isScreenWide(player, step)
  if not player or not step then return false end
  local steps = player.steps
  local marked = stepCache[steps]
  if not marked then
    marked = {}
    local starts, frame = {}, 0
    for _, current in ipairs(steps) do
      starts[frame] = current
      frame = frame + current.dur
    end
    local first = {}
    for _, event in ipairs(player.events or {}) do
      if fullFieldEffects[event.effect] and starts[event.frame] then
        first[starts[event.frame]] = true
      end
    end
    local active = false
    for _, current in ipairs(steps) do
      if first[current] then active = true end
      if #current.sprites == 0 then active = false end
      if active then marked[current] = true end
    end
    stepCache[steps] = marked
  end
  return marked[step] == true
end

function Effects.draw(battle)
  if battle.fieldCleared or not battle.animPlayer then return end
  local colorFn = function(sprite) return Effects.colors(battle, sprite) end
  love.graphics.setColor(1, 1, 1, 1)
  if battle.animPlaying then
    battle.animPlayer:draw(colorFn)
  elseif battle.lockedBall then
    battle.animPlayer:drawSprites(battle.lockedBall, colorFn)
  end
end

return Effects
