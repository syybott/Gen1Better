# Gen1Better — Provider and Mod Compatibility

This wiki reference describes the interfaces implemented in the current
Gen1Better source. Feature files and public exports use the BetterBattle,
BetterScenes, BetterPC, BetterBag, and BetterParty names. The mod ID `gen1-better-menus` and `bettermenus.*` hook names remain the integration identifiers. Current settings include the replacement battle toggles; see [all settings](https://github.com/syybott/Gen1Better/wiki/Extra-Features).

## Interface index

| Interface | Kind | Purpose |
| --- | --- | --- |
| `bettermenus.betterbattle_provider` | Gen1Better hook | Declare who owns battle rendering and whether BetterBattle may draw its HUD. |
| `bettermenus.battle_backdrop` | Gen1Better hook | Select a registered 2D scene for a normal or custom-spawn battle. |
| `bettermenus.battle_shadow` | Gen1Better hook | Modify, tint, reposition, or suppress species shadows during battle rendering. |
| `bettermenus.battle_geometry` | Gen1Better hook | Supply custom actor presentation geometry, ground lines, and coordinate space. |
| `bettermenus.ui_scale` | Gen1Better hook | Opt a custom menu into the user's Menu Scale, or keep native scale. |
| `betterBattle` | Export | Query battle ownership, draw the BetterBattle HUD, inspect backdrop selection. |
| `betterBattle.registerBattleGeometryProvider` | Export | Register/update a provider by ID; true on success, false for missing ID or non-function callback. |
| `betterBattle.getBattleGeometry` | Export | Query the resolved battle presentation geometry for a battle instance. |
| `betterBattle.shadowSettings` | Export | Register custom species shadow profiles and scene-wide shadow adjustments. |
| `betterScenes` | Export | Top-level 16:9 story stage for cutscenes, underlays, and narrative presentation. |
| `isModOptions = true` | Screen marker | Identify a third-party settings screen. |
| `ui.party.submenu` | Engine hook supported by Gen1Better | Add actions to party menus and BetterPC's party-side action list. |
| `betterPC*` methods | BetterPC instance helpers | Operate the active PC screen through its existing controller. |
| `betterParty`, `betterPokedex`, `betterModManager`, `betterOptions`, `betterBag` | Exports | Screen factories. Prefer registered screen navigation so options-based routing applies. |
| `betterBagInventoryLimits` | Export | Current `slots` and `stack` limits. |

The `render.*`, `pokemon.sprite`, and `ui.*` engine hooks mentioned below are
engine interfaces, not additional Gen1Better-owned hooks.

> [!NOTE]
> **Public integration surfaces**: Use the documented exports, hooks, and screen markers below when building a consuming mod. Check availability before calling an export.

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

`mod.find()` returns nil if Gen1Better is absent, disabled, failed, or has not
loaded yet. Query at use time or after `game.ready`; do not assume another mod's
exports exist during your entry script. Hook registration itself can be done
without looking up Gen1Better. A registered hook has no effect until called.

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
When BetterBattle UI is ON, a claim with `betterBattle = false` makes the effective mode `mod`. OFF stays off. MOD is an automatic provider mode, not a current selectable setting.

Any active provider claim suppresses Gen1Better' 2D backdrop, **including a claim
with `betterBattle = true`**. That flag permits the HUD, not the built-in art.

### 3D / voxel renderers

Gen1Better also yields when `renderer.worldOverride ~= nil` during composition,
or when a downstream `render.compose` handler returns true to own composition.
Supply your actual canvas through the engine's `renderer:setWorldOverride(canvas)`;
the renderer rejects non-canvas sentinels and clears ownership each frame.

Use the provider hook as well if your renderer owns HUD/layout behavior. A world
override alone suppresses 2D art but does not automatically claim BetterBattle's
HUD layout. Publish your current frame's canvas before the Gen1Better composition
check. Gen1Better' wrapper runs at priority `math.huge`, calls `next` first, then
checks existing ownership before supplying its own outer canvas.

For new providers, declare ownership through `bettermenus.betterbattle_provider`. Installing a provider alone is not a claim; report whether your renderer actually owns the current battle. Preserve downstream detection with `next(ctx)` when inactive.

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
See [the full scene registry and location rules](https://github.com/syybott/Gen1Better/wiki/Battle-Backdrops#registered-scenes).

### Registering new custom 320×180 scenes

See the [Artist Backdrop Pack Quickstart](https://github.com/syybott/Gen1Better/wiki/Artist-Backdrop-Packs) for a complete,
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

`registerArtistScene` resolves all supported shadow-schema and subsystem-availability
failures before the backdrop is registered, so invalid artist configuration cannot
produce a partial scene registration. On expected registration or validation rejection,
it returns `false, err` without mutating backdrop or shadow registries. Handled failure
reasons include:
- `"reserved"` / `"collision"`: Backdrop ID collision guards.
- `"shadow_subsystem_unavailable"`: Shadow config requested but shadow engine uninitialized.
- `"invalid_shadows"` / `"invalid_color"` / `"invalid_opacity_scale"` / `"invalid_offset_y"` / `"invalid_player_offset_y"` / `"invalid_enemy_offset_y"` / `"invalid_enabled"`: Schema validation failures.


`registerScene(id, imageOrPath, sourceMod)` returns `true, id` or expected `false, "reserved" / "collision"` failures. It asserts on invalid IDs/types and on incorrect dimensions of an already loaded Image. String paths are loaded lazily through the owning mod's assets; factories are evaluated lazily. Therefore registration success does not validate a path/factory image's dimensions in advance. Pass your own `mod` for asset resolution and ownership; omission uses Gen1Better.

`registerArtistScene` performs supported shadow validation before image registration. It returns the documented expected-error tuples, but invalid configuration types or a loaded Image with incorrect dimensions can still raise errors. This is not a blanket no-exception contract.

Images must be strictly 320×180 pixels. See [Verifying backdrops for 1080p and 4K](https://github.com/syybott/Gen1Better/wiki/Battle-Backdrops#verifying-backdrops-for-1080p-and-4k-python)
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

Normal scene selection is cached. `refresh()` re-runs the hook against the original captured encounter context; it does not recapture map/position fields. Inspect `ctx.battle` for live state when needed.

#### Geometry timing vs. scene identity
Scene identity switches immediately (`diagnostics(battle).sceneId` updates to target scene on call), while visible geometry moves according to `opts.geometry`:
- `immediate`: Target offsets apply immediately on frame 0 (default).
- `lerp`: Smoothly glides `playerOffsetY` and `enemyOffsetY` across transition duration ($0.0 \to 1.0$). Essential for cliffs, platforms, and sunken trenches to prevent battlers from snapping in midair during crossfades.
- `after`: Retains origin offsets until transition completes ($100\%$), then switches.

Query presentation-time values using:
```lua
local playerOffsetY, enemyOffsetY = api.backdrop.effectiveGroundOffsets(battle)
```
Diagnostics also reports `effectivePlayerOffsetY` and `effectiveEnemyOffsetY` alongside target `playerOffsetY` and `enemyOffsetY`. The built-in BetterBattle UI geometry incorporates these offsets. Custom geometry providers must incorporate them into their own ground lines/shifts to keep sprites and shadows aligned.

Selection does not enable BetterBattle or override an external renderer.
The 320×180 art retains its full colors; front sprites are required for
BetterBattle to display properly. No mon-paper backing is added.

## 3. Battle shadows and custom scenes

The Actor Shadow Engine (`schemaVersion = 2`, `profileVersion = 1`) is a
general-purpose shadow system used by BetterBattle and BetterScenes. Its built-in
151 Pokémon profiles are optional preset data rather than a requirement: arbitrary
images and objects can use automatic measurement and instance shadow settings
without having a species identity.

Both consumers use the same footprint measurement, anchor selection, profile
resolution, authored and detected shape evaluation, dynamic callbacks, source-space
conversion, mirroring, scaling, and rendering primitives. BetterBattle still owns
battle ground placement and its final shadow hook; BetterScenes still owns actor
placement, poses, variants, transitions, and draw order.

Modders can manipulate shadows dynamically in combat using the `bettermenus.battle_shadow`
hook, register scene-wide adjustments via `betterBattle.shadowSettings.registerScene`,
or register custom species using `betterBattle.shadowSettings.registerSpecies`.

Species-level values contain tuning shared by every presentation. The optional
`player`, `enemy`, and `scene` tables contain presentation-context-specific
exceptions. Context tables are siblings and never inherit from one another. A
single value resolves from the active context to the species-level value and then
to the global default; an instance override, where supported by the consumer, has
the highest priority. The `scene` table is normally omitted and should be added
only when a species needs cutscene-specific calibration.

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
| `alpha` | Effective rendering gain; can exceed 1. This is not a final opacity value. |
| `color` | Current RGB tint `{ r, g, b }` (0.0 to 1.0), or nil for standard black. |
| `rotationDegrees` | Ellipse rotation angle in degrees. |
| `innerRing`, `middleRing` | Feathering ring configurations, or false/nil. |

#### Return contract

| Return | Behavior |
| --- | --- |
| `false` | Cancel and suppress this shadow shape completely. |
| Context table or override table | Apply modified shadow properties (`x`, `y`, `width`, `height`, `alpha`, `color`, `rotationDegrees`, `innerRing`, `middleRing`). |
| `next(ctx)` or nil | Delegate through remaining hook wrappers or keep default drawing. |

The detected wing rendering branch does not apply inner/middle ring overrides. Color and ring fallbacks mean false/nil are not general-purpose clearing values; return false to suppress a whole shape.

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

### Schema validation & normalization: `validateSceneConfig`

Part of the public v1 API, `betterBattle.shadowSettings.validateSceneConfig(config)` is the
pure validator and normalizer used by `registerArtistScene`. Modders and authoring tools can
invoke it directly to validate and normalize scene shadow tables before submission:

```lua
local ok, normalizedOrErr = shadowSettings.validateSceneConfig({
  enabled = true,
  color = { r = "0.4", g = "0.3", b = "0.2" },
  opacityScale = "0.85",
  offsetY = "-2",
  customExtension = "persisted",
})
-- ok: boolean
-- normalizedOrErr: table on success (numbers coerced, color mapped to dual array/table access), or error string on failure
```

**Authoring rules enforced by `validateSceneConfig`**:
- **Permissive representation**: Valid numeric strings (e.g. `"0.85"`, `"-2"`) are coerced to Lua numbers for `opacityScale`, `offsetY`, `playerOffsetY`, `enemyOffsetY`, and color components (`[1..3]` and `.r/.g/.b`).
- **Strict meaning**:
  - `enabled`: Must be a strict boolean (`true` or `false`). Strings like `"false"` or integers `0` are rejected.
  - `color`: Components must normalize to finite numbers in $[0.0, 1.0]$. Values outside this range are rejected (not clamped).
  - `opacityScale`: Must normalize to a finite number $\ge 0$.
  - `offsetY`, `playerOffsetY`, `enemyOffsetY`: Must normalize to finite numbers.
  - Rejection: `NaN`, `math.huge`, `-math.huge`, and unparseable strings return `false, err`.
- **Dual color access**: The normalized color table provides dual access `{ r, g, b, r = r, g = g, b = b }`.
- **Extension metadata preserved**: Unrecognized keys are passed through untouched to support third-party hook metadata.

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

Direct `shadowSettings.registerScene` merges configuration and returns the live scene entry; it does **not** call `validateSceneConfig`. Validate untrusted input first, check `ok`, then register the normalized table. `sceneConfig(id)` returns the live entry or nil.

Helper methods on `betterBattle.shadowSettings`:
- `registerSpecies(species, config)`: Register or merge species configuration; returns its live entry.
- `registerScene(sceneId, config)`: Merge scene configuration without validation; returns its live entry.
- `setSpecies(species, key, value)`: Set a species property; returns nil.
- `setContext(species, context, key, value)`: Set a context-specific property (`player`, `enemy`, or `scene`); returns nil and asserts on an invalid context.
- `addShape(species, shape, context)`: Append a shadow shape at species level or within a presentation context. Returns nil.

For species-profile values, resolution is:

```text
instance override
-> current context override
-> species-level value
-> global default
```

`player`, `enemy`, and `scene` overrides do not cross-inherit.

#### Unified Shadow Configuration Schema

The shared engine uses `schemaVersion = 2` and `profileVersion = 1`. Species presets use `profileSpace = { width = 56, height = 56, originX = 28, originY = 56 }`. Defaults apply after instance/context/species resolution.

| Property | Contract / default |
| --- | --- |
| `baseWidth` / `baseHeight` | Baseline virtual dimensions, defaults 12 / 3.75. Automatic measurement can adjust effective sizing. |
| `widthScale` / `heightScale` / `opacityScale` | Multipliers, default 1. |
| `offsetX` / `offsetY` / `rotationDegrees` | Contact-relative offsets and rotation, default 0. |
| `opacity` / `alpha` | Optional gain aliases: soft rendering normalizes by 0.075. Prefer opacityScale; these are not a final combined-opacity guarantee. |
| `color` | RGB tint; nil uses black. |
| `grounding` | Default grounded; flying selects special flight behavior. Hovering/floating have no distinct implemented behavior. |
| `anchorMode` / `anchorX` | contact (default) or body; optional normalized horizontal anchor. |
| `manualAnchorX` / `manualContactY` | Source-space manual coordinates; defaults false. |
| `sourceSpace` | Optional `{ width, height, originX, originY }` for authored data. Actor instances otherwise use their effective image dimensions. |
| `shapeSpace` | origin for actor-relative instance shapes (default for instances), source for source-image coordinates (default for species profiles). |
| `bodyRegion` | Normalized opaque-bounds sub-rectangle `{ left, right, top, bottom }`. A context bodyRegion replaces the species region as a whole. |
| `wingShadows` | Detector zones containing region and optional opacity. |
| `shadowMode` | Species-profile selection: manual, automatic, combined, or false for legacy resolution. An instance shadowMode does not select the species filter. |
| `shadowShapes` | Authored/detected shapes: x/y, width/height, offsets, opacity/alpha, opacityScale, rotationDegrees, color, rings, soft, and optional `animate(context)` overrides. Declare source = manual or detected when using mode filtering. |
| `innerRing` / `middleRing` | widthScale, heightScale, offsetX, offsetY. The renderer uses fixed ring alpha; ring alpha/scaleX/scaleY are not supported tuning fields. |
| `soft` | Three-layer ellipse feathering, default true; no cosine falloff. |
| `detectionSizing` | Automatic geometry bounds and scale controls; defaults below. |
| `automaticBody` | Separate automatic-body contribution policy; defaults below. |

`detectionSizing` defaults: **contactWidthScale 1.30**, **bodyWidthScale 0.44**, **minimumWidth 8**, **maximumWidthScale 0.70**, **heightScale 0.16**, **minimumHeight 2.5**, **maximumHeight 4.5**. Values resolve through contribution → context → species → defaults; false can disable optional bounds.

`automaticBody` defaults: **sizeScale 2**, **spriteWidthScale 0.44**, **majorExtentScale 0.44**, **minimumContactCoverage 0.20**, **maximumContactOffset 0.25**. Values resolve through context → species → defaults.

Soft ellipses use outer/middle/inner scale factors 1, 0.82, and 0.64 with fixed alpha 0.025, 0.050, and 0.075 and global gain 1.035, then apply configured gain. This is a layered draw, not one opacity value.

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

This hook runs even at 100% when an overworld exists below a menu,
and no battle is in the stack. It cannot enable scaling for a title screen or
an in-battle menu outside those dispatch conditions. The renderer also enforces
its minimum UI scale, so the requested factor is not a pixel-size guarantee.

Stock supported menus opt in by default. Explicit `isModOptions` and `BetterMenusScaleEligible` markers opt in before the general mod-owned screen check. The seven responsive interfaces (PC, party, Pokédex, trainer card, bag, mod manager, and options) retain their own sizing. Other registered mod-owned and unknown screens default to native scale.
There is no current detached-battle-HUD dispatch for this hook. BetterBattle's
own panels use their separate internal half-size target and pixel snapping.

## 5. Battle presentation geometry

BetterBattle features a fully decoupled Battle Presentation Geometry Provider System. Battle actor presentation geometry (positions, ground planes, scaling, and clipping) is cleanly separated from HUD layout. This allows custom battle UIs, alternate widescreen mods, or stock Wide layouts to supply actor presentation geometry, which BetterBattles backdrops and the unified shadow engine consume.

### Hook: `bettermenus.battle_geometry`

```lua
mod.hooks:wrap("bettermenus.battle_geometry", function(next, ctx)
  if ctx.battle.myCustomArena then
    return {
      owner = "my-arena",
      coordinateSpace = "field", -- mandatory: "field" | "native"
      playerX = 52,
      enemyX = 260,
      playerGround = 140,
      enemyGround = 108,
      spriteScale = 0.8333,
      nativeBlit = false,
      nativeAnim = false,
      nativeClip = false,
    }
  end
  return next(ctx)
end)
```

### Provider registration API: `registerBattleGeometryProvider`

Alternatively, mods can register a priority-aware provider callback:

```lua
local api = betterBattle()
if api and api.registerBattleGeometryProvider then
  api.registerBattleGeometryProvider("my_provider", function(battle, ctx)
    if battle.myCustomArena then
      return {
        owner = "my_provider",
        coordinateSpace = "native", -- mandatory: "field" | "native"
        playerGround = 104,
        enemyGround = 56,
        nativeBlit = true,
        nativeAnim = true,
        nativeClip = true,
        stock = true,
      }
    end
  end, 100) -- priority (defaults to 0, higher runs first; registration order is tiebreaker)
end
```

### Context fields

| Field | Meaning |
| --- | --- |
| `game` | The battle's game instance. |
| `battle` | The live battle instance. |
| `uiEnabled` | Boolean: whether BetterBattle UI is active. |
| `battlesEnabled` | Boolean: whether BetterBattles stage/backdrops are active. |

### Geometry return contract & schema

External geometry must be a table containing both `playerGround` and `enemyGround`, and must explicitly declare `coordinateSpace`. Malformed returns are rejected at the resolver boundary and fall through to the next provider.

| Field | Type | Mandatory? | Default / Behavior |
| --- | --- | --- | --- |
| `coordinateSpace` | string | **Yes** | Must be `"field"` or `"native"`. Controls shadow positioning and blit space. |
| `playerGround` | number | **Yes** | Ground line Y in virtual canvas pixels for the player actor. |
| `enemyGround` | number | **Yes** | Ground line Y in virtual canvas pixels for the enemy actor. |
| `owner` | string | No | String identifier for provenance (defaults to `"external"`). |
| `playerX` | number | No | Player actor X position (defaults to `52` for `"field"`, `0` for `"native"`). |
| `enemyX` | number | No | Enemy actor X position (defaults to `260` for `"field"`, `0` for `"native"`). |
| `playerShift` | number | No | Rendering vertical translation offset `dy` (defaults to `playerGround - 104` for `"field"`, `0` for `"native"`). |
| `enemyShift` | number | No | Rendering vertical translation offset `dy` (defaults to `enemyGround - 56` for `"field"`, `0` for `"native"`). |
| `spriteScale` | number | No | Actor sprite scale factor (defaults to `0.8333` for `"field"`, `1.0` for `"native"`). |
| `nativeBlit` | boolean | No | When `true`, actor canvases are blitted natively without field transforms. |
| `nativeAnim` | boolean | No | When `true`, move animations retain native vertical positioning. |
| `nativeClip` | boolean | No | When `true`, retain stock viewport clipping (do not unclip into message box). |
| `stock` | boolean | No | Informational provenance flag. |

### Resolution Pipeline
1. Hook `bettermenus.battle_geometry` (if handled)
2. Registered providers sorted by `priority` descending, with stable insertion order tiebreaker
3. Built-in BetterBattle UI geometry (if `BetterBattle UI` is `ON`)
4. Stock Wide fallback geometry (`coordinateSpace = "native"`, `nativeBlit = true`, `nativeAnim = true`, `nativeClip = true`, `stock = true`)

## 6. BetterBattle exports

Resolve `game.mods.exports["gen1-better-menus"].betterBattle` with nil checks, or
use the `mod.find` helper above. Call these functions with dot syntax:

| Function | Result / usage |
| --- | --- |
| `enabled(battle)` | Whether BetterBattle UI is ON with WIDE and Extended settings. Does not itself check `worldOverride`. |
| `uiEnabled(battle)` | Explicit check for BetterBattle UI being ON with WIDE and Extended settings. |
| `battlesEnabled(battle)` / `stageEnabled(battle)` | Explicit check for BetterBattles (320×180 backdrops and shadow engine) being ON with WIDE and Extended settings. |
| `modeFor(battle)` | Effective `on`, `off`, or `mod` mode. |
| `activeProvider(battle)` | Normalized cached provider claim, or nil. Treat the returned table as read-only. |
| `drawLayer(battle, bottomVisible)` | Draw BetterBattle's detached HUD and register its anchors. Requires the appropriate HUD pass and eligible topmost battle. |
| `expPixels(battle)` | Current animated XP-display pixel count, floored and nonnegative. |
| `registerBattleGeometryProvider(id, fn, priority)` | Register an ordered, priority-aware actor presentation geometry provider. |
| `unregisterBattleGeometryProvider(id)` | True when removed; false for missing or unknown ID. |
| `getBattleGeometry(battle)` | Query the resolved battle presentation geometry for a live battle instance. |
| `shadowEngine` | Shared shadow measurement/rendering module, when available. Ordinary artist integrations use the settings and hooks above. |
| `shadowSettings` | Shadow configuration table exposing `validateSceneConfig`, `registerSpecies`, `registerScene`, `setSpecies`, `setContext`, `addShape`, and species profiles. |
| `backdrop.sceneIds()` | Sorted copy of all registered scene IDs (including custom registered scenes). |
| `backdrop.registerArtistScene(id, config, sourceMod)` | One-stop registration helper for custom 320×180 backdrops and their shadow styles. |
| `backdrop.registerScene(id, imageOrPath, sourceMod)` | Direct registration helper for custom 320×180 backdrops. |
| `backdrop.setScene(battle, id, opts)` | Change a captured battle's scene; default crossfade 0.4 seconds and immediate geometry. Returns true, id or false, error. |
| `backdrop.refresh(battle, opts)` | Re-run selection using captured context. Returns true, id, changed/unchanged or false, error. |
| `backdrop.effectiveGroundOffsets(battle)` | Presentation-time player/enemy offsets, including configured transition timing. |
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

## 7. BetterScenes story stage exports

Resolve `handle.exports.betterScenes` after availability checks. Call methods with dot syntax. The [BetterScenes guide](https://github.com/syybott/Gen1Better/wiki/BetterScenes) supplies complete manifest, update/input controller, asset resolution, cleanup, sequence, and handoff examples.

Gen1Better draws an active stage. The consuming mod must call `update(dt)`, forward advance/skip input, and start/finish encounters. `hide` does not clear all stage resources; completion and skipping do not automatically apply sequence cleanup.

### Complete public API reference

A mutator listed with an error return uses `false, error` for its handled failures. Malformed nested values can still raise ordinary Lua errors; the tables do not promise universal validation. Getters have method-specific returns. Treat nested resource/config references as read-only unless a method explicitly supports editing.

#### Scene presentation

| Method | Return / behavior |
| --- | --- |
| `registerScene(id, config, sourceMod)` | true, id / false, error. Ownership/collisions, protected prefixes gen1_/better_/system_. config.image or config.path required. Use mod.assets for consumer paths; sourceMod alone does not scope paths. Loaded measurable images must be 320×180; unreadable paths are not proven by registration. |
| `show(idOrFalse, opts)` | true, id-or-false / false, error. cut (default), crossfade, flash; underlay black/paper/transparent. |
| `hide(opts)` | true, nil / false, error. Clears background presentation, not other stage resources. |
| `current()` | ID, false (underlay), or nil (no current background). |
| `isActive()` | Boolean considering background/transition, actors, bubble, subtitle, emotes, or sequence. FX/handoff alone do not activate drawing. |
| `update(dt)` | nil. Consumer-driven timeline, FX/weather, and handoff updates. |
| `draw()` | nil. Gen1Better calls this for an active stage; avoid drawing twice. |
| `diagnostics()` | Inspection table. actors is keyed by slot, with no actorCount. active also considers FX/handoff and can differ from isActive. |

#### Actors and dialogue

| Method | Return / behavior |
| --- | --- |
| `setActor(slot, config, opts)` | true, slot / false, error. Built-in left/center/right or custom x/y. Feet-based origin; opts transitions cut/fade/slide. |
| `updateActor(slot, config, opts)` | true, slot / false, error. Merge existing actor data; actor-not-found if absent. |
| `clearActor(slot, opts)` | true, slot (or nil if absent) / false, error. |
| `clearActors(opts)` | true, count. Does not aggregate per-actor validation failures into an error return. |
| `getActor(slot)` | Inspection table or nil, including configured position, scale, mirror, path/pose/frame/shadow and transition flags. |
| `getActorAnchor(slot, name)` | x, y / nil, error. Anchors are feet-relative scaled/mirrored offsets; resolves configured positions, not interpolated motion. |
| `showBubble(speaker, text, opts)` | true, bubbleId / false, error. speech/thought/shout; cut/fade/pop; actor, narrator, or coordinate speaker. |
| `hideBubble(opts)` | true, nil / false, error. cut/fade/pop. |
| `getBubble()` | Table or nil. Text/style/position/size/tail; no lines field. Refreshes actor tail using configured anchor. |
| `setSubtitle(text, opts)` | true, nil / false, error. top/bottom/center; cut/fade, optional bar/align; duration controls visibility, not fade speed. |
| `clearSubtitle(opts)` | true, nil / false, error. |
| `getSubtitle()` | Table or nil. |
| `showEmote(target, type, opts)` | true, targetKey / false, error. exclamation/question/heart/anger/sweat/dots/music. |
| `clearEmote(target)` | true, count; nil target clears all. |
| `getEmotes()` | Inspection array, empty when none. |

#### Stage FX

| Method | Return / behavior |
| --- | --- |
| `shakeScreen(opts)` | true, nil / false, error. Intensity, duration, direction both/horizontal/vertical, frequency, pixelSnap, shakeUI. |
| `stopShake()` | true, nil. |
| `getShake()` | State table with active flag. |
| `setTint(colorOrPreset, opts)` | true, nil / false, error. RGB(A) or sunset/night/cave/underwater/poison/sepia; duration. |
| `clearTint(opts)` | true, nil / false, error; optional duration. |
| `getTint()` | State table with active flag. |
| `flashScreen(colorOrPreset, opts)` | true, nil / false, error. white/red/yellow/black or RGB; duration/mode out or inout/scope stage or full. |
| `stopFlash()` | true, nil. API method, not a sequence action. |
| `getFlash()` | State table with active flag. |
| `setVignette(style, opts)` | true, nil / false, error. letterbox/spotlight/dither. |
| `clearVignette(opts)` | true, nil / false, error. |
| `getVignette()` | State table with active flag. |
| `setWeather(type, opts)` | true, nil / false, error. rain/snow/leaves/cherry_blossom/embers/dust; count/speed/seed/duration. speed is a multiplier, default 1. |
| `clearWeather(opts)` | true, nil / false, error. |
| `getWeather()` | State table with active flag. |

#### Battle handoff

| Method | Return / behavior |
| --- | --- |
| `prepareBattleHandoff(opts)` | true, token / false, error. trainer/wild/boss; cut/flash/blinds/mosaic/swirl, default swirl 0.8s. onHandoff(token) fires after timing. Consumer starts combat and applies music/atmosphere data. |
| `getBattleHandoff()` | Token snapshot or nil, with generated id, state, captured storySceneId, battleBackdropId, encounter data, music/atmosphere, timing, outcome. |
| `cancelBattleHandoff()` | true, nil / false, no-handoff or handoff-locked. Cannot cancel after handing off. |
| `resumeFromBattle(result)` | true, outcome / false, error. result.handoffId must equal token.id; outcome win/lose/flee/draw. Calls matching onWin/onLose/onFlee and onReturn(api, result), then continues a waiting sequence. |

#### Sequences

| Method | Return / behavior |
| --- | --- |
| `playSequence(steps, opts)` | true, sequenceId / false, error. skippable true, cleanup false by default. onComplete(api), onAbort(api[, error]). Stops an existing sequence first. |
| `stopSequence(opts)` | true, nil. Uses cleanup policy from playSequence; stop opts does not change it. |
| `skipSequence()` | true, nil / false, not-skippable. Runs remaining non-wait/non-input/non-battle actions and onComplete; no automatic completion cleanup. |
| `advanceSequence()` | true, nextIndex-or-nil / false, not-waiting. Clears input barrier or timed wait; only forward dialogue input while waitingInput if timed waits should remain intact. |
| `getSequence()` | Table or nil: active/id, stepIndex/totalSteps, waitingInput/waitingBattle, lastBattleOutcome, waitRemaining, currentAction, skippable, aborted, lastError. |

#### Scale defaults and cache

| Method | Return / behavior |
| --- | --- |
| `getDefaultScaleMode()` | String, default nearest. |
| `setDefaultScaleMode(mode)` | true, mode / false, invalid-scale-mode. nearest/auto/variant/clean/area/custom. |
| `getDefaultPixelSnap()` | Boolean, default true. |
| `setDefaultPixelSnap(value)` | true, boolean; coerces Lua truthiness (0 and strings are true). |
| `clearScaleCache()` | true. |
| `setScaleCacheLimit(n)` | true, positive floored limit / false, invalid-limit. Default 128, FIFO eviction. |
| `getScaleCacheCount()` | Number of cached entries. |

### Common configuration defaults

| Surface | Supported options and defaults |
| --- | --- |
| Scene | `config.image` or `path`, underlay, scaleMode, pixelSnap. show/hide opts transition cut, non-cut duration 0.35; underlay resolves from call → target scene → current → transparent. |
| Actor | image/path, x/y, mirror, scale (1), scaleMode, fallbackScaleMode, pixelSnap, variants, customDraw/scaleFn, pose (idle), frame (1), species, shadow, anchors. Transition options cut/fade/slide; non-cut duration 0.3; from/to left/right/top/bottom. |
| Bubble | style speech, transition cut, anchor mouth, maxWidth 180, padding 6, tail true. duration is optional visibility lifetime; fade/pop uses fixed 0.2s. |
| Subtitle | position bottom, transition cut, bar true, align center. duration is optional visibility lifetime; fade uses fixed 0.25s. color is not a supported option. |
| Emote | duration optional, bounce true. Target actor slot or `{ x, y }`. |
| Shake | intensity 4, duration 0.4, frequency 24, direction both, pixelSnap true, shakeUI false. |
| Tint | Named preset or RGB(A); transition duration 0 (immediate). |
| Flash | white default, duration 0.3, mode out, scope stage. No intensity option. |
| Vignette | style required; duration 0, alpha 0.75, color black, target center, radius 80. |
| Weather | type required; speed multiplier 1, seed 1, count 20, transition duration 0. |
| Handoff | battleType trainer, transition swirl, duration 0.8 (cut 0); battleBackdropId/backdropId, trainerId/species/level/music, onHandoff/onWin/onLose/onFlee/onReturn callbacks. |
| Sequence | id optional, skippable true, cleanup false, onComplete/onAbort callbacks. |

Actor scaling resolves an override → actor → current scene → global default. Pixel snapping follows the same precedence. Custom drawing is only called in effective custom mode as `callback(actor, ctx)`, where ctx contains image, requested scale, scaleMode, pixelSnap, fallbackScaleMode, screen x/y, and mirror. Any truthy return claims drawing; false/nil or an error uses the fallback. The regular path draws with its own stage scale and actor alpha, so a custom callback must implement its intended presentation.

The [sequence action guide](https://github.com/syybott/Gen1Better/wiki/BetterScenes#6-declarative-sequences) documents aliases and option nesting. Actor action transitions must be in `step.opts`. Emote actions do not block on wait=true. Use a call step for `stopFlash`.

## 8. Options-screen marker

```lua
local OptionsScreen = { isModOptions = true }

function OptionsScreen.new(game)
  return { game = game, isModOptions = true, rows = {}, index = 1 }
end
```

Add the marker to your actual factory or instance, retaining its existing draw
and input methods. Gen1Better propagates the factory marker for screens built
through `Screens.build` / `Screens.push`; manually pushed instances should carry
the marker themselves. This identifies options-style layout behavior and automatically opts the screen into Menu Scale in the eligible overworld/menu path. `BetterMenusScaleEligible = true` also opts in. No Gen1Better dependency is required.

See [Mod Options Screen Compatibility](https://github.com/syybott/Gen1Better/wiki/Mod-Options-Screen-Compatibility).

## 9. Party actions and BetterPC helpers

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

Other exports are `betterParty`, `betterPokedex`, `betterModManager`, `betterOptions`, and `betterBag` screen factories, plus
`betterBagInventoryLimits` with `slots` and `stack`. Prefer the engine's registered
`PartyMenu` / `BagMenu` screens for ordinary navigation so settings-based routing
continues to apply. BetterPC is routed through the registered `BoxMenu`; there is
no top-level `betterPC` or `betterTrainerCard` export. The trainer card uses its registered screen routing.

### Exported screen factories

| Export | Entry points |
| --- | --- |
| `betterParty` | `new(game, opts)` |
| `betterPokedex` | `new(game, opts)` |
| `betterBag` | `new(game, opts)` |
| `betterModManager` | `new(game, ...)`, forwarding the registered mod-manager screen arguments. |
| `betterOptions` | `new(game, opts)`; `wrapStartItem(game, items, enabled, onError)`; TABS and CATEGORY tables. |

`betterOptions.wrapStartItem` wraps the OPTION Start Menu entry and returns nil. Pass an `enabled()` callback and optional `onError(error)` callback. Its factory supports `opts.onCancel`. Prefer registered screen navigation for ordinary use; directly constructing a factory bypasses the routing decision that selects classic or Better interfaces.

## Existing provider bridges and limits

Integrate new renderers through the public ownership hook, geometry providers, and exported HUD API. An existing companion integration does not define a general interface for another mod's private textures or internal functions.

The provider claim controls layout ownership; it does not promise universal
recoloring of arbitrary third-party textures. Known provider bridges can apply
Gen1Better palette coverage separately even when BetterBattle's layout yields.

Gen1Better also wraps engine hooks including `render.compose`, `render.letterbox`,
`render.hud`, `render.zones`, `battle.overlay`, `screen.render_visible`,
`ui.options.rows`, and `ui.start_menu.items`. Preserve their engine contracts and
chain with `next`; they are not interchangeable with the Gen1Better hooks.

## Compatibility testing

When testing compatibility with other mods, verify behavior across standard in-game states:
check your provider active and inactive, each BetterBattles/BetterBattle UI combination, fishing versus
surfing, nickname entry, and menu overlays. An inactive 2D backdrop while your 3D
provider owns the frame is expected. Use the [Diagnostics API](https://github.com/syybott/Gen1Better/wiki/Battle-Backdrops#diagnostics)
to inspect the active scene state and verify whether the backdrop is drawn.
