# BetterBattle pixel-art backdrops
 
A battle backdrop gives each encounter a sense of place: a forest path, a gym arena, a ship's deck, or a scene you painted yourself

Gen1Better includes 63 registered scenes and chooses them from the encounter's location and circumstances. To present the 2D stage, use **BetterBattles ON**, **WIDE** layout, and **EXTENDED** HUD. **BetterBattle UI** separately controls the panels; an active external scene renderer takes priority over the 2D backdrop.

Want to bring your own art into a battle? Start with the [Artist Backdrop Pack guide](https://github.com/syybott/Gen1Better/wiki/Artist-Backdrop-Packs). This page provides the scene catalog, selection rules, and integration details to support your pack.

## Sprite compatibility requirement

Use battle sprites with a correctly defined transparency mask: the background must be transparent while the Pokémon itself, including white body areas, remains opaque. Crystal Animated Sprites supplies compatible assets; another pack meeting the same requirement can be used.

Full-color backdrops expose holes in the sprite's body mask. Gen1Better does not repair those assets or add a paper-colored backing rectangle.

The scene retains its original colors: it is rendered on an outer canvas with
no palette shader, beneath the transparent actor canvas and the independently
shaded HUD. Nearest filtering preserves pixel edges. The image fits the viewport
height; narrow windows crop its sides and wide windows extend its edge columns.

The provider yields to the existing BetterBattle provider hook and staged-renderer
detection, as well as any `renderer.worldOverride` present at composition time.
An installed but inactive 3D mod does not by itself suppress the scene. Nickname
blanking returns to the native draw path. Missing images retain the plain field
and log one warning per path for the session.

## Custom-spawn hook

The backdrop selector is one of the public Gen1Better compatibility hooks.
See the [provider and mod compatibility reference](https://github.com/syybott/Gen1Better/wiki/Compatibility) for the
full hook contract, provider ownership rules, and exported BetterBattle API.

Wrap `bettermenus.battle_backdrop` using `mod.hooks:wrap`. It runs synchronously
after the engine constructs a battle and before the constructor returns. The
selected scene is retained for that battle. Rendering does not re-run this hook.

The context contains `game`, `battle`, `mapId`, `x`, `y`, `tileset`, `surfing`,
`fishing`, `kind`, `species`, `trainerClass`, `partyIndex`, and `defaultSceneId`.
Unknown context fields may be nil. Fishing is captured from `opts.hooked` and
preserved as `battle.kaHooked` before this callback executes.

Return a registered scene ID to override automatic matching, `false` to request
a plain background, or `next(ctx)` to delegate. A final nil result uses automatic
matching. Unknown IDs or other result types log once and use automatic matching.
The scene hook never grants rendering ownership over a 3D provider.

Hook priority follows the engine: higher numeric priorities run first; calling
`next(ctx)` evaluates the lower-priority wrappers. Do not depend on ordering
between equal priorities. A throwing callback follows the engine's existing
hook error recovery; it is logged and downstream selection remains available.

### Custom wild spawn

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
  sceneForSpawn = previous -- also restore after a refused spawn or exception
  if not ok then error(started, 0) end
  return started, err
end
```

The temporary context pattern applies to synchronous construction such as
`WorldAPI:startWildBattle`. If your spawn first opens dialogue or schedules a
callback, establish the context inside the callback that actually constructs
the battle, not just around the initial request.

### Custom trainer spawn

```lua
mod.hooks:wrap("bettermenus.battle_backdrop", function(next, ctx)
  if ctx.kind == "trainer" and ctx.trainerClass == "MY_SPACE_TRAINER"
      and ctx.partyIndex == 1 then
    return "custom_spaceship"
  end
  return next(ctx)
end)
```

Replace the example class with your registered trainer class. This hook works
with normal trainer encounters and custom callers of `BattleState.newTrainer`.
It selects art; it does not create encounters or trainer definitions.

## Automatic scene rules

Specific landmarks precede trainer identity, then terrain/location rules, then
the universal route-grass fallback. Unfinished gyms intentionally select plain
instead of falling through. Existing Pewter, Cerulean, and Viridian grunt scenes
remain distinct from their leaders.

- Elite Four/champion rooms, Oak's Lab, Power Plant, Pokémon Mansion/Tower,
  Diglett's Cave, ship locations, the dock, and Celadon roofs use their named art
- Silph floors use the office; Rocket Hideout floors use the bunker
- Seafoam B4F always uses its chamber, including fishing and surfing. Other
  Seafoam land uses ice cave; Seafoam/Cerulean Cave water uses water cave.
- Route 12 land and fishing use Silence Bridge; surfing uses ocean
- Route 24's five bridge trainers and Rocket recruiter use Nugget Bridge;
  the off-bridge trainer uses route dirt. Fishing/surfing use lake water.
- Route 23 land uses mountain pass. Other numbered-route wild/trainer encounters
  use route grass/dirt; sea routes and inland waters use their respective scenes.
- Named towns, Viridian Forest, and Safari outdoor areas use their assigned art
- Labs use general lab; clubs/Daycare use fan club; houses/gates use ship quarters.
  Unknown interiors use general lab; unknown outdoor locations use route grass.

Vermilion City has no supplied town scene, so land encounters currently use the
universal fallback. Alternate/custom scenes without assigned triggers are hook-only.

## Registered scenes

The file for every ID is `assets/backdrops/wide/<id>_320.png`. High-resolution
variants are not loaded.

| Group | IDs |
| --- | --- |
| Bosses | `boss_agatha`, `boss_bruno`, `boss_lorelei`, `boss_lance`, `boss_champion`, `boss_giovanni_silph`, `boss_giovanni_hideout`, `boss_giovanni_gym` |
| Gyms | `gym_pewter_leader`, `gym_pewter_grunt`, `gym_cerulean_leader`, `gym_cerulean_grunt`, `gym_vermilion_leader`, `gym_fuchsia_leader`, `gym_saffron_leader`, `gym_viridian_grunt` |
| Towns | `town_pallet`, `town_viridian`, `town_pewter`, `town_cerulean`, `town_lavender`, `town_celadon`, `town_fuchsia`, `town_saffron`, `town_cinnabar`, `town_indigo_plateau` |
| Landmarks | `landmark_oak_lab`, `landmark_power_plant`, `landmark_pokemon_mansion`, `landmark_pokemon_tower`, `landmark_vermilion_dock`, `landmark_ship_deck`, `landmark_ship_quarters`, `landmark_digletts_cave`, `landmark_seafoam_b4f`, `landmark_nugget_bridge`, `landmark_silence_bridge`, `landmark_fan_club`, `landmark_lab_general`, `landmark_celadon_mart_roof`, `landmark_celadon_mansion_roof` |
| Land | `env_route_grass`, `env_route_dirt`, `env_tall_grass`, `env_grass_variant`, `env_fr_grass`, `env_viridian_forest`, `env_mountain_pass`, `env_safari_zone` |
| Caves/water | `env_cave`, `env_water_cave`, `env_ice_cave`, `env_lava_cave`, `env_desert_cave`, `env_ocean_water`, `env_lake_water`, `env_beach`, `env_shoreline` |
| Custom | `custom_desert`, `custom_mountain_snow`, `custom_snow_grass`, `custom_space`, `custom_spaceship` |

## Custom backdrop registration

> [!TIP]
> **Creating an artist backdrop pack?** See the [Artist Backdrop Pack Quickstart](https://github.com/syybott/Gen1Better/wiki/Artist-Backdrop-Packs)
> for a beginner guide with one-stop registration, encounter recipes, and folder structure.

In addition to the 63 built-in scenes, other mods can register their own custom
320×180 battle backdrops using `betterBattle.backdrop.registerScene` or the unified
`betterBattle.backdrop.registerArtistScene`:

```lua
local function registerCustomBackdrops()
  local other = mod.find("gen1-better-menus")
  local backdropApi = other and other.exports and other.exports.betterBattle
      and other.exports.betterBattle.backdrop
  if not backdropApi then return end

  -- One-stop registration (image + shadow styling together):
  local ok, result = backdropApi.registerArtistScene("my_custom_arena", {
    image = "assets/arena_320.png",
    shadows = {
      color = { 0.45, 0.32, 0.18 }, -- warm sunset earth tint
      opacityScale = 0.85,
    },
  }, mod)

  if not ok then error("Backdrop registration: " .. tostring(result)) end

  -- Or direct registration:
  -- backdropApi.registerScene("my_custom_arena", "assets/arena_320.png", mod)
end
```

Once registered, your scene ID is recognized by `bettermenus.battle_backdrop`,
`betterBattle.backdrop.sceneIds()`, and `betterBattle.shadowSettings.registerScene`

You can also return a dynamic table directly from `bettermenus.battle_backdrop`:

```lua
mod.hooks:wrap("bettermenus.battle_backdrop", function(next, ctx)
  if ctx.mapId == "MY_CUSTOM_MAP" then
    return { id = "my_custom_arena", image = myLoveImage }
  end
  return next(ctx)
end)
```

## Verifying backdrops for 1080p and 4K (Python)

All BetterBattle 2D backdrops must be **strictly 320×180 pixels**

### Why 320×180 scales cleanly

In 16:9 widescreen, 180 is an exact integer factor of all standard viewport heights:
- **720p**: $180 \times 4 = 720$ ($320 \times 4 = 1280$) $\to$ **$4\times$ integer scale**
- **1080p**: $180 \times 6 = 1080$ ($320 \times 6 = 1920$) $\to$ **$6\times$ integer scale**
- **1440p**: $180 \times 8 = 1440$ ($320 \times 8 = 2560$) $\to$ **$8\times$ integer scale**
- **4K (2160p)**: $180 \times 12 = 2160$ ($320 \times 12 = 3840$) $\to$ **$12\times$ integer scale**

With nearest-neighbor sampling (`nearest`, `nearest`), every single virtual pixel maps to
an exact, uniform $6\times 6$ square of screen pixels at 1080p and a $12\times 12$ square
at 4K. There is zero sub-pixel distortion, fractional pixel shimmering, or interpolation blur.

### Validation script

Gen1Better includes `tools/verify_backdrop.py`. Install Pillow and NumPy, then inspect an image or directory:

```bash
python -m pip install Pillow NumPy
python tools/verify_backdrop.py path/to/my_backdrop_320.png
```

The validator checks backdrop export requirements and reports palette size, flat-neighbor ratios, and interpolated-ramp heuristics. Grades are PERFECT, PASS, WARN, or FAIL. An ordinary graded run fails only FAIL; `--strict` also fails WARN. Read the dedicated guide for the alpha inspection's current limits.

With `--counterpart-dir` it can compare matching native/high-resolution images and measure nearest-neighbor 4K differences and eligible block uniformity. The [Backdrop Artwork Checker guide](https://github.com/syybott/Gen1Better/wiki/Backdrop-Artwork-Checker) explains counterpart filenames, every grade, the exact thresholds, strict mode, and JSON reports. A native-image-only run does not capture or verify in-game output at display resolutions.

Other window sizes can use fractional scales; the integer examples above apply to those full 16:9 viewport sizes

## Shadow system and scene interaction

BetterBattle renders soft, multi-layered feathered shadows beneath battlers when
a 2D backdrop is active, powered by the shared Actor Shadow Engine (`schemaVersion = 1`, `profileVersion = 1`). Each species has baseline dimensions, grounding rules,
and optional manual limb shapes or dynamic wing-feathering detectors.

Because shadow profiles are unified across the mod, species definitions registered
via `betterBattle.shadowSettings.registerSpecies` are immediately available in both
combat backdrops and [BetterScenes narrative cutscenes](https://github.com/syybott/Gen1Better/wiki/BetterScenes#actor-shadows-and-floor-contact).
Species-level tuning is shared; optional `player`, `enemy`, and `scene` overrides
remain isolated presentation contexts and never cross-inherit.

Because different battle scenes represent different environments (e.g. solid ground,
water, dark interiors, or weightless outer space), BetterBattle provides two ways
for modders to customize shadows for custom scenes:

### Declarative scene configuration

Modders can configure scene-wide shadow behavior using `shadowSettings.registerScene(sceneId, config)`:

```lua
local function setupSceneShadows()
  local other = mod.find("gen1-better-menus")
  local api = other and other.exports and other.exports.betterBattle
  local shadowSettings = api and api.shadowSettings
  if not shadowSettings then return end

  -- Suppress ground shadows entirely for space / void scenes:
  shadowSettings.registerScene("custom_space", {
    enabled = false,
  })

  -- Water surface: tint shadows oceanic blue and soften opacity:
  shadowSettings.registerScene("env_ocean_water", {
    color = { 0.05, 0.15, 0.30 },
    opacityScale = 0.70,
  })
end
```

Direct `shadowSettings.registerScene` does not validate input and returns the live merged configuration. For values from a tool or user input, call `validateSceneConfig` first and only register its successful normalized result.

Available scene properties (validated by `shadowSettings.validateSceneConfig`):
- `enabled`: Set to `false` to disable shadows in this scene entirely. Must be a strict boolean (`true` or `false`).
- `color`: `{ r, g, b }` or `{ r = ..., g = ..., b = ... }` table for custom shadow tinting. Components must be finite numbers in `[0.0, 1.0]` (numeric strings accepted).
- `opacityScale`: Non-negative multiplier applied to all shadow layers in this scene (finite number $\ge 0$, numeric strings accepted)
- `offsetY`: **Shadow-only** vertical adjustment applied to the shadow contact anchor (does not move the Pokémon; numeric strings accepted)
- `playerOffsetY`: Side ground-plane adjustment lifting or lowering the player Pokémon sprite, battler-attached status panel, and shadow together (e.g. `+4` for sunken shoreline; numeric strings accepted)
- `enemyOffsetY`: Side ground-plane adjustment lifting or lowering the enemy Pokémon sprite, battler-attached status panel, and shadow together (e.g. `-12` for high cliff/podium; numeric strings accepted)

> [!NOTE]
> `shadowSettings.validateSceneConfig(config)` can pre-validate and normalize custom scene configurations before registration

### Dynamic scene changes & transitions

Modders can change the active backdrop mid-battle (for multi-phase boss fights, terrain destruction, or scripted weather):

```lua
-- Transition active scene mid-battle
local ok, sceneId = api.backdrop.setScene(battle, "boss_phase2_ruins", {
  transition = "crossfade", -- "crossfade" (default), "flash", or "cut"
  duration = 0.5,           -- seconds
  geometry = "lerp",        -- "immediate" (default) | "lerp" | "after"
})
-- Returns: true, sceneId | false, "unknown-scene" | false, "no-record" | false, "invalid-battle"

-- Re-run selection using captured encounter context; inspect ctx.battle for live state
local ok, sceneId, status = api.backdrop.refresh(battle, { transition = "flash" })
-- Returns: true, sceneId, "changed" | true, sceneId, "unchanged" | false, err
```

> [!NOTE]
> **Cached vs. Dynamic Selection**: Normal scene selection is cached. `refresh()` is an explicit API escape hatch that re-runs selection against the captured context. It does not recapture map or position fields. Hooks can inspect the live battle to choose a different scene.

#### Scene identity vs. geometry presentation

Scene identity switches immediately on `setScene()` (`diagnostics(battle).sceneId` resolves to the target scene right away for deterministic scripting). However, visible geometry timing can be configured via `opts.geometry`:

- `geometry = "immediate"` *(default)*: Target scene offsets apply immediately on frame 0. Best when arena height does not change.
- `geometry = "lerp"` *(recommended for elevation changes)*: Smoothly interpolates `playerOffsetY` and `enemyOffsetY` across the transition duration ($0.0 \to 1.0$), when their geometry path incorporates these offsets
- `geometry = "after"` *(niche fallback)*: Holds the origin scene ground offsets until the visual transition reaches 100%, then snaps to target offsets. Avoid unless you specifically want an old ground hold followed by a snap.

**Creator Guidance for Arena Transitions**:
- **Hard scene jumps**: Use `transition = "cut"` or `"flash"`. Flash masks height snaps naturally behind full-screen intensity.
- **Elevation changes** (cliffs, platforms, podiums, water trenches, elevators, psychic lifts, abduction beams): Use `transition = "crossfade"` with `geometry = "lerp"`
- **Same-height transitions**: Use default `geometry = "immediate"`

#### Single source of truth: `effectiveGroundOffsets`

The built-in BetterBattle UI geometry includes the scene offsets. External geometry providers must incorporate them into their own ground lines/shifts. Query the presentation-time values with:
```lua
local playerOffsetY, enemyOffsetY = api.backdrop.effectiveGroundOffsets(battle)
```
Diagnostics also reports `effectivePlayerOffsetY` and `effectiveEnemyOffsetY` alongside the raw target `playerOffsetY` and `enemyOffsetY`

### Dynamic battle shadow hook

For dynamic or conditional shadow behavior (e.g. reacting to battle state, weather,
or Pokémon actions), use the `bettermenus.battle_shadow` hook. See the
[Provider and Mod Compatibility guide](https://github.com/syybott/Gen1Better/wiki/Compatibility#3-battle-shadows-and-custom-scenes)
for full hook specifications and examples.

## Diagnostics

`mod.exports.betterBattle.backdrop` exposes `sceneIds()`, pure `resolve(context)`,
`setScene(battle, sceneId, opts)`, `refresh(battle, opts)`, and `diagnostics(battle)`. Diagnostics returns a detached table with the selected
scene, reason, asset path, captured encounter context, whether the field was made
transparent, whether the scene was rendered, viewport dimensions, elevated ledge offsets (`playerOffsetY`, `enemyOffsetY`), transition status, and inactivity
reason. Changing that table does not change the battle. False scene IDs mean plain.
