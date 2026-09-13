# Gen1BetterMenus — Provider and Mod Compatibility

This wiki reference describes the interfaces implemented in the current
BetterMenus source. Feature files use the BetterBattle, BetterPC, BetterBag,
and BetterParty names; existing hook names, settings keys, and exports retain
their compatibility names.

## Interface index

| Interface | Kind | Purpose |
| --- | --- | --- |
| `bettermenus.betterbattle_provider` | BetterMenus hook | Declare who owns battle rendering and whether BetterBattle may draw its HUD. |
| `bettermenus.battle_backdrop` | BetterMenus hook | Select a registered 2D scene for a normal or custom-spawn battle. |
| `bettermenus.ui_scale` | BetterMenus hook | Opt a custom menu into the user's Menu Scale, or keep native scale. |
| `betterBattle` | Export | Query battle ownership, draw the BetterBattle HUD, inspect backdrop selection. |
| `isModOptions = true` | Screen marker | Identify a third-party settings screen. |
| `ui.party.submenu` | Engine hook supported by BetterMenus | Add actions to party menus and BetterPC's party-side action list. |
| `modernPC*` methods | BetterPC instance helpers | Operate the active PC screen through its existing controller. |
| `modernParty`, `modernBag`, `modernBagInventoryLimits` | Exports | Access installed screen factories and active inventory limits. |

The `render.*`, `pokemon.sprite`, and `ui.*` engine hooks mentioned below are
engine interfaces, not additional BetterMenus-owned hooks.

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

This is a selector for registered BetterMenus assets, not an arbitrary image-path
or new-scene registration API. Selection does not enable BetterBattle or override
an external renderer. The 320×180 art retains its full colors; front sprites are
required for BetterBattle to display properly. No mon-paper backing is added.

## 3. Custom-menu scaling

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

## 4. BetterBattle exports

Resolve `game.mods.exports["gen1-better-menus"].betterBattle` with nil checks, or
use the `mod.find` helper above. Call these functions with dot syntax:

| Function | Result / usage |
| --- | --- |
| `enabled(battle)` | Whether the effective BetterBattle mode is ON with WIDE and Extended settings. Does not itself check `worldOverride`. |
| `modeFor(battle)` | Effective `on`, `off`, or `mod` mode. |
| `activeProvider(battle)` | Normalized cached provider claim, or nil. Treat the returned table as read-only. |
| `drawLayer(battle, bottomVisible)` | Draw BetterBattle's detached HUD and register its anchors. Requires the appropriate HUD pass and eligible topmost battle. |
| `expPixels(battle)` | Current animated XP-display pixel count, floored and nonnegative. |
| `backdrop.sceneIds()` | Sorted copy of all registered scene IDs. |
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

## 5. Options-screen marker

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

## 6. Party actions and BetterPC helpers

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

The active BetterPC instance (`state.modernPCUI == true`) exposes colon methods:

| Method | Purpose |
| --- | --- |
| `state:modernPCSelected()` | Get the current selection through the PC controller. |
| `state:modernPCPickOrDrop()` | Pick up or place the selection. |
| `state:modernPCSwitchBox(delta)` | Switch boxes through the existing controller. |
| `state:modernPCQuickTransfer()` | Transfer between party and box. |
| `state:modernPCRequestRelease()` | Open the existing release confirmation flow. |
| `state:modernPCLayoutInfo()` | Get the current computed layout. |

These retain their `modernPC` names for compatibility; file renames do not rename
the methods. Resolve the active screen before calling them.

Other retained exports are `modernParty` and `modernBag` screen factories, plus
`modernBagInventoryLimits` with `slots` and `stack`. Prefer the engine's registered
`PartyMenu` / `BagMenu` screens for ordinary navigation so settings-based routing
continues to apply. BetterPC is routed through the registered `BoxMenu`; there is
no top-level `modernPC` export in this source.

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
chain with `next`; they are not interchangeable with the three BetterMenus hooks.

## Compatibility testing

The [backdrop visual-driver instructions](Battle-Backdrops.md#diagnostics-and-visual-driver)
describe runs using the user's current saved settings and enabled mods. Every
new run snapshots the settings, loaded mods, source hashes, selection diagnostics,
and screenshots. It does not silently enable BetterBattle or replace sprite mods.

Check your provider active and inactive, BetterBattle ON and OFF, fishing versus
surfing, nickname entry, and menu overlays. An inactive 2D backdrop while your 3D
provider owns the frame is expected. Compare diagnostics with what the screenshot
actually presents rather than treating a selected scene ID as proof it was drawn.

Source: [provider/HUD](../better_battle_hud.lua),
[backdrops](../better_battle_backdrops.lua), [scaling and integration](../main.lua),
[BetterPC](../better_pc_screen.lua).
