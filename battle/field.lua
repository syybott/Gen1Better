-- Internal BetterBattle module. Detached sprite/animation capture, private layer caches, and scoped draw restoration.
-- Loaded once by better_battle_hud.lua; not a public consumer API.
return function(deps)
  local M = {}
  local Footprint = assert(deps.footprint)
  local Geometry = assert(deps.geometry)
  local Messages = assert(deps.messages)
  local PaletteFX = require("src.render.PaletteFX")
  local WideBattle = require("src.battle.WideBattle")
  local betterBattleApi = deps.betterBattleApi
  local effects = deps.effects
  local mod = deps.mod

  local spriteLayerCache = setmetatable({}, { __mode = "k" })

  -- Keep native sprite drawing intact, then scale its finished layer through
  -- the same placement function used by the panels.
  function M.withBetterBattleField(battle, draw)
    local geometry = Geometry.resolveBattleGeometry(battle)
    local renderer = battle.game.renderer
    renderer.gen1BetterBattleFieldGeometry = geometry
    renderer.gen1BetterBattleSpriteLayers = nil
    renderer.gen1BetterBattleScreenAnim = nil
    local cached = spriteLayerCache[battle]
    if not cached then
      cached = {}
      spriteLayerCache[battle] = cached
    end

    local function layerFor(key)
      if not cached[key] then
        local canvas =
          love.graphics.newCanvas(WideBattle.WIDTH, WideBattle.HEIGHT, { dpiscale = 1 })
        canvas:setFilter("nearest", "nearest")
        cached[key] = {
          canvas = canvas,
          x = 0,
          y = 0,
          w = WideBattle.WIDTH,
          h = WideBattle.HEIGHT,
        }
      end
      return cached[key]
    end

    local function captureSprite(side, callback, footprintState)
      local g = love.graphics
      local previous = g.getCanvas()
      if previous ~= renderer.canvas then return callback() end

      -- Preserve the field already painted before the first Pokémon.
      -- Subsequent native drawing remains above the detached sprites.
      if not renderer.gen1BetterBattleSpriteLayers then
        local field = layerFor("field")
        field.nativeField = true
        field.zones = WideBattle.zones()
        g.push("all")
        g.setCanvas(field.canvas)
        g.origin()
        g.setScissor()
        g.setShader()
        g.clear(0, 0, 0, 0)
        g.setColor(1, 1, 1, 1)
        g.setBlendMode("replace", "premultiplied")
        g.draw(previous)
        g.setCanvas(previous)
        g.clear(0, 0, 0, 0)
        g.pop()
        renderer.gen1BetterBattleSpriteLayers = { field }
      end

      if Messages.escapeMessageVisible(battle) then return end

      local layer = layerFor(side)
      layer.betterBattleSide = side
      layer.nativeBlit = geometry.nativeBlit
      layer.gen1BetterMenusPlacement = {
        owner = geometry.owner,
        coordinateSpace = geometry.coordinateSpace,
        edge = geometry.coordinateSpace == "field" and "field-sprite" or "native-sprite",
        scale = geometry.spriteScale,
        fieldX = side == "player" and geometry.playerX or geometry.enemyX,
        fieldY = side == "player" and geometry.playerGround or geometry.enemyGround,
        playerGround = geometry.playerGround,
        enemyGround = geometry.enemyGround,
        playerShift = geometry.playerShift,
        enemyShift = geometry.enemyShift,
        nativeBlit = geometry.nativeBlit,
        nativeAnim = geometry.nativeAnim,
        nativeClip = geometry.nativeClip,
        stock = geometry.stock,
      }
      layer.zones = WideBattle.zones()
      local marks = PaletteFX.trueColorRects("ui")
      local first = #marks + 1
      local settings = betterBattleApi.shadowSettings
      local shadowProfile = settings and settings.shadowProfile(footprintState.species, side)
      local wingSettings = settings and settings.wingShadows(footprintState.species, side)
      local manualAnchorX = settings
        and settings.value(footprintState.species, side, "manualAnchorX")
      local manualContactY = settings
        and settings.value(footprintState.species, side, "manualContactY")
      local sourceSpace = settings
        and settings.value(footprintState.species, side, "sourceSpace")
      if type(sourceSpace) ~= "table" then
        sourceSpace = settings and settings.profileSpace or {}
      end
      local manualOrigin
      local spriteTransform
      local function measureFootprint(region)
        return Footprint.inProfileSpace(
          Footprint.measureShadowFootprint(layer.canvas, region),
          spriteTransform)
      end
      local previousDrawBattlerPic = rawget(battle, "drawBattlerPic")
      local originalDrawBattlerPic = battle.drawBattlerPic
      local manualWrapperInstalled = false

      -- Keep shadow calculations in their authored reference units.
      -- Capture every Pokémon's input size and actual drawing transform.
      if type(originalDrawBattlerPic) == "function" then
        battle.drawBattlerPic = function(self, battler, x, y, scale, ...)
          if battler == self[side] and not spriteTransform then
            local image = battler.sprite and self:picImage(battler.sprite)
            if image and type(x) == "number" and type(y) == "number" then
              local spriteScale = tonumber(scale) or 1
              local imageWidth, imageHeight = image:getWidth(), image:getHeight()
              local profileWidth = tonumber(sourceSpace.width) or imageWidth
              local profileHeight = tonumber(sourceSpace.height) or imageHeight
              assert(profileWidth > 0 and profileWidth < math.huge
                and profileHeight > 0 and profileHeight < math.huge,
                "Shadow sourceSpace dimensions must be finite and positive")
              local px, py = g.transformPoint(x, y)
              local qx, qy = g.transformPoint(x + spriteScale, y + spriteScale)
              spriteTransform = {
                x = px,
                y = py,
                scaleX = (qx - px) * imageWidth / profileWidth,
                scaleY = (qy - py) * imageHeight / profileHeight,
                profileWidth = profileWidth,
                profileHeight = profileHeight,
              }
              if type(manualAnchorX) == "number" and type(manualContactY) == "number" then
                local spriteX = side == "player" and profileWidth - manualAnchorX or manualAnchorX
                manualOrigin = { centerX = spriteX, contactY = manualContactY }
              end
            end
          end
          return originalDrawBattlerPic(self, battler, x, y, scale, ...)
        end
        manualWrapperInstalled = true
      end
      g.push("all")
      g.setCanvas(layer.canvas)
      local clipX, clipY, clipW, clipH = g.getScissor()
      g.setScissor()
      g.clear(0, 0, 0, 0)
      if clipX then g.setScissor(clipX, clipY, clipW, clipH) end
      local ok, result = pcall(callback)
      if manualWrapperInstalled then
        if previousDrawBattlerPic == nil then
          battle.drawBattlerPic = nil
        else
          battle.drawBattlerPic = previousDrawBattlerPic
        end
      end
      g.setCanvas(previous)
      g.pop()
      for i = first, #marks do
        if PaletteFX.honorsTrueColor() then layer.zones[#layer.zones + 1] = marks[i] end
      end
      for i = #marks, first, -1 do
        marks[i] = nil
      end
      if not ok then error(result, 0) end

      local previousTransform = layer.shadowTransform
      local revision = settings and settings.revision
      if spriteTransform and (
        layer.shadowProfileRevision ~= revision
        or (previousTransform and (
          previousTransform.scaleX ~= spriteTransform.scaleX
          or previousTransform.scaleY ~= spriteTransform.scaleY
          or previousTransform.profileWidth ~= spriteTransform.profileWidth
          or previousTransform.profileHeight ~= spriteTransform.profileHeight
        ))
      ) then
        layer.detectedWingShadowState = nil
        layer.authoredShadowState = nil
        layer.shadowFootprints = nil
        layer.shadowFootprint, layer.shadowAnchor = nil, nil
      end
      layer.shadowTransform = spriteTransform or previousTransform
      layer.shadowProfileRevision = revision

      layer.detectedWingShadows = nil
      if wingSettings and spriteTransform then
        local state = layer.detectedWingShadowState
        if
          not state
          or state.owner ~= footprintState.owner
          or state.species ~= footprintState.species
          or state.shift ~= footprintState.shift
          or state.settings ~= wingSettings
        then
          state = {
            owner = footprintState.owner,
            species = footprintState.species,
            shift = footprintState.shift,
            settings = wingSettings,
            regions = {},
          }
          layer.detectedWingShadowState = state
        end
        state.transform = spriteTransform
        local measurements = {}
        for index, wing in ipairs(wingSettings) do
          local region = wing.region
          assert(type(region) == "table", "Wing shadow requires a detection region")
          if side == "player" then
            region = {
              left = 1 - region.right,
              right = 1 - region.left,
              top = region.top,
              bottom = region.bottom,
            }
          end
          local entry = state.regions[index]
          if not entry or entry.settings ~= wing then
            entry = {
              settings = wing,
              frames = setmetatable({}, { __mode = "k" }),
            }
            state.regions[index] = entry
          end
          if footprintState.settled and footprintState.sprite then
            local measured = entry.frames[footprintState.sprite]
            if measured == nil then
              measured = measureFootprint(region) or false
              entry.frames[footprintState.sprite] = measured
            end
            if measured then entry.last = measured end
          end
          measurements[index] = entry.last
        end
        layer.detectedWingShadows = {
          settings = wingSettings,
          measurements = measurements,
          transform = state.transform,
        }
      else
        layer.detectedWingShadowState = nil
      end

      layer.authoredShadow = nil
      if shadowProfile then
        local state = layer.authoredShadowState
        if
          not state
          or state.owner ~= footprintState.owner
          or state.species ~= footprintState.species
          or state.shift ~= footprintState.shift
          or state.mode ~= shadowProfile.mode
          or state.shapes ~= shadowProfile.shapes
        then
          state = {
            owner = footprintState.owner,
            species = footprintState.species,
            shift = footprintState.shift,
            mode = shadowProfile.mode,
            shapes = shadowProfile.shapes,
            regions = {},
          }
          layer.authoredShadowState = state
        end
        if spriteTransform then
          local previousTransform = state.transform
          if
            previousTransform
            and (
              previousTransform.x ~= spriteTransform.x
              or previousTransform.y ~= spriteTransform.y
              or previousTransform.scaleX ~= spriteTransform.scaleX
              or previousTransform.scaleY ~= spriteTransform.scaleY
            )
          then
            state.regions = {}
          end
          state.transform = spriteTransform
        end
        local measurements, activeRegions = {}, {}
        for index, shape in ipairs(shadowProfile.shapes) do
          if
            settings.shadowShapeEnabled(shadowProfile, shape)
            and (
              shape.source == "detected"
              or (shadowProfile.mode == "combined" and shape.detection)
            )
          then
            local region = shape.region
            if region == nil then
              region = settings.value(footprintState.species, side, "bodyRegion")
            end
            local key = "full"
            if region then
              key = table.concat({
                region.left,
                region.right,
                region.top,
                region.bottom,
              }, ":")
              if side == "player" then
                region = {
                  left = 1 - region.right,
                  right = 1 - region.left,
                  top = region.top,
                  bottom = region.bottom,
                }
              end
            end
            activeRegions[key] = true
            local entry = state.regions[key]
            if not entry then
              entry = { frames = setmetatable({}, { __mode = "k" }) }
              state.regions[key] = entry
            end
            if footprintState.settled and footprintState.sprite and state.transform then
              local measured = entry.frames[footprintState.sprite]
              if measured == nil then
                measured = measureFootprint(region) or false
                entry.frames[footprintState.sprite] = measured
              end
              if measured then
                entry.last = measured
                entry.reference = entry.reference or measured
                entry.anchor = entry.anchor
                  or {
                    centerX = measured.centerX,
                    contactY = measured.contactY,
                  }
              end
            end
            if entry.last then
              measurements[index] = {
                footprint = entry.last,
                anchor = entry.anchor,
                reference = entry.reference,
              }
            end
          end
        end
        for key in pairs(state.regions) do
          if not activeRegions[key] then state.regions[key] = nil end
        end
        layer.authoredShadow = {
          profile = shadowProfile,
          transform = state.transform,
          measurements = measurements,
          sprite = footprintState.sprite,
          frame = battle.frame,
        }
        layer.shadowFootprint, layer.shadowAnchor = nil, nil
        local layers = renderer.gen1BetterBattleSpriteLayers
        layers[#layers + 1] = layer
        return result
      end
      layer.authoredShadowState = nil
      local sprite = footprintState.sprite
      local region = settings and settings.value(footprintState.species, side, "bodyRegion")
      local anchorMode = settings and settings.value(footprintState.species, side, "anchorMode")
      local anchorX = settings and settings.value(footprintState.species, side, "anchorX")
      local left, right = region and region.left or 0, region and region.right or 1
      local top, bottom = region and region.top or 0, region and region.bottom or 1
      if
        not layer.shadowFootprints
        or layer.shadowFootprintShift ~= footprintState.shift
        or layer.shadowOwner ~= footprintState.owner
        or layer.shadowSpecies ~= footprintState.species
        or layer.shadowLeft ~= left
        or layer.shadowRight ~= right
        or layer.shadowTop ~= top
        or layer.shadowBottom ~= bottom
        or layer.shadowAnchorMode ~= anchorMode
        or layer.shadowAnchorX ~= anchorX
        or layer.shadowManualAnchorX ~= manualAnchorX
        or layer.shadowManualContactY ~= manualContactY
      then
        layer.shadowFootprints = setmetatable({}, { __mode = "k" })
        layer.shadowFootprint, layer.shadowAnchor = nil, nil
        layer.shadowFootprintShift = footprintState.shift
        layer.shadowOwner, layer.shadowSpecies = footprintState.owner, footprintState.species
        layer.shadowLeft, layer.shadowRight = left, right
        layer.shadowTop, layer.shadowBottom = top, bottom
        layer.shadowAnchorMode, layer.shadowAnchorX = anchorMode, anchorX
        layer.shadowManualAnchorX = manualAnchorX
        layer.shadowManualContactY = manualContactY
      end

      -- Frame changes retain the last valid footprint until a replacement
      -- is available. Never measure transient slides, shakes or effects.
      local hasManualAnchor = type(manualAnchorX) == "number" and type(manualContactY) == "number"
      if hasManualAnchor and manualOrigin and footprintState.settled then
        -- Keep the measured fields deliberately neutral: authored baseWidth
        -- and baseHeight control the ellipse instead of frame alpha bounds.
        local footprint = {
          automatic = false,
          centerX = manualOrigin.centerX,
          contactCenterX = manualOrigin.centerX,
          bodyCenterX = manualOrigin.centerX,
          contactY = manualOrigin.contactY,
          contactWidth = 1,
          visibleWidth = 1,
          visibleLeft = manualOrigin.centerX,
          visibleRight = manualOrigin.centerX,
        }
        layer.shadowFootprint = footprint
        -- Keep the authored body projection stable while frames animate.
        layer.shadowAnchor = layer.shadowAnchor
          or {
            centerX = manualOrigin.centerX,
            contactY = manualOrigin.contactY,
          }
      elseif not hasManualAnchor and sprite and footprintState.settled then
        local footprint = layer.shadowFootprints[sprite]
        if not footprint then
          footprint = measureFootprint(region)
          layer.shadowFootprints[sprite] = footprint
        end
        if footprint then
          layer.shadowFootprint = footprint
          local minimumCoverage =
            settings.automaticBodyValue(footprintState.species, side, "minimumContactCoverage")
          local maximumOffset =
            settings.automaticBodyValue(footprintState.species, side, "maximumContactOffset")
          local centerX, contactReliable
          local shadowEngine = betterBattleApi and betterBattleApi.shadowEngine
          if shadowEngine and type(shadowEngine.resolveAnchor) == "function" then
            local resolvedAnchor = shadowEngine.resolveAnchor(footprint, {
              anchorMode = anchorMode,
              anchorX = anchorX,
              minimumContactCoverage = minimumCoverage,
              maximumContactOffset = maximumOffset,
            })
            centerX = resolvedAnchor.centerX
            contactReliable = resolvedAnchor.contactReliable
          else
            local fullWidth = footprint.fullVisibleWidth or footprint.visibleWidth
            local fullHeight = footprint.fullVisibleHeight or footprint.visibleHeight or 1
            local boundsCenter = footprint.boundsCenterX or footprint.centerX
            centerX = footprint.contactCenterX or footprint.centerX
            local contactCoverage = footprint.contactWidth / math.max(1, fullWidth)
            local contactOffset = math.abs(centerX - boundsCenter) / math.max(1, fullWidth)
            contactReliable = contactCoverage >= minimumCoverage and contactOffset <= maximumOffset
            if anchorMode == "body" then
              centerX = footprint.bodyCenterX or centerX
            elseif not contactReliable then
              if fullWidth >= fullHeight then
                centerX = boundsCenter
              else
                centerX = footprint.bodyCenterX or footprint.opaqueCentroidX or boundsCenter
              end
            end
            if type(anchorX) == "number" then
              centerX = footprint.visibleLeft
                + (footprint.visibleRight - footprint.visibleLeft) * anchorX
            end
          end

          -- Keep the chosen body anchor stable; animation changes
          -- dimensions and contact rows without making the shadow jump.
          layer.shadowAnchor = layer.shadowAnchor
            or {
              centerX = centerX,
              contactY = footprint.contactY,
            }
          footprint.contactReliable = contactReliable
        end
      end

      local layers = renderer.gen1BetterBattleSpriteLayers
      layers[#layers + 1] = layer
      return result
    end
    local originalPics, originalAnim = battle.drawPicsLayer, battle.drawAnimLayer
    local ownPics, ownAnim = rawget(battle, "drawPicsLayer"), rawget(battle, "drawAnimLayer")
    local function shifted(dy, callback)
      if geometry and geometry.nativeBlit and dy == 0 then return callback() end
      local g = love.graphics
      local marks = PaletteFX.trueColorRects("ui")
      local first = #marks + 1
      local x, _, w = g.getScissor()
      g.push("all")
      -- Native WideBattle clips at FIELD_BOTTOM. The compact layout uses
      -- that formerly reserved message area for the Pokémon's lower rows.
      if not (geometry and geometry.nativeClip) then g.setScissor(x or 0, 0, w or 304, 144) end
      if dy ~= 0 then g.translate(0, dy) end
      local ok, result = pcall(callback)
      g.pop()
      if dy ~= 0 then
        for i = first, #marks do
          marks[i].y = marks[i].y + dy
        end
      end
      if not ok then error(result, 0) end
      return result
    end
    battle.drawPicsLayer = function(self, slide, sx, sy, side, skipMenuClip)
      if Messages.escapeMessageVisible(self) then
        return captureSprite(side, function() end)
      end
      local dy = side == "player" and geometry.playerShift or geometry.enemyShift
      local function drawSide()
        return shifted(
          dy,
          function() return originalPics(self, slide, sx, sy, side, skipMenuClip) end
        )
      end
      local pokemonSide = (
        side == "player"
        and not self.showPlayerBack
        and not self.safari
        and not self.demo
      ) or (side == "enemy" and not self.showEnemyTrainer)
      if pokemonSide then
        local battler = self[side]
        return captureSprite(side, drawSide, {
          sprite = battler and battler.sprite,
          owner = battler and battler.mon,
          species = battler and battler.mon and battler.mon.species,
          shift = dy,
          settled = (slide or 0) == 0
            and (sx or 0) == 0
            and (sy or 0) == 0
            and not self.animPlaying
            and not self.sendingOut
            and not self.enemySendingOut,
        })
      end
      return drawSide()
    end
    battle.drawAnimLayer = function(self, colorized)
      if Messages.escapeMessageVisible(self) then return end
      if self.fieldCleared then return end
      local enhanced = mod.options:get("better_animations") ~= false
      local function drawAnimation()
        if enhanced then return effects.draw(self) end
        return originalAnim(self, colorized)
      end
      local step = self.animPlaying
        and self.animPlayer
        and self.animPlayer.steps[self.animPlayer.stepIndex]
      if
        enhanced
        and geometry
        and effects.isScreenWide(self.animPlayer, step)
      then
        renderer.gen1BetterBattleScreenAnim = { battle = self, step = step }
        return
      end
      if geometry and geometry.nativeAnim then return drawAnimation() end
      local sprites = self.lockedBall
      if self.animPlaying and self.animPlayer then
        local step = self.animPlayer.steps[self.animPlayer.stepIndex]
        sprites = step and step.sprites
      end
      local minX, maxX = math.huge, -math.huge
      for _, sprite in ipairs(sprites or {}) do
        minX, maxX = math.min(minX, sprite.x - 8), math.max(maxX, sprite.x)
      end
      local t = minX < math.huge and math.max(0, math.min(1, ((minX + maxX) / 2 - 40) / 80)) or 0
      local dy = math.floor(geometry.playerShift * (1 - t) + geometry.enemyShift * t + 0.5)
      return shifted(dy, drawAnimation)
    end
    local ok, result = pcall(draw)
    battle.drawPicsLayer, battle.drawAnimLayer = ownPics, ownAnim
    if not ok then
      renderer.gen1BetterBattleSpriteLayers = nil
      error(result, 0)
    end
    return result
  end

  return M
end
