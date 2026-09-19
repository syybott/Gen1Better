# Gen1Better — Provider and Mod Compatibility

This wiki reference describes the interfaces implemented in the current
Gen1Better source. Feature files and public exports use the BetterBattle,
BetterScenes, BetterPC, BetterBag, and BetterParty names. Existing hook names
and stored settings keys remain unchanged.

## Interface index

| Interface | Kind | Purpose |
| --- | --- | --- |
| `bettermenus.betterbattle_provider` | BetterMenus hook | Declare who owns battle rendering and whether BetterBattle may draw its HUD. |
| `bettermenus.battle_backdrop` | BetterMenus hook | Select a registered 2D scene for a normal or custom-spawn battle. |
| `bettermenus.battle_shadow` | BetterMenus hook | Modify, tint, reposition, or suppress species shadows during battle rendering. |
| `bettermenus.ui_scale` | BetterMenus hook | Opt a custom menu into the user's Menu Scale, or keep native scale. |
| `betterBattle` | Export | Query battle ownership, draw the BetterBattle HUD, inspect backdrop selection. |
| `betterBattle.shadowSettings` | Export | Register custom species shadow profiles and scene-wide shadow adjustments. |
| `betterScenes` | Export | Top-level 16:9 story stage for cutscenes, underlays, and narrative presentation. |
| `isModOptions = true` | Screen marker | Identify a third-party settings screen. |
| `ui.party.submenu` | Engine hook supported by BetterMenus | Add actions to party menus and BetterPC's party-side action list. |
| `betterPC*` methods | BetterPC instance helpers | Operate the active PC screen through its existing controller. |
| `betterParty`, `betterBag`, `betterBagInventoryLimits` | Exports | Access installed screen factories and active inventory limits. |

The `render.*`, `pokemon.sprite`, and `ui.*` engine hooks mentioned below are
engine interfaces, not additional BetterMenus-owned hooks.

> [!NOTE]
> **API Stability & Contract Guarantee**:
> `registerArtistScene`, `registerScene`, `bettermenus.battle_backdrop`, `bettermenus.battle_shadow`, and scene shadow config are public compatibility surfaces that maintain backward compatibility across updates.

## Registering hooks and finding exports

Examples belong in your mod's entry script, where `mod` is the API object supplied
by Gen1Recomp:

```lua
local mod = ...

local function betterBattle()
  local other = mod.find("gen1-better-menus")
  return other and other.exports and other.exports.betterBattle
end
```

`mod.find()` returns nil if BetterMenus is absent, disabled, failed, or has not
loaded yet. Query at use time or after `game.ready`; do not assume another mod's
exports exist during your entry script. Hook registration itself can be done
without looking up BetterMenus. A registered hook has no effect until called.

The equivalent lookup with a live game is:

```lua
local exports = game.mods and game.mods.exports
local menus = exports and exports["gen1-better-menus"]
local api = menus and menus.betterBattle
```

Register with `mod.hooks:wrap(name, callback, priority)`. Priority defaults to 0;
higher numbers run first. `next(...)` invokes the remaining wrappers. Equal
priorities have no guaranteed ordering. Preserve downstream results whenever
your mod does not own the current case.

## 1. Battle-provider ownership

**Hook:** `bettermenus.betterbattle_provider`

```lua
mod.hooks:wrap("bettermenus.betterbattle_provider", function(next, ctx)
  -- Set this marker when your renderer takes ownership of this battle.
  if ctx.battle.myArenaActive then
    return { id = "my-arena", active = true, betterBattle = false }
  end
  return next(ctx)
end)
```

### Context

| Field | Meaning |
| --- | --- |
| `game` | The battle's game instance. |
| `battle` | The live battle. |
| `provider` | Automatically detected provider ID, or nil. |
| `detected` | Whether built-in staged-provider detection found a claim. |
| `defaultClaim` | The detected claim table, or nil. |

### Return contract

| Return | Behavior |
| --- | --- |
| `{ id = "...", active = true, betterBattle = false }` | Your provider owns the battle; BetterBattle's layout yields. |
| `{ id = "...", active = true, betterBattle = true }` | Your provider owns the scene and allows BetterBattle's HUD. |
| `true` | Active claim allowing BetterBattle's HUD; uses the detected ID or a generic ID. Prefer an explicit table. |
| `false` | Keeps the built-in detected claim. **This does not mean “disable provider detection.”** |
| nil, another value, or a table without `active == true` | Normalizes to no claim. This can discard built-in detection; delegate with `next(ctx)` when inactive. |

Only `id`, `active`, and `betterBattle` are retained in the normalized claim.
Ownership is cached per battle's `frame`; establish it before that frame's first
ownership query. Do not use this hook to force the user's BetterBattle setting ON.
When the user selected ON, a claim with `betterBattle = false` makes the effective
mode `mod`. OFF and explicitly selected MOD remain their selected modes.

Any active provider claim suppresses BetterMenus' 2D backdrop, **including a claim
with `betterBattle = true`**. That flag permits the HUD, not the built-in art.

### 3D / voxel renderers

BetterMenus also yields when `renderer.worldOverride ~= nil` during composition,
or when a downstream `render.compose` handler returns true to own composition.
Supply your actual canvas through the engine's `renderer:setWorldOverride(canvas)`;
the renderer rejects non-canvas sentinels and clears ownership each frame.

Use the provider hook as well if your renderer owns HUD/layout behavior. A world
override alone suppresses 2D art but does not automatically claim BetterBattle's
HUD layout. Publish your current frame's canvas before the BetterMenus composition
check. BetterMenus' wrapper runs at priority `math.huge`, calls `next` first, then
checks existing ownership before supplying its own outer canvas.

Built-in staged detection currently recognizes `battle.dramaticShapeShot ~= nil`
or `battle.letterboxWhite == false`. It identifies known companion exports
`DRAMATIC_SHAPE`, `BATTLE_ART_VOXEL_FORK`, and `DRAMALESS_SHAPE`, otherwise using
`detected-3d-battle-provider`. New providers should use the explicit hook instead
of imitating another mod's private fields. Installation alone is not a claim.

## 2. Custom battle backgrounds

**Hook:** `bettermenus.battle_backdrop`

```lua
mod.hooks:wrap("bettermenus.battle_backdrop", function(next, ctx)
  if ctx.kind == "trainer" and ctx.trainerClass == "MY_SPACE_TRAINER" then
    return "custom_spaceship"
  end
  return next(ctx)
end)
```

Replace the example class with your own registered trainer class. The hook runs
synchronously after `BattleState.newWild` / `BattleState.newTrainer` constructs
the battle, before the wrapper returns. Selection is cached for that battle,
not recomputed while drawing. Battles that predate installation are captured
lazily when first drawn.

Context fields: `game`, `battle`, `mapId`, `x`, `y`, `tileset`, `surfing`, `fishing`,
`kind`, `species`, `trainerClass`, `partyIndex`, and `defaultSceneId`. Unavailable
fields may be nil. `defaultSceneId` can be false for intentionally plain scenes.
These describe construction-time context; later Safari/ghost setup can occur
after construction. `battle.kaHooked` preserves `opts.hooked` before selection.

| Return | Behavior |
| --- | --- |
| Registered scene-ID string | Override automatic location matching. |
| `false` | Request the original plain background for this battle. |
| `next(ctx)` | Delegate through the remaining hook chain. |
| Final nil | Use automatic matching. |
| Unknown string or other type | Log once for that value and use automatic matching. |

### Synchronous custom wild spawn

```lua
local sceneForSpawn

mod.hooks:wrap("bettermenus.battle_backdrop", function(next, ctx)
  if sceneForSpawn then return sceneForSpawn end
  return next(ctx)
end)

local function spawnSpaceMew(world)
  local previous = sceneForSpawn
  sceneForSpawn = "custom_space"
  local ok, started, err = pcall(world.startWildBattle, world, "MEW", 30)
  sceneForSpawn = previous
  if not ok then error(started, 0) end
  return started, err
end
```

Here `world` is a Gen1Recomp `WorldAPI` instance. For a deferred spawn, set and
restore the context inside the callback that actually constructs the battle.
Setting a flag only around the earlier dialogue/scheduling call is insufficient.

All 63 supplied scenes are selectable, including `custom_desert`,
`custom_mountain_snow`, `custom_snow_grass`, `custom_space`, and `custom_spaceship`.
See [the full scene registry and location rules](Battle-Backdrops.md#registered-scenes).

### Registering new custom 320×180 scenes

See the [Artist Backdrop Pack Quickstart](Artist-Backdrop-Packs.md) for a complete,
beginner-friendly guide to building standalone backdrop mods.

Other mods can register their own custom 320×180 battle backdrops using the unified
`betterBattle.backdrop.registerArtistScene` or direct `registerScene`:

```lua
local function registerCustomBackdrops()
  local other = mod.find("gen1-better-menus")
  local api = other and other.exports and other.exports.betterBattle
  if not api or not api.backdrop then return end

  -- One-stop registration (image + optional shadow style):
  api.backdrop.registerArtistScene("my_custom_arena", {
    image = "assets/arena_320.png",
    shadows = {
      color = { 0.45, 0.32, 0.18 }, -- warm earth tint
      opacityScale = 0.85,
    },
  }, mod)

  -- Or direct image registration:
  -- api.backdrop.registerScene("my_custom_arena", "assets/arena_320.png", mod)
end
```

Images must be strictly 320×180 pixels. See [Verifying backdrops for 1080p and 4K](Battle-Backdrops.md#verifying-backdrops-for-1080p-and-4k-python)
for the Python validation script.

Alternatively, `bettermenus.battle_backdrop` can return a dynamic table containing
an instantiated LÖVE `Image`:

```lua
mod.hooks:wrap("bettermenus.battle_backdrop", function(next, ctx)
  if ctx.mapId == "MY_CUSTOM_MAP" then
    return { id = "my_custom_arena", image = myLoveImage }
  end
  return next(ctx)
end)
```

### Mid-battle scene changes (`setScene` & `refresh`)

To change the active backdrop mid-battle (for multi-phase boss fights, scripted floor collapses, or dynamic weather shifts):

```lua
-- Shift active scene with transition and elevation lerp
local ok, sceneId = api.backdrop.setScene(battle, "boss_ruins", {
  transition = "crossfade", -- "crossfade" (default), "flash", or "cut"
  duration = 0.5,           -- seconds
  geometry = "lerp",        -- "immediate" (default), "lerp", or "after"
})
-- Returns: true, sceneId | false, "unknown-scene" | false, "no-record" | false, "invalid-battle"

-- Or re-evaluate the battle_backdrop hook if encounter state changed
local ok, sceneId, status = api.backdrop.refresh(battle, { transition = "crossfade" })
-- Returns: true, sceneId, "changed" | true, sceneId, "unchanged" | false, err
```

Normal scene selection is cached. `refresh()` is an explicit API escape hatch that re-runs selection against the captured context.

#### Geometry timing vs. scene identity
Scene identity switches immediately (`diagnostics(battle).sceneId` updates to target scene on call), while visible geometry moves according to `opts.geometry`:
- `immediate`: Target offsets apply immediately on frame 0 (default).
- `lerp`: Smoothly glides `playerOffsetY` and `enemyOffsetY` across transition duration ($0.0 \to 1.0$). Essential for cliffs, platforms, and sunken trenches to prevent battlers from snapping in midair during crossfades.
- `after`: Retains origin offsets until transition completes ($100\%$), then switches.

Query presentation-time values using:
```lua
local playerOffsetY, enemyOffsetY = api.backdrop.effectiveGroundOffsets(battle)
```
Diagnostics also reports `effectivePlayerOffsetY` and `effectiveEnemyOffsetY` alongside target `playerOffsetY` and `enemyOffsetY`.

Selection does not enable BetterBattle or override an external renderer.
The 320×180 art retains its full colors; front sprites are required for
BetterBattle to display properly. No mon-paper backing is added.

## 3. Battle shadows and custom scenes

BetterBattle and BetterScenes share a unified, decoupled Actor Shadow Engine
(`schemaVersion = 1`, `profileVersion = 1`) that renders soft, feathered contact
shadows beneath combatants and story cutscene actors across all 320×180 scenes.
Shadows automatically accommodate grounding, dynamic wings, manual limb ellipses,
stance tilts, and sprite scaling.

Modders can manipulate shadows dynamically in combat using the `bettermenus.battle_shadow`
hook, register scene-wide adjustments via `betterBattle.shadowSettings.registerScene`,
or register custom species using `betterBattle.shadowSettings.registerSpecies`. Registered
species profiles are immediately accessible to both BetterBattle and BetterScenes.

### Hook: `bettermenus.battle_shadow`

Dispatched per shadow shape during the backdrop composition pass before drawing.

```lua
mod.hooks:wrap("bettermenus.battle_shadow", function(next, ctx)
  -- Suppress shadows for underground or airborne states:
  if ctx.flying and ctx.battle.flyingTurn then
    return false
  end

  -- Tint shadows blue when fighting over water:
  if ctx.sceneId == "env_ocean_water" or ctx.sceneId == "env_lake_water" then
    ctx.color = { 0.05, 0.15, 0.30 }
    ctx.alpha = ctx.alpha * 0.7
    return ctx
  end

  return next(ctx)
end)
```

#### Context fields

| Field | Meaning |
| --- | --- |
| `game` | The battle's live game instance. |
| `battle` | The live `BattleState` object. |
| `sceneId` | Selected backdrop ID (e.g. `"custom_space"`), or `false` for plain field. |
| `side` | `"player"` or `"enemy"`. |
| `species` | Pokémon species identifier string (e.g. `"CHARIZARD"`). |
| `battler` | Active battler state (`battle[side]`). |
| `flying` | Whether the Pokémon is currently airborne/flying. |
| `kind` | Shape type: `"configured"` (manual/authored ellipse), `"wing"` (detected wing), or `"footprint"` (automatic body fallback). |
| `shapeIndex` | 1-based index of this shape within its profile or wing list. |
| `x`, `y` | Canvas coordinates of shadow center in virtual screen pixels. |
| `width`, `height` | Pixel dimensions of the outer ellipse. |
| `alpha` | Effective opacity multiplier (0.0 to 1.0). |
| `color` | Current RGB tint `{ r, g, b }` (0.0 to 1.0), or nil for standard black. |
| `rotationDegrees` | Ellipse rotation angle in degrees. |
| `innerRing`, `middleRing` | Feathering ring configurations, or false/nil. |

#### Return contract

| Return | Behavior |
| --- | --- |
| `false` | Cancel and suppress this shadow shape completely. |
| Context table or override table | Apply modified shadow properties (`x`, `y`, `width`, `height`, `alpha`, `color`, `rotationDegrees`, `innerRing`, `middleRing`). |
| `next(ctx)` or nil | Delegate through remaining hook wrappers or keep default drawing. |

### Declarative scene shadows: `registerScene`

Use `betterBattle.shadowSettings.registerScene(sceneId, config)` to apply persistent
adjustments for custom battle backgrounds:

```lua
local function setupSceneShadows()
  local other = mod.find("gen1-better-menus")
  local shadowSettings = other and other.exports and other.exports.betterBattle
      and other.exports.betterBattle.shadowSettings
  if not shadowSettings then return end

  -- Space / void: completely disable floor shadows:
  shadowSettings.registerScene("custom_space", {
    enabled = false,
  })

  -- Dark cave: faint purple-tinted shadows:
  shadowSettings.registerScene("env_cave", {
    color = { 0.10, 0.05, 0.15 },
    opacityScale = 0.60,
  })
end
```

### Species registration: `registerSpecies`

Romhacks and Pokémon expansion mods can register shadow dimensions, grounding,
body regions, and wing detectors for custom species or Fakemon:

```lua
local function registerCustomSpeciesShadows()
  local other = mod.find("gen1-better-menus")
  local shadowSettings = other and other.exports and other.exports.betterBattle
      and other.exports.betterBattle.shadowSettings
  if not shadowSettings then return end

  -- Grounded custom Pokémon with baseline dimensions:
  shadowSettings.registerSpecies("MY_FAKEMON", {
    baseWidth = 26,
    baseHeight = 7.0,
    grounding = "grounded",
    manualAnchorX = 28,
    manualContactY = 48,
  })

  -- Flying custom Pokémon with dynamic wing detection:
  shadowSettings.registerSpecies("MY_BIRD", {
    baseWidth = 20,
    baseHeight = 5.5,
    grounding = "flying",
    bodyRegion = { left = 0.25, right = 0.75, top = 0.1, bottom = 0.9 },
    wingShadows = {
      { region = { left = 0, right = 0.25, top = 0, bottom = 1 }, opacity = 0.05 },
      { region = { left = 0.75, right = 1.0, top = 0, bottom = 1 }, opacity = 0.05 },
    },
  })
end
```

Helper methods on `betterBattle.shadowSettings`:
- `registerSpecies(species, config)`: Register or merge species configuration.
- `registerScene(sceneId, config)`: Register or merge scene shadow configuration.
- `setSpecies(species, key, value)`: Set a species property.
- `setSide(species, side, key, value)`: Set a side-specific property (`player` or `enemy`).
- `addShape(species, shape, side)`: Append a manual shadow shape to `shadowShapes`.

#### Unified Shadow Configuration Schema
| Property | Type | Description |
| :--- | :--- | :--- |
| `baseWidth` | number | Baseline ellipse width in virtual pixels. |
| `baseHeight` | number | Baseline ellipse height in virtual pixels. |
| `widthScale` / `heightScale` | number | Scaling multipliers applied to base dimensions (default `1.0`). |
| `offsetX` / `offsetY` | number | Positional offsets relative to ground contact point. |
| `rotationDegrees` | number | Stance tilt angle in degrees. |
| `opacity` / `alpha` | number | Shadow opacity (0.0 to 1.0). |
| `color` | table | Normalized RGB `{ r, g, b }` for environment tinting. |
| `grounding` | string | Stance behavior: `"grounded"`, `"hovering"`, `"floating"`, `"flying"`. |
| `anchorMode` | string | Anchor resolution: `"feet"`, `"manual"`, or `"auto"`. |
| `manualAnchorX` / `manualContactY` | number | Explicit sprite pixel coordinates for contact anchor. |
| `bodyRegion` | table | Normalized sub-rectangle `{ left, right, top, bottom }` for measurement. |
| `wingShadows` | table | Array of wing detector zones `{ region = { left, right, top, bottom }, opacity }`. |
| `shadowShapes` | table | Array of explicit custom shapes (`{ width, height, offsetX, offsetY, alpha, ... }`). |
| `innerRing` / `middleRing` | table | Concentric inner feathering ring specifications. |
| `soft` | boolean | Enables cosine multi-ring soft edge feathering (default `true`). |

## 4. Custom-menu scaling

**Hook:** `bettermenus.ui_scale`

```lua
mod.hooks:wrap("bettermenus.ui_scale", function(next, ctx)
  if ctx.kind == "menu" and ctx.state and ctx.state.myCustomScreen then
    return true -- use the user's selected Menu Scale
  end
  return next(ctx)
end)
```

The current dispatch is **menu-only**. Context contains `kind = "menu"`, `game`,
`state` (top screen), `states` (stack), `requestedFactor`, and `defaultEnabled`.
Return exactly true to opt into the requested factor, false to use native scale,
or `next(ctx)` to preserve the downstream decision. Numeric factors are not
accepted; any result other than true yields native scale.

This hook runs when Menu Scale is below 100%, an overworld exists below a menu,
and no battle is in the stack. It cannot enable scaling for a title screen or
an in-battle menu outside those dispatch conditions. The renderer also enforces
its minimum UI scale, so the requested factor is not a pixel-size guarantee.

Stock supported menus opt in by default. BetterPC, BetterBag, BetterParty,
registered mod-owned screens, and unknown screen types default to native scale.
There is no current detached-battle-HUD dispatch for this hook. BetterBattle's
own panels use their separate internal half-size target and pixel snapping.

## 5. BetterBattle exports

Resolve `game.mods.exports["gen1-better-menus"].betterBattle` with nil checks, or
use the `mod.find` helper above. Call these functions with dot syntax:

| Function | Result / usage |
| --- | --- |
| `enabled(battle)` | Whether the effective BetterBattle mode is ON with WIDE and Extended settings. Does not itself check `worldOverride`. |
| `modeFor(battle)` | Effective `on`, `off`, or `mod` mode. |
| `activeProvider(battle)` | Normalized cached provider claim, or nil. Treat the returned table as read-only. |
| `drawLayer(battle, bottomVisible)` | Draw BetterBattle's detached HUD and register its anchors. Requires the appropriate HUD pass and eligible topmost battle. |
| `expPixels(battle)` | Current animated XP-display pixel count, floored and nonnegative. |
| `shadowSettings` | Shadow configuration table exposing `registerSpecies`, `registerScene`, `setSpecies`, `setSide`, `addShape`, and species profiles. |
| `backdrop.sceneIds()` | Sorted copy of all registered scene IDs (including custom registered scenes). |
| `backdrop.registerArtistScene(id, config, sourceMod)` | One-stop registration helper for custom 320×180 backdrops and their shadow styles. |
| `backdrop.registerScene(id, imageOrPath, sourceMod)` | Direct registration helper for custom 320×180 backdrops. |
| `backdrop.resolve(context)` | Pure automatic resolver: returns scene ID or false, plus a reason string. Does not invoke the custom hook. |
| `backdrop.diagnostics(battle)` | Detached diagnostic table, or nil before context was captured. |

`drawLayer` defaults `bottomVisible` from `battle:bottomUIVisible()` when omitted.
A provider that requests `betterBattle = true` and owns a separate draw path can
integrate it like this:

```lua
local function drawProviderHud(game, battle)
  local api = betterBattle() -- helper defined above
  if not api or not api.enabled(battle) then return false end
  local renderer = game.renderer
  local previous = renderer:beginBattleHUDPass()
  local ok, result = pcall(api.drawLayer, battle)
  renderer:endBattleHUDPass(previous)
  if not ok then error(result, 0) end
  return result
end
```

Call this at your provider's HUD-rendering point, once per frame. If you already
have a HUD pass open, call `api.drawLayer` within it instead of opening a nested
pass. Do not call it again when the normal BetterBattle draw path has already
drawn the layer. It supplies BetterBattle's own layout; it is not an arbitrary
provider-HUD geometry API.

Backdrop diagnostics includes `sceneId`, `reason`, `assetPath`, `rendered`,
`inactiveReason`, `fieldTransparent`, viewport dimensions, and captured encounter
fields. Read it after composition to inspect presentation. `rendered = false`
can be correct for disabled BetterBattle, an external provider, nickname blanking,
an opaque screen, an intentionally plain scene, or an unavailable image.
Changing the returned diagnostic table does not change scene selection.

## 6. BetterScenes story stage exports

`mod.exports.betterScenes` provides a standalone 16:9 widescreen story stage (320×180 native integer-scaled pixels) decoupled from combat states. It allows modders and story authors to create narrative cutscenes, character staging, comic dialogue bubbles, camera effects, atmospheric weather, and seamless transitions into battle.

```lua
local mod = ...
local betterScenes = mod.find("gen1-better-menus").exports.betterScenes

-- Register custom 320x180 story backdrop
betterScenes.registerScene("ship_intro", { path = "assets/ship_320.png", underlay = "black" }, mod)

-- Display story scene with animated transition
betterScenes.show("ship_intro", { transition = "crossfade", duration = 0.5 })

-- Present active underlay only (e.g. blackout or psychic void without an image)
betterScenes.show(false, { underlay = "black" })

-- Cleanly end cutscene and return screen ownership to the game
betterScenes.hide({ transition = "crossfade", duration = 0.35 })
```

### Complete Public API Reference

#### 1. Scene Presentation & Underlays

| Function | Returns | Description |
| :--- | :--- | :--- |
| `registerScene(id, config, sourceMod)` | `true, id` or `false, err` | Register a 320×180 story scene. Reserved prefixes (`gen1_*`, `better_*`, `system_*`) are protected. |
| `show(idOrFalse, opts)` | `true, id` or `false, err` | Transition into a registered scene (`string`) or plain underlay (`false`). Transitions: `"cut"`, `"crossfade"`, `"flash"`. |
| `hide(opts)` | `true, nil` or `false, err` | Transition toward inactive, clearing presentation and unhooking renderer. |
| `current()` | `string`, `false`, or `nil` | Current scene ID (`string` = image, `false` = active plain underlay, `nil` = inactive). |
| `isActive()` | `boolean` | `true` when BetterScenes is actively presenting an image, underlay, actor, sequence, or effect. |

#### 2. Actor Staging & Relative Anchors

Theatrical cast layer positioned in 320×180 stage coordinates. The actor base point (`x`, `y`) represents the actor's feet / bottom-center. Relative anchors (`head`, `mouth`, `top`) automatically scale and mirror with the actor. Staged actors can automatically inherit species shadow profiles or render custom soft floor contact shadows.

| Function | Returns | Description |
| :--- | :--- | :--- |
| `setActor(slot, config, opts)` | `true, slot` or `false, err` | Stage an actor in preset slot (`"left"`, `"center"`, `"right"`) or custom named slot with explicit coordinates (`x`, `y`). Supports `path`, `species`, `shadow` (`true`, `false`, or schema table), and relative `anchors`. Transitions: `"cut"`, `"fade"`, `"slide"`. |
| `clearActor(slot, opts)` | `true, slot` or `false, err` | Remove actor from stage with optional exit transition (`fade`, `slide`). |
| `clearActors(opts)` | `true, count` | Remove all active actors from stage. |
| `getActor(slot)` | `table` or `nil` | Query actor state (`x`, `y`, `scale`, `mirror`, `transitionActive`, `exiting`, `shadowState`). |
| `getActorAnchor(slot, anchorName)` | `x, y` or `nil, err` | Resolve live stage coordinates for anchor (`"mouth"`, `"head"`, `"top"`). |

```lua
-- Stage trainer on the left with custom shadow, and Charizard on the right with calibrated species shadow:
betterScenes.setActor("left", {
  path = "assets/red.png",
  mirror = false,
  shadow = { baseWidth = 24, baseHeight = 6, offsetY = 1 },
}, { transition = "fade", duration = 0.3 })

betterScenes.setActor("right", {
  path = "assets/charizard.png",
  species = "CHARIZARD",
  shadow = true,
  scale = 1.0,
}, { transition = "slide", duration = 0.4 })
```

#### 3. Comic Dialogue Bubbles, Subtitles & Emotes

Anchored dialogue bubbles dynamically track speaker mouth coordinates live, clamping within stage bounds while the tail points directly to the speaker.

| Function | Returns | Description |
| :--- | :--- | :--- |
| `showBubble(speaker, text, opts)` | `true, bubbleId` or `false, err` | Show dialogue bubble. `speaker` can be actor slot string, `{ x, y }`, or `"narrator"`. Styles: `"speech"`, `"thought"`, `"shout"`. Transitions: `"cut"`, `"fade"`, `"pop"`. |
| `hideBubble(opts)` | `true, nil` or `false, err` | Hide active dialogue bubble. |
| `getBubble()` | `table` or `nil` | Query active bubble layout, text, lines, tail coordinates, and state. |
| `setSubtitle(text, opts)` | `true, nil` or `false, err` | Display widescreen cinematic letterbox subtitle (`bar = true`, `position = "bottom"|"top"|"center"`). |
| `clearSubtitle(opts)` | `true, nil` or `false, err` | Clear active subtitle with optional fade transition. |
| `getSubtitle()` | `table` or `nil` | Query active subtitle state. |
| `showEmote(target, emoteType, opts)` | `true, emoteKey` or `false, err` | Display floating animated bounce emote over actor or coordinate (`"exclamation"`, `"question"`, `"heart"`, `"anger"`, `"sweat"`, `"dots"`, `"music"`). |
| `clearEmote(target)` | `true, count` | Clear active emote by target, or all emotes if target is nil. |
| `getEmotes()` | `table` | Query all active emotes. |

```lua
-- Oak speaks with an anchored comic bubble
betterScenes.showBubble("left", "Welcome to the world of Pokémon!", { style = "speech" })

-- Mew reacts with an emote puff
betterScenes.showEmote("right", "exclamation", { duration = 1.5 })
```

#### 4. Declarative Story Sequence Runner

Choreograph multi-step cutscenes using a linear step queue. Sequences handle pauses, player interaction, skipping, and clean resource scoping.

| Function | Returns | Description |
| :--- | :--- | :--- |
| `playSequence(steps, opts)` | `true, seqId` or `false, err` | Run array of timeline steps. Options: `skippable = true/false`, `cleanup = true`, `onComplete = fn`, `onAbort = fn`. |
| `stopSequence(opts)` | `true, nil` | Halts active sequence immediately and triggers `onAbort`. If `cleanup = true`, clears sequence-owned elements. |
| `skipSequence()` | `true, nil` or `false, err` | Fast-forwards remaining instant steps to land safely on intended final scene state. |
| `advanceSequence()` | `true, nextStep` or `false, err` | Unblocks player input barriers (`waitInput`) or fast-forwards timed waits. |
| `getSequence()` | `table` or `nil` | Query sequence progress (`stepIndex`, `totalSteps`, `waitingInput`, `currentAction`, `skippable`). |

**Supported Sequence Actions**:
- `show` / `hide`: Background scenes and transitions (supports `wait = true`).
- `actor` / `clearActor` / `clearActors`: Cast staging (supports `wait = true`).
- `bubble` / `hideBubble`: Anchored dialogue bubbles.
- `subtitle` / `clearSubtitle`: Cinematic letterbox narration.
- `emote` / `clearEmote`: Floating reaction emotes.
- `shake` / `stopShake`: Screen camera trauma (supports `wait = true`).
- `flash`: Momentary combat strobe pulse (supports `wait = true`).
- `tint` / `clearTint`: Ambient color grading (supports `wait = true`).
- `vignette` / `clearVignette`: Restomod framing masks (supports `wait = true`).
- `weather` / `clearWeather`: Atmospheric particle simulation.
- `battle`: Decoupled combat transition (halts progression until battle concludes).
- `wait`: Timed pause `{ action = "wait", duration = 0.5 }`.
- `waitInput`: Player button prompt barrier `{ action = "waitInput" }`.
- `call`: Custom script callback `{ action = "call", fn = function(api, seq) ... end }` (pcall-guarded).

```lua
betterScenes.playSequence({
  { action = "show", scene = "dock_scene", transition = "crossfade", duration = 0.5, wait = true },
  { action = "actor", slot = "left", path = "assets/oak.png", transition = "fade", wait = true },
  { action = "bubble", speaker = "left", text = "Are you ready for your journey?" },
  { action = "waitInput" },
  { action = "hideBubble" },
  { action = "weather", type = "rain", count = 25 },
  { action = "shake", intensity = 4, duration = 0.5, wait = true },
}, {
  skippable = true,
  cleanup = true,
})
```

#### 5. 320×180 Stage FX & Camera Dynamics

Atmospheric effects run natively in 320×180 integer space before scaling, preserving crisp pixel-art restomod visuals without subpixel blur.

| Function | Returns | Description |
| :--- | :--- | :--- |
| `shakeScreen(opts)` | `true, nil` or `false, err` | Trigger deterministic camera shake. Options: `intensity`, `duration`, `direction` (`"both"`, `"horizontal"`, `"vertical"`), `pixelSnap = true`, `shakeUI = false`. |
| `stopShake()` | `true, nil` | Immediately cancel active camera shake. |
| `getShake()` | `table` | Query shake active state, offsets (`offsetX`, `offsetY`), and decay progress. |
| `setTint(colorOrPreset, opts)` | `true, nil` or `false, err` | Apply full-stage ambient color wash. Presets: `"sunset"`, `"night"`, `"cave"`, `"underwater"`, `"poison"`, `"sepia"`, or custom `{ r, g, b, a }`. Supports smooth fade `duration`. |
| `clearTint(opts)` | `true, nil` or `false, err` | Clear ambient tint back to neutral with optional fade duration. |
| `getTint()` | `table` | Query active tint color, alpha, and transition progress. |
| `flashScreen(colorOrPreset, opts)` | `true, nil` or `false, err` | High-impact momentary pulse. Modes: `"out"` (instant peak, decays to 0), `"inout"` (fades in, peaks at midpoint, decays to 0). Scope: `"stage"` or `"full"`. |
| `stopFlash()` | `true, nil` | Immediately clear active flash. |
| `getFlash()` | `table` | Query flash alpha and status. |
| `setVignette(style, opts)` | `true, nil` or `false, err` | Apply framing mask: `"letterbox"` (top/bottom bars), `"spotlight"` (circle focus on coordinate/slot), `"dither"` (restomod Bayer border fade). |
| `clearVignette(opts)` | `true, nil` or `false, err` | Clear vignette with optional fade duration. |
| `getVignette()` | `table` | Query vignette style and alpha. |
| `setWeather(weatherType, opts)` | `true, nil` or `false, err` | Simulate atmospheric retro particles (`"rain"`, `"snow"`, `"leaves"`, `"cherry_blossom"`, `"embers"`, `"dust"`). Supports isolated deterministic `seed`. |
| `clearWeather(opts)` | `true, nil` or `false, err` | Clear weather with optional fade duration. |
| `getWeather()` | `table` | Query weather active state, particle count, and particle positions. |

#### 6. Decoupled Battle Handoff

Seamlessly transition from a narrative cutscene into active combat (`BetterBattle`) using a decoupled, data-only token protocol.

| Function | Returns | Description |
| :--- | :--- | :--- |
| `prepareBattleHandoff(opts)` | `true, token` or `false, err` | Generate serializable handoff token and begin pre-battle transition (`"swirl"`, `"blinds"`, `"mosaic"`, `"flash"`, `"cut"`). Snapshots atmosphere (`tint`, `weather`) into combat. |
| `getBattleHandoff()` | `table` or `nil` | Query active or latest handoff token (`id`, `state`, `storySceneId`, `battleBackdropId`, `battleType`, `transitionProgress`, `outcome`). |
| `cancelBattleHandoff()` | `true, nil` or `false, err` | Safely cancel handoff prior to combat handoff lock (`state = "cancelled"`). |
| `resumeFromBattle(resultToken)` | `true, outcome` or `false, err` | Consume combat outcome (`"win"`, `"lose"`, `"flee"`, `"draw"`). Dispatches author callbacks and unblocks paused sequence. |

```lua
-- Trigger battle handoff from cutscene
betterScenes.prepareBattleHandoff({
  battleType = "boss",
  trainerId = "giovanni",
  battleBackdropId = "boss_giovanni_gym",
  transition = "swirl",
  duration = 0.8,
  onHandoff = function(token)
    -- BetterBattle consumes the token and starts combat
  end,
  onWin = function(api, result)
    -- Play victory cutscene upon return
    api.showBubble("left", "You have bested me...", { style = "speech" })
  end,
})

-- When combat concludes, BetterBattle resumes the story:
betterScenes.resumeFromBattle({
  handoffId = "bh_1",
  outcome = "win",
})
```

#### 7. Diagnostics

`betterScenes.diagnostics()` returns a detached, comprehensive snapshot of stage activity:
- `active`: Boolean indicating if any visual element, transition, sequence, or effect is live.
- `state`: `"inactive"`, `"plain"`, or `"image"`.
- `sceneId`, `underlay`, `assetPath`: Active scene and underlay configuration.
- `actors`: Table of all currently staged actors (including coordinates, scaling, mirroring, and `shadowState` telemetry: `mode`, `profileId`, `profileVersion`, `schemaVersion`, `shapes`).
- `bubble`, `subtitle`, `emotes`: Active dialogue and reaction elements.
- `sequence`: Active sequence status and step indices.
- `shake`, `tint`, `flash`, `vignette`, `weather`: Active camera and atmosphere FX.
- `battleHandoff`: Active or last battle handoff token state.

## 7. Options-screen marker

```lua
local OptionsScreen = { isModOptions = true }

function OptionsScreen.new(game)
  return { game = game, isModOptions = true, rows = {}, index = 1 }
end
```

Add the marker to your actual factory or instance, retaining its existing draw
and input methods. BetterMenus propagates the factory marker for screens built
through `Screens.build` / `Screens.push`; manually pushed instances should carry
the marker themselves. This identifies options-style layout behavior. It is not
an automatic opt-in to Menu Scale. No BetterMenus dependency is required.

See [Mod Options Screen Compatibility](Mod-Options-Screen-Compatibility.md).

## 8. Party actions and BetterPC helpers

BetterParty retains the engine PartyMenu controller. BetterPC also calls the
engine's `ui.party.submenu` hook when its **party-side** action list opens:

```lua
mod.hooks:wrap("ui.party.submenu", function(next, game, items, mon, ctx)
  local entries = next(game, items, mon, ctx)
  if ctx and ctx.pc and mon then
    entries[#entries + 1] = {
      label = "MY ACTION",
      onSelect = function(selectedMon, liveGame)
        -- Open your screen or run your action here.
      end,
    }
  end
  return entries
end)
```

BetterPC supplies `{ battle = false, overworld = game.overworld, storage = true,
pc = true }`. Return the action table. A custom callback entry should omit
`action`; BetterPC calls `onSelect(mon, game)` for such entries. The hook is not
called for box-side selections. BetterPC keeps MOVE first, removes entries whose
`action` is `summary`, and appends CANCEL after the hook.

The active BetterPC instance (`state.betterPCUI == true`) exposes colon methods:

| Method | Purpose |
| --- | --- |
| `state:betterPCSelected()` | Get the current selection through the PC controller. |
| `state:betterPCPickOrDrop()` | Pick up or place the selection. |
| `state:betterPCSwitchBox(delta)` | Switch boxes through the existing controller. |
| `state:betterPCQuickTransfer()` | Transfer between party and box. |
| `state:betterPCRequestRelease()` | Open the existing release confirmation flow. |
| `state:betterPCLayoutInfo()` | Get the current computed layout. |

Resolve the active BetterPC screen before calling these methods.

Other exports are `betterParty` and `betterBag` screen factories, plus
`betterBagInventoryLimits` with `slots` and `stack`. Prefer the engine's registered
`PartyMenu` / `BagMenu` screens for ordinary navigation so settings-based routing
continues to apply. BetterPC is routed through the registered `BoxMenu`; there is
no top-level `betterPC` export in this source.

## Existing provider bridges and limits

BetterMenus installs compatibility bridges for Gender Mod and staged providers
at `game.ready`. Staged bridges discover provider exports with
`api.lib.require("OverworldBattle")` and a `hudTexture` function. These are
implementation-specific adapters, not a general public HUD-texture hook. A new
provider should use the ownership hook and exported HUD API above instead of
assuming a private bridge will match its geometry or palette layout.

The provider claim controls layout ownership; it does not promise universal
recoloring of arbitrary third-party textures. Known provider bridges can apply
BetterMenus palette coverage separately even when BetterBattle's layout yields.

BetterMenus also wraps engine hooks including `render.compose`, `render.letterbox`,
`render.hud`, `render.zones`, `battle.overlay`, `screen.render_visible`,
`ui.options.rows`, and `ui.start_menu.items`. Preserve their engine contracts and
chain with `next`; they are not interchangeable with the BetterMenus hooks.

## Compatibility testing

When testing compatibility with other mods, verify behavior across standard in-game states:
check your provider active and inactive, BetterBattle ON and OFF, fishing versus
surfing, nickname entry, and menu overlays. An inactive 2D backdrop while your 3D
provider owns the frame is expected. Use the [Diagnostics API](Battle-Backdrops.md#diagnostics)
to inspect the active scene state and verify whether the backdrop is drawn.
