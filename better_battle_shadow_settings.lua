-- Offsets and baseline dimensions are in sprite pixels.
-- All species start grounded. Set grounding = "flying" to opt in later.
-- bodyRegion is false or { left, right, top, bottom } using named fields
-- normalized to the frame's opaque bounds. It is a manual body mask,
-- not automatic wing detection; side overrides replace the whole region.
-- anchorMode is "contact" or "body". anchorX is an optional normalized
-- manual override within the measured opaque region.
-- manualAnchorX/manualContactY are sprite-local coordinates in the canonical
-- 56x56 front sprite. They are authored visual projections for reviewed
-- species; they do not come from automatic pixel measurements.
local settings = {
  defaults = {
    -- false retains the existing species configuration.
    -- Explicit modes: manual, automatic, combined.
    shadowMode = false,
    -- Ordered, unlimited list of independent ellipses.
    -- Each shape has source (manual/detected), opacity and rotationDegrees.
    -- Manual: x, y, width, height in canonical front-sprite pixels.
    -- Detected: optional region (normalized opaque bounds), authored x/y,
    -- offsetX/Y, widthScale/heightScale and minWidth/minHeight.
    -- Optional animate(context) returns per-draw field overrides.
    -- Context contains sprite, frame, side, species and measurement.
    -- Manual shapes can opt into detection in combined mode with
    -- detection = true; their animate callback owns the response.
    shadowShapes = false,
    -- Contribution > side > species > defaults. false disables a bound.
    -- Manual ellipses never use these detection settings.
    detectionSizing = {
      contactWidthScale = 1.30,
      bodyWidthScale = 0.44,
      minimumWidth = 8,
      maximumWidthScale = 0.70,
      heightScale = 0.16,
      minimumHeight = 2.5,
      maximumHeight = 4.5,
    },
    -- Automatic body detection only. Manual ellipses and detected wing
    -- contributions do not use these values.
    automaticBody = {
      sizeScale = 2,
      spriteWidthScale = 0.44,
      majorExtentScale = 0.44,
      minimumContactCoverage = 0.20,
      maximumContactOffset = 0.25,
    },
    -- Additional detected contributions for wings. false disables wing
    -- measurement. Each entry can override region, offsets, dimensions,
    -- opacity, rotation and detectionSizing independently.
    wingShadows = false,
    offsetX = 0, offsetY = 0,
    widthScale = 1, heightScale = 1, opacityScale = 1,
    grounding = "grounded",
    baseWidth = 12, baseHeight = 3.75,
    bodyRegion = false,
    anchorMode = "contact",
    anchorX = false,
    manualAnchorX = false,
    manualContactY = false,
    innerRing = false,
    middleRing = false,
    rotationDegrees = 0,
  },
  schemaVersion = 1,
  profileVersion = 1,
  species = {},
  scenes = {},
}
-- Initial size assignments informed by local Gen 1 height/weight data.
-- Explicit baselines only; no physical-size ranking runs during gameplay.
local baselines = {
  BULBASAUR = { 16, 4.5 },
  IVYSAUR = { 20, 5.25 },
  VENUSAUR = { 28, 6.75 },
  CHARMANDER = { 16, 4.5 },
  CHARMELEON = { 20, 5.25 },
  CHARIZARD = { 28, 6.75 },
  SQUIRTLE = { 12, 3.75 },
  WARTORTLE = { 20, 5.25 },
  BLASTOISE = { 46, 14 },
  CATERPIE = { 12, 3.75 },
  METAPOD = { 16, 4.5 },
  BUTTERFREE = { 20, 5.25 },
  WEEDLE = { 12, 3.75 },
  KAKUNA = { 16, 4.5 },
  BEEDRILL = { 20, 5.25 },
  PIDGEY = { 12, 3.75 },
  PIDGEOTTO = { 28, 7.5 },
  PIDGEOT = { 34, 9.0 },
  RATTATA = { 36, 10.0 },
  RATICATE = { 42, 11.5 },
  SPEAROW = { 12, 3.75 },
  FEAROW = { 20, 5.25 },
  EKANS = { 16, 4.5 },
  ARBOK = { 24, 6 },
  PIKACHU = { 12, 3.75 },
  RAICHU = { 28, 7.5 },
  SANDSHREW = { 24, 6.5 },
  SANDSLASH = { 20, 5.25 },
  NIDORAN_F = { 12, 3.75 },
  NIDORINA = { 16, 4.5 },
  NIDOQUEEN = { 24, 6 },
  NIDORAN_M = { 34, 9.0 },
  NIDORINO = { 38, 10.0 },
  NIDOKING = { 24, 6 },
  CLEFAIRY = { 16, 4.5 },
  CLEFABLE = { 24, 6 },
  VULPIX = { 36, 9.5 },
  NINETALES = { 20, 5.25 },
  JIGGLYPUFF = { 12, 3.75 },
  WIGGLYTUFF = { 36, 9.5 },
  ZUBAT = { 16, 4.5 },
  GOLBAT = { 24, 6 },
  ODDISH = { 12, 3.75 },
  GLOOM = { 16, 4.5 },
  VILEPLUME = { 20, 5.25 },
  PARAS = { 12, 3.75 },
  PARASECT = { 22, 5.75 },
  VENONAT = { 20, 5.25 },
  VENOMOTH = { 30, 8 },
  DIGLETT = { 16, 4.5 },
  DUGTRIO = { 26, 7.0 },
  MEOWTH = { 12, 3.75 },
  PERSIAN = { 38, 10.5 },
  PSYDUCK = { 18, 5.0 },
  GOLDUCK = { 46, 11.5 },
  MANKEY = { 26, 7.0 },
  PRIMEAPE = { 28, 7.5 },
  GROWLITHE = { 16, 4.5 },
  ARCANINE = { 42, 11.5 },
  POLIWAG = { 24, 6.5 },
  POLIWHIRL = { 20, 5.25 },
  POLIWRATH = { 36, 9.5 },
  ABRA = { 24, 6.5 },
  KADABRA = { 38, 10.0 },
  ALAKAZAM = { 36, 9.5 },
  MACHOP = { 16, 4.5 },
  MACHOKE = { 24, 6 },
  MACHAMP = { 42, 11.0 },
  BELLSPROUT = { 16, 4.5 },
  WEEPINBELL = { 20, 5.25 },
  VICTREEBEL = { 28, 6.75 },
  TENTACOOL = { 20, 5.25 },
  TENTACRUEL = { 24, 6 },
  GEODUDE = { 16, 4.5 },
  GRAVELER = { 24, 6 },
  GOLEM = { 32, 7.5 },
  PONYTA = { 20, 5.25 },
  RAPIDASH = { 40, 10.5 },
  SLOWPOKE = { 34, 9.5 },
  SLOWBRO = { 30, 8.0 },
  MAGNEMITE = { 18, 5.0 },
  MAGNETON = { 20, 5.25 },
  FARFETCHD = { 16, 4.5 },
  DODUO = { 24, 6 },
  DODRIO = { 28, 6.75 },
  SEEL = { 38, 10.0 },
  DEWGONG = { 42, 11.0 },
  GRIMER = { 30, 8.0 },
  MUK = { 46, 12.0 },
  SHELLDER = { 22, 6.0 },
  CLOYSTER = { 30, 7.25 },
  GASTLY = { 20, 5.25 },
  HAUNTER = { 22, 5.5 },
  GENGAR = { 24, 6 },
  ONIX = { 32, 7.5 },
  DROWZEE = { 32, 8.5 },
  HYPNO = { 24, 6 },
  KRABBY = { 12, 3.75 },
  KINGLER = { 46, 12.0 },
  VOLTORB = { 16, 4.5 },
  ELECTRODE = { 24, 6 },
  EXEGGCUTE = { 12, 3.75 },
  EXEGGUTOR = { 38, 10.0 },
  CUBONE = { 12, 3.75 },
  MAROWAK = { 20, 5.25 },
  HITMONLEE = { 26, 7.0 },
  HITMONCHAN = { 24, 6 },
  LICKITUNG = { 24, 6 },
  KOFFING = { 16, 4.5 },
  WEEZING = { 30, 8.0 },
  RHYHORN = { 40, 11.0 },
  RHYDON = { 30, 7.25 },
  CHANSEY = { 20, 5.25 },
  TANGELA = { 20, 5.25 },
  KANGASKHAN = { 32, 7.5 },
  HORSEA = { 12, 3.75 },
  SEADRA = { 20, 5.25 },
  GOLDEEN = { 16, 4.5 },
  SEAKING = { 20, 5.0 },
  STARYU = { 38, 10.0 },
  STARMIE = { 24, 6 },
  MR_MIME = { 30, 8.0 },
  SCYTHER = { 24, 6 },
  JYNX = { 24, 6 },
  ELECTABUZZ = { 36, 9.5 },
  MAGMAR = { 38, 10.0 },
  PINSIR = { 32, 8.5 },
  TAUROS = { 40, 10.5 },
  MAGIKARP = { 32, 8.5 },
  GYARADOS = { 32, 7.5 },
  LAPRAS = { 46, 12.0 },
  DITTO = { 12, 3.75 },
  EEVEE = { 32, 8.5 },
  VAPOREON = { 58, 15.5 },
  JOLTEON = { 38, 10.0 },
  FLAREON = { 20, 5.25 },
  PORYGON = { 20, 5.25 },
  OMANYTE = { 20, 5.5 },
  OMASTAR = { 20, 5.25 },
  KABUTO = { 16, 4.5 },
  KABUTOPS = { 44, 11.5 },
  AERODACTYL = { 42, 11.0 },
  SNORLAX = { 54, 15.0 },
  ARTICUNO = { 28, 6.75 },
  ZAPDOS = { 34, 9.0 },
  MOLTRES = { 28, 6.75 },
  DRATINI = { 16, 4.5 },
  DRAGONAIR = { 20, 5.25 },
  DRAGONITE = { 32, 7.5 },
  MEWTWO = { 40, 10.5 },
  MEW = { 12, 3.75 },
}
for species, size in pairs(baselines) do
  settings.species[species] = {
    baseWidth = size[1], baseHeight = size[2],
    player = {}, enemy = {},
  }
end

-- First authored front-sprite calibration:
-- Bulbasaur's perceived body-mass projection and ground contact are
-- authored in canonical front-sprite pixels for both battle sides.
settings.species.BULBASAUR.baseWidth = 48
settings.species.BULBASAUR.baseHeight = 16
settings.species.BULBASAUR.enemy.anchorMode = "body"
settings.species.BULBASAUR.enemy.offsetX = 0
settings.species.BULBASAUR.enemy.manualAnchorX = 28
settings.species.BULBASAUR.enemy.manualContactY = 39
settings.species.BULBASAUR.player.manualAnchorX = 28
settings.species.BULBASAUR.player.manualContactY = 39
-- Inner-ring dimensions and offsets are fractions of the outer ellipse.
-- Authored in front-sprite orientation; the renderer mirrors X for the player.
settings.species.BULBASAUR.innerRing = {
  widthScale = 34.72 / 48, heightScale = 12.64 / 16,
  offsetX = 2 / 48, offsetY = -1.2 / 16,
}

-- Ivysaur's reviewed front-sprite calibration, shared by both sides.
settings.species.IVYSAUR.baseWidth = 50
settings.species.IVYSAUR.baseHeight = 16
settings.species.IVYSAUR.manualAnchorX = 28
settings.species.IVYSAUR.manualContactY = 45
settings.species.IVYSAUR.innerRing = {
  widthScale = 39 / 50, heightScale = 14 / 16,
  offsetX = 0, offsetY = -1 / 16,
}

-- Venusaur: approved stance with all three layers enlarged 20% after live review.
-- Rotation is authored in front-sprite orientation and mirrored for player.
settings.species.VENUSAUR.baseWidth = 74.4
settings.species.VENUSAUR.baseHeight = 28.8
settings.species.VENUSAUR.manualAnchorX = 29.5
settings.species.VENUSAUR.manualContactY = 46
settings.species.VENUSAUR.rotationDegrees = -8
settings.species.VENUSAUR.middleRing = {
  widthScale = 55 / 62, heightScale = 20 / 24,
}
settings.species.VENUSAUR.innerRing = {
  widthScale = 48 / 62, heightScale = 16 / 24,
}

-- Charmander's approved third preview: 5% smaller, one pixel toward viewer.
settings.species.CHARMANDER.baseWidth = 41.8
settings.species.CHARMANDER.baseHeight = 17.1
settings.species.CHARMANDER.manualAnchorX = 26
settings.species.CHARMANDER.manualContactY = 44
settings.species.CHARMANDER.rotationDegrees = 0
settings.species.CHARMANDER.middleRing = {
  widthScale = 35.15 / 41.8, heightScale = 13.3 / 17.1,
}
settings.species.CHARMANDER.innerRing = {
  widthScale = 28.5 / 41.8, heightScale = 10.45 / 17.1,
}

-- Charmeleon's approved third preview, shared by both battle sides.
settings.species.CHARMELEON.baseWidth = 45.98
settings.species.CHARMELEON.baseHeight = 18.81
settings.species.CHARMELEON.manualAnchorX = 28
settings.species.CHARMELEON.manualContactY = 47
settings.species.CHARMELEON.rotationDegrees = 0
settings.species.CHARMELEON.middleRing = {
  widthScale = 38.665 / 45.98, heightScale = 14.63 / 18.81,
}
settings.species.CHARMELEON.innerRing = {
  widthScale = 31.35 / 45.98, heightScale = 11.495 / 18.81,
}

-- Charizard's approved three-section preview, shared by both battle sides.
settings.species.CHARIZARD.baseWidth = 62.1
settings.species.CHARIZARD.baseHeight = 23
settings.species.CHARIZARD.manualAnchorX = 30
settings.species.CHARIZARD.manualContactY = 53
settings.species.CHARIZARD.rotationDegrees = 0
settings.species.CHARIZARD.middleRing = {
  widthScale = 50.922 / 62.1, heightScale = 18.86 / 23,
}
settings.species.CHARIZARD.innerRing = {
  widthScale = 39.744 / 62.1, heightScale = 14.72 / 23,
}

-- Starter central-body regions; visually calibrate these later.
-- Each species owns its region so editing one cannot change another.
local function bodyRegions(names, left, right)
  for species in names:gmatch("%S+") do
    settings.species[species].bodyRegion = {
      left = left, right = right, top = 0, bottom = 1,
    }
  end
end
bodyRegions([[
BUTTERFREE BEEDRILL ZUBAT GOLBAT VENOMOTH AERODACTYL
ARTICUNO ZAPDOS MOLTRES
]], 0.30, 0.70)
bodyRegions([[
CHARIZARD PIDGEY PIDGEOTTO PIDGEOT SPEAROW FEAROW FARFETCHD
SCYTHER DRAGONITE CHARMANDER CHARMELEON PIKACHU RAICHU
VULPIX NINETALES SLOWPOKE SLOWBRO MEWTWO MEW RATTATA RHYHORN
]], 0.20, 0.80)

-- Keep the central body detector intact and add independent left/right wing
-- measurements outside that body mask. Species can replace these defaults.
local function detectedWings(names)
  for species in names:gmatch("%S+") do
    local body = settings.species[species].bodyRegion
    assert(body, "Wing detection requires bodyRegion for " .. species)
    settings.species[species].wingShadows = {
      {
        region = {
          left = 0, right = body.left,
          top = 0, bottom = 1,
        },
        widthScale = 1, heightScale = 1,
        offsetX = 0, offsetY = 0,
        opacity = 0.025, rotationDegrees = 0,
      },
      {
        region = {
          left = body.right, right = 1,
          top = 0, bottom = 1,
        },
        widthScale = 1, heightScale = 1,
        offsetX = 0, offsetY = 0,
        opacity = 0.025, rotationDegrees = 0,
      },
    }
  end
end

detectedWings([[
CHARIZARD BUTTERFREE BEEDRILL PIDGEY PIDGEOTTO PIDGEOT
SPEAROW FEAROW ZUBAT GOLBAT VENOMOTH FARFETCHD
SCYTHER AERODACTYL ARTICUNO ZAPDOS MOLTRES DRAGONITE
]])

-- Side values override species values; missing values inherit defaults.
-- Keep dimensions positive and scale multipliers nonnegative.
function settings.value(species, side, key)
  local entry = settings.species[species]
  local sideEntry = entry and entry[side]
  local value = sideEntry and sideEntry[key]
  if value == nil and entry then value = entry[key] end
  if value == nil then value = settings.defaults[key] end
  return value
end

function settings.shadowProfile(species, side)
  local mode = settings.value(species, side, "shadowMode")
  if not mode then return nil end
  assert(mode == "manual" or mode == "automatic" or mode == "combined",
    "Invalid shadowMode for " .. tostring(species))
  local shapes = settings.value(species, side, "shadowShapes")
  assert(type(shapes) == "table",
    "Explicit shadowMode requires shadowShapes for " .. tostring(species))
  return { mode = mode, shapes = shapes }
end

function settings.shadowShapeEnabled(profile, shape)
  assert(shape.source == "manual" or shape.source == "detected",
    "Shadow shape requires source = manual or detected")
  return profile.mode == "combined"
    or (profile.mode == "manual" and shape.source == "manual")
    or (profile.mode == "automatic" and shape.source == "detected")
end

function settings.wingShadows(species, side)
  local wings = settings.value(species, side, "wingShadows")
  if not wings or type(wings) ~= "table" then return nil end
  return wings
end

function settings.detectionSizing(species, side, shape, key)
  local contribution = shape and shape.detectionSizing
  if contribution and contribution[key] ~= nil then
    return contribution[key]
  end
  local entry = settings.species[species]
  local sideEntry = entry and entry[side]
  local sideSizing = sideEntry and sideEntry.detectionSizing
  if sideSizing and sideSizing[key] ~= nil then return sideSizing[key] end
  local speciesSizing = entry and entry.detectionSizing
  if speciesSizing and speciesSizing[key] ~= nil then
    return speciesSizing[key]
  end
  return settings.defaults.detectionSizing[key]
end

function settings.automaticBodyValue(species, side, key)
  local entry = settings.species[species]
  local sideEntry = entry and entry[side]
  local sideValues = sideEntry and sideEntry.automaticBody
  if sideValues and sideValues[key] ~= nil then
    return sideValues[key]
  end
  local speciesValues = entry and entry.automaticBody
  if speciesValues and speciesValues[key] ~= nil then
    return speciesValues[key]
  end
  return settings.defaults.automaticBody[key]
end

-- Existing detector sizing policy, shared by measured animation and shapes.
function settings.measuredDimensions(species, side, shape, footprint)
  local function value(key)
    return settings.detectionSizing(species, side, shape, key)
  end
  local width = math.max(
    footprint.contactWidth * value("contactWidthScale"),
    footprint.visibleWidth * value("bodyWidthScale"))
  local low, high = value("minimumWidth"), value("maximumWidthScale")
  if low ~= false then width = math.max(low, width) end
  if high ~= false then width = math.min(footprint.visibleWidth * high, width) end
  local height = width * value("heightScale")
  low, high = value("minimumHeight"), value("maximumHeight")
  if low ~= false then height = math.max(low, height) end
  if high ~= false then height = math.min(high, height) end
  return width, height
end

-- Preserve each approved ellipse. Detection modulates dimensions relative
-- to the first valid settled frame for this owner/region. It never moves
-- the authored center, changes opacity, or reduces the approved baseline.
local function animatedBodyEllipse(x, y, width, height, opacity)
  local shape = {
    source = "manual", detection = true, soft = false,
    x = x, y = y, width = width, height = height,
    rotationDegrees = 0, opacity = opacity,
  }
  shape.animate = function(context)
    local measurement = context.measurement
    if not measurement or not measurement.reference then return end
    local currentWidth, currentHeight = settings.measuredDimensions(
      context.species, context.side, shape, measurement.footprint)
    local referenceWidth, referenceHeight = settings.measuredDimensions(
      context.species, context.side, shape, measurement.reference)
    if referenceWidth <= 0 or referenceHeight <= 0 then return end
    return {
      width = shape.width * math.max(1, currentWidth / referenceWidth),
      height = shape.height * math.max(1, currentHeight / referenceHeight),
    }
  end
  return shape
end

settings.species.CHARMANDER.shadowMode = "combined"
settings.species.CHARMANDER.shadowShapes = {
  animatedBodyEllipse(26, 44, 41.8, 17.1, 0.025),
  animatedBodyEllipse(26, 44, 35.15, 13.3, 0.050),
  animatedBodyEllipse(26, 44, 28.5, 10.45, 0.075),
}

settings.species.CHARMELEON.shadowMode = "combined"
settings.species.CHARMELEON.shadowShapes = {
  animatedBodyEllipse(28, 47, 45.98, 18.81, 0.025),
  animatedBodyEllipse(28, 47, 38.665, 14.63, 0.050),
  animatedBodyEllipse(28, 47, 31.35, 11.495, 0.075),
}

-- Quadruped anchor modes: use body mass center rather than lowest front paws
local quadrupeds = {
  "EEVEE", "VAPOREON", "JOLTEON", "VULPIX", "PERSIAN",
  "ARCANINE", "RHYHORN", "TAUROS", "RATTATA",
}
for _, sp in ipairs(quadrupeds) do
  settings.species[sp].anchorMode = "body"
end

-- Specific alignment / offset calibrations
settings.species.PIDGEY.offsetY = 4
settings.species.BLASTOISE.anchorMode = "body"
settings.species.BLASTOISE.offsetY = -5
settings.species.PIDGEOTTO.offsetX = 2
settings.species.PIDGEOTTO.offsetY = -3
settings.species.PIDGEOT.offsetX = -2
settings.species.PIDGEOT.offsetY = -1
settings.species.RATTATA.offsetX = 4
settings.species.RATTATA.offsetY = -8
settings.species.RAICHU.offsetX = -4
settings.species.SANDSHREW.offsetX = 3
settings.species.SANDSHREW.offsetY = -3
settings.species.NIDORAN_F.anchorMode = "body"
settings.species.NIDORAN_F.offsetX = 8
settings.species.NIDORAN_M.anchorMode = "body"
settings.species.NIDORAN_M.offsetX = 3
settings.species.NIDORAN_M.offsetY = -3
settings.species.VULPIX.offsetY = -3
settings.species.ZUBAT.grounding = "flying"
settings.species.ZUBAT.offsetY = 6
settings.species.ZUBAT.wingShadows = false
settings.species.VENOMOTH.offsetX = -4
settings.species.VENOMOTH.wingShadows = {
  { region = { left = 0.0, right = 0.40, top = 0.1, bottom = 0.9 }, widthScale = 0.9, heightScale = 0.8, opacity = 0.07 },
  { region = { left = 0.60, right = 1.0, top = 0.1, bottom = 0.9 }, widthScale = 0.9, heightScale = 0.8, opacity = 0.07 },
}
settings.species.MANKEY.offsetX = -4
settings.species.PRIMEAPE.offsetX = -4
settings.species.ARCANINE.offsetY = -5
settings.species.MACHOKE.offsetY = -4
settings.species.POLIWRATH.offsetY = -4
settings.species.WIGGLYTUFF.offsetY = -3
settings.species.GOLDUCK.offsetX = 6
settings.species.GOLDUCK.offsetY = -1
settings.species.GOLDUCK.baseWidth = 46
settings.species.GOLDUCK.baseHeight = 11.5
settings.species.ABRA.anchorMode = "body"
settings.species.ABRA.offsetY = -7
settings.species.GEODUDE.wingShadows = false
settings.species.RAPIDASH.offsetY = -4
settings.species.SLOWPOKE.offsetY = -2
settings.species.ALAKAZAM.offsetY = -2
settings.species.SEEL.offsetX = 2
settings.species.SEEL.offsetY = -3
settings.species.DEWGONG.offsetX = -4
settings.species.GRIMER.offsetY = -3
settings.species.MUK.offsetX = 5
settings.species.MUK.offsetY = -8
settings.species.GASTLY.offsetX = -4
settings.species.HAUNTER.offsetY = 5
settings.species.DROWZEE.offsetY = -3
settings.species.KINGLER.offsetY = -3
settings.species.MAGMAR.offsetY = -1
settings.species.RHYHORN.offsetY = -6
settings.species.SEAKING.offsetX = 3
settings.species.SEAKING.offsetY = -3
settings.species.STARYU.offsetX = 3
settings.species.STARYU.offsetY = 3
settings.species.MR_MIME.offsetY = -3
settings.species.TAUROS.offsetX = 5
settings.species.TAUROS.offsetY = -3
settings.species.EEVEE.offsetY = -4
settings.species.VAPOREON.offsetY = -11
settings.species.JOLTEON.offsetY = -5
settings.species.AERODACTYL.offsetX = 4
settings.species.MOLTRES.offsetY = -3
settings.species.MEWTWO.offsetY = -4
settings.species.WEEZING.anchorMode = "body"
settings.species.MAGNEMITE.anchorMode = "body"
settings.species.MR_MIME.anchorMode = "body"
settings.species.PINSIR.offsetX = -1
settings.species.SNORLAX.anchorMode = "body"
settings.species.SNORLAX.offsetX = 6
settings.species.SNORLAX.offsetY = -10

-- Persian: custom bread-loaf composite shadow matching crouching posture and paws
settings.species.PERSIAN.shadowMode = "manual"
settings.species.PERSIAN.shadowShapes = {
  { source = "manual", x = 20, y = 51, width = 26, height = 10.0, opacity = 0.07, rotationDegrees = -6 },
  { source = "manual", x = 33, y = 52, width = 44, height = 13.0, opacity = 0.08, rotationDegrees = -3 },
  { source = "manual", x = 43, y = 54, width = 18, height = 7.0, opacity = 0.065, rotationDegrees = 0 },
}

-- Bellsprout: 2 small foot shadows on same Y axis (left foot grounded, right foot in air lighter)
settings.species.BELLSPROUT.shadowMode = "manual"
settings.species.BELLSPROUT.shadowShapes = {
  { source = "manual", x = 17, y = 47, width = 12, height = 4.0, opacity = 0.075 },
  { source = "manual", x = 44, y = 47, width = 11, height = 3.6, opacity = 0.04 },
}

-- Diglett & Dugtrio: tight custom dirt mound rim shadow
settings.species.DIGLETT.opacityScale = 0
settings.species.DUGTRIO.shadowMode = "manual"
settings.species.DUGTRIO.shadowShapes = {
  { source = "manual", x = 28, y = 47, width = 36, height = 10, opacity = 0.08, rotationDegrees = 0 },
}

-- Exeggcute: distinct shadow underneath each of the 6 eggs
settings.species.EXEGGCUTE.shadowMode = "manual"
settings.species.EXEGGCUTE.shadowShapes = {
  { source = "manual", x = 15, y = 50, width = 14, height = 5.0, opacity = 0.07 },
  { source = "manual", x = 28, y = 51, width = 15, height = 5.2, opacity = 0.07 },
  { source = "manual", x = 43, y = 47, width = 14, height = 4.8, opacity = 0.06 },
  { source = "manual", x = 22, y = 45, width = 12, height = 4.2, opacity = 0.05 },
  { source = "manual", x = 13, y = 43, width = 12, height = 4.2, opacity = 0.05 },
  { source = "manual", x = 37, y = 41, width = 13, height = 4.2, opacity = 0.05 },
}

-- Dual-shadow species: Main grounded foot + 2nd lighter shadow for raised limb
local function dualLimbShadow(species, mainFoot, raisedFoot)
  settings.species[species].shadowMode = "manual"
  settings.species[species].shadowShapes = {
    { source = "manual", x = mainFoot.x, y = mainFoot.y,
      width = mainFoot.w, height = mainFoot.h, opacity = 0.08 },
    { source = "manual", x = raisedFoot.x, y = raisedFoot.y,
      width = raisedFoot.w, height = raisedFoot.h, opacity = 0.035 },
  }
end

dualLimbShadow("RATICATE",
  { x = 36, y = 53, w = 50, h = 14.5 },
  { x = 18, y = 53, w = 30, h = 9.0 })

dualLimbShadow("POLIWAG",
  { x = 32, y = 47, w = 38, h = 11.0 },
  { x = 19, y = 47, w = 22, h = 6.5 })

dualLimbShadow("PRIMEAPE",
  { x = 21, y = 51, w = 38, h = 11.5 },
  { x = 36, y = 50, w = 22, h = 7.5 })

dualLimbShadow("EXEGGUTOR",
  { x = 25, y = 52, w = 40, h = 12.5 },
  { x = 41, y = 51, w = 26, h = 8.5 })

dualLimbShadow("STARYU",
  { x = 31, y = 51, w = 40, h = 12.0 },
  { x = 42, y = 49, w = 24, h = 7.5 })

-- Hitmonlee: Keep automatic body detection enabled + dynamic detected wing/foot shadow for kicking leg
settings.species.HITMONLEE.bodyRegion = { left = 0.15, right = 0.60, top = 0, bottom = 1 }
settings.species.HITMONLEE.wingShadows = {
  {
    region = { left = 0.60, right = 1.0, top = 0.30, bottom = 1 },
    widthScale = 0.8, heightScale = 0.8,
    opacity = 0.07, rotationDegrees = 0,
  },
}

-- Lickitung: body region mask + dynamic wing detection for extended tongue
settings.species.LICKITUNG.bodyRegion = { left = 0.15, right = 0.65, top = 0.20, bottom = 1.0 }
settings.species.LICKITUNG.wingShadows = {
  {
    region = { left = 0.62, right = 1.0, top = 0.35, bottom = 0.95 },
    widthScale = 1.25, heightScale = 0.95,
    opacity = 0.07, rotationDegrees = 0,
  },
}

-- Beedrill manual treatment with active wing detection
settings.species.BEEDRILL.shadowMode = "manual"
settings.species.BEEDRILL.shadowShapes = {
  { source = "manual", x = 36, y = 53, width = 34, height = 9.0, opacity = 0.06, rotationDegrees = 0 },
}
settings.species.BEEDRILL.wingShadows = {
  { region = { left = 0.0, right = 0.35, top = 0.05, bottom = 0.70 }, widthScale = 1.1, heightScale = 0.9, opacity = 0.08 },
  { region = { left = 0.65, right = 1.0, top = 0.05, bottom = 0.70 }, widthScale = 1.1, heightScale = 0.9, opacity = 0.08 },
}

-- Ditto: Dynamic wing/fluid detector only
settings.species.DITTO.shadowMode = "manual"
settings.species.DITTO.shadowShapes = {}
settings.species.DITTO.wingShadows = {
  { region = { left = 0.0, right = 1.0, top = 0.4, bottom = 1.0 }, widthScale = 1.0, heightScale = 1.0, opacity = 0.075 },
}

-- ============================================================================
-- Public Shadow Customization API for Modders & Custom Scenes
-- ============================================================================

--- Register or update a scene-wide shadow configuration.
-- @param sceneId string Backdrop scene identifier (e.g. "custom_space")
-- @param config table Table of scene properties:
--   - enabled: boolean (false suppresses shadows completely in this scene)
--   - color: { r, g, b } tint table (0.0 to 1.0)
--   - opacityScale: number multiplier for shadow opacity
--   - offsetY: number vertical pixel offset
function settings.registerScene(sceneId, config)
  assert(type(sceneId) == "string", "registerScene requires a string sceneId")
  assert(type(config) == "table", "registerScene requires a table config")
  local current = settings.scenes[sceneId] or {}
  for k, v in pairs(config) do current[k] = v end
  settings.scenes[sceneId] = current
  return current
end

--- Get the shadow configuration for a scene, if defined.
-- @param sceneId string|false Backdrop scene identifier
function settings.sceneConfig(sceneId)
  if not sceneId then return nil end
  return settings.scenes[sceneId]
end

--- Register or update a species shadow profile (e.g. for Romhacks or Fakemon).
-- @param species string Uppercase species identifier
-- @param config table Species shadow configuration
function settings.registerSpecies(species, config)
  assert(type(species) == "string", "registerSpecies requires a string species name")
  assert(type(config) == "table", "registerSpecies requires a table config")
  local entry = settings.species[species]
  if not entry then
    entry = {
      baseWidth = config.baseWidth or settings.defaults.baseWidth,
      baseHeight = config.baseHeight or settings.defaults.baseHeight,
      player = {},
      enemy = {},
    }
    settings.species[species] = entry
  end
  for k, v in pairs(config) do
    if k == "player" or k == "enemy" then
      if type(v) == "table" then
        entry[k] = entry[k] or {}
        for sideKey, sideVal in pairs(v) do
          entry[k][sideKey] = sideVal
        end
      end
    else
      entry[k] = v
    end
  end
  return entry
end

--- Set a single shadow property on a species.
-- @param species string Uppercase species identifier
-- @param key string Property name
-- @param value any Property value
function settings.setSpecies(species, key, value)
  assert(type(species) == "string", "setSpecies requires a string species name")
  local entry = settings.species[species]
  if not entry then
    entry = { player = {}, enemy = {} }
    settings.species[species] = entry
  end
  entry[key] = value
end

--- Set a single side-specific shadow property on a species.
-- @param species string Uppercase species identifier
-- @param side string "player" or "enemy"
-- @param key string Property name
-- @param value any Property value
function settings.setSide(species, side, key, value)
  assert(type(species) == "string", "setSide requires a string species name")
  assert(side == "player" or side == "enemy", "side must be 'player' or 'enemy'")
  local entry = settings.species[species]
  if not entry then
    entry = { player = {}, enemy = {} }
    settings.species[species] = entry
  end
  entry[side] = entry[side] or {}
  entry[side][key] = value
end

--- Add a shadow shape to a species' shadowShapes list.
-- @param species string Uppercase species identifier
-- @param shape table Shadow shape definition
-- @param side optional string "player", "enemy", or nil for both
function settings.addShape(species, shape, side)
  assert(type(species) == "string", "addShape requires a string species name")
  assert(type(shape) == "table", "addShape requires a table shape")
  local entry = settings.species[species]
  if not entry then
    entry = { player = {}, enemy = {} }
    settings.species[species] = entry
  end
  if side then
    assert(side == "player" or side == "enemy", "side must be 'player' or 'enemy'")
    entry[side] = entry[side] or {}
    local shapes = entry[side].shadowShapes or {}
    shapes[#shapes + 1] = shape
    entry[side].shadowShapes = shapes
  else
    local shapes = entry.shadowShapes or {}
    shapes[#shapes + 1] = shape
    entry.shadowShapes = shapes
  end
end

return settings
