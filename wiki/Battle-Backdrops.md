# BetterBattle pixel-art backdrops

BetterBattle automatically selects a 320×180 scene when BetterBattle is ON,
the battle layout is WIDE, the HUD is Extended, and no external renderer owns
the battle. Crystal battle sprites are required for BetterBattle to display
properly. Other sprite providers can have the same transparency or matting
problem, so their battle assets must also be checked before using these
backgrounds. There is no hollow-sprite detector or white rectangle behind
Pokémon.

## Sprite compatibility requirement

BetterBattle backgrounds expose any transparency that exists in the battle
sprite itself. The current supported visual configuration therefore requires
the Crystal battle-sprite provider, which supplies the corrected battle sprite
assets. A different sprite mod can be used only after its front and back battle
sprites have been inspected against a full-color backdrop. The same failure can
occur with any provider whose extractor or animation pipeline leaves body pixels
transparent: the backdrop will show through those pixels. BetterBattle does not
repair those assets or add a paper-colored backing rectangle.

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

The backdrop selector is one of the public BetterMenus compatibility hooks.
See the [provider and mod compatibility reference](Compatibility.md) for the
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
  Diglett's Cave, ship locations, the dock, and Celadon roofs use their named art.
- Silph floors use the office; Rocket Hideout floors use the bunker.
- Seafoam B4F always uses its chamber, including fishing and surfing. Other
  Seafoam land uses ice cave; Seafoam/Cerulean Cave water uses water cave.
- Route 12 land and fishing use Silence Bridge; surfing uses ocean.
- Route 24's five bridge trainers and Rocket recruiter use Nugget Bridge;
  the off-bridge trainer uses route dirt. Fishing/surfing use lake water.
- Route 23 land uses mountain pass. Other numbered-route wild/trainer encounters
  use route grass/dirt; sea routes and inland waters use their respective scenes.
- Named towns, Viridian Forest, and Safari outdoor areas use their assigned art.
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

## Diagnostics and visual driver

`mod.exports.betterBattle.backdrop` exposes `sceneIds()`, pure `resolve(context)`,
and `diagnostics(battle)`. Diagnostics returns a detached table with the selected
scene, reason, asset path, captured encounter context, whether the field was made
transparent, whether the scene was rendered, viewport dimensions, and inactivity
reason. Changing that table does not change the battle. False scene IDs mean plain.

From the Gen1Recomp folder, run:

```powershell
.\worker-drivers\run_betterbattle_backdrops.ps1 -Version red
.\worker-drivers\run_betterbattle_backdrops.ps1 -Version red -Case route_12_fish
.\worker-drivers\run_betterbattle_backdrops.ps1 -Version blue -Suite scenes -Width 2560 -Height 1080
```

The default driver snapshots your current saved options and loads your installed,
enabled mods. It does not force BetterBattle ON, change palettes, or substitute
sprites. Save your settings before launching; each new run reads them again.
Explicit Width/Height arguments request only a test-window size change. The
`guards` suite contains deliberate palette/nickname/hook test cases and records
those changes separately.

Test party/progress and mod storage live under a fresh LÖVE identity; user save
files are not used or overwritten. Installed mods and complete ROM caches are
shared, while writable mod caches are copied. Captures, JSON results, launch-option
snapshots, and file hashes go under a timestamped `worker-output` directory.

`locations` verifies actual map/encounter selection. `scenes` requests all 63
registered IDs through the public custom-spawn hook. Inactive BetterBattle and
active external providers must produce an ownership check, not a false claim
that backdrop art was visually validated. Crystal battle sprites are required
for the background-on visual acceptance configuration, and any alternate sprite
provider needs the same full-color compatibility check.
