# Artist Backdrop Pack Quickstart

BetterBattle turns Gen 1 widescreen battles into an **artist-pack surface**. As an artist or modder creating battle scenes, you do not need to understand provider ownership, render composition passes, or detector internals.

You only need three safe doors:
1. **“Here is my 320×180 image.”**
2. **“Here is when it should appear.”**
3. **“Here is how shadows should look on it.”**

---

## 1. The Hard Wall: Strictly 320×180 PNGs

All BetterBattle 2D backdrops must be fully opaque **320×180 PNGs**.

At full 16:9 viewport sizes, the 180-pixel height scales by these integer factors:

- **720p**: $180 \times 4 = 720$ ($320 \times 4 = 1280$) $\to$ **$4\times$ exact integer scale**
- **1080p**: $180 \times 6 = 1080$ ($320 \times 6 = 1920$) $\to$ **$6\times$ exact integer scale**
- **1440p**: $180 \times 8 = 1440$ ($320 \times 8 = 2560$) $\to$ **$8\times$ exact integer scale**
- **4K (2160p)**: $180 \times 12 = 2160$ ($320 \times 12 = 3840$) $\to$ **$12\times$ exact integer scale**

Because BetterBattle renders with nearest-neighbor texture sampling, every single pixel of your artwork scales into an exact, uniform $6\times 6$ square of screen pixels at 1080p and an exact $12\times 12$ square at 4K.

Other viewport sizes can produce fractional display scales. Images of other dimensions do not meet the backdrop API contract.

---

## 2. Run the Validator First

Before packaging your art, test it using the built-in validator script:

```bash
python tools/verify_backdrop.py assets/my_scene_320.png
```

The validator reports exact dimensions, aspect ratio, opacity, palette size, flat-neighbor ratios, and possible interpolated color ramps. It grades images **PERFECT**, **PASS**, **WARN**, or **FAIL**. Incorrect dimensions, a non-PNG format, or any alpha below 255 fail the contract.

Install its dependencies with `python -m pip install Pillow NumPy`. By default only FAIL produces a nonzero exit status; `--strict` also fails WARN. An optional `--counterpart-dir` compares matching native/high-resolution images, including nearest-neighbor 4K differences and eligible texel-block uniformity checks. A native-image-only run does not test actual in-game rendering at 1080p or 4K.

---

## 3. Mod Folder Layout

Place your mod folder inside Gen1Recomp's `mods/` directory:

```text
mods/
└── my-artist-pack/
    ├── manifest.json
    ├── main.lua
    └── assets/
        └── sunset_route_320.png
```

### `manifest.json`
```json
{
  "id": "my-artist-pack",
  "name": "My Sunset Route Backdrops",
  "version": "1.0.0",
  "api": 2,
  "entry": "main.lua",
  "dependencies": ["gen1-better-menus"],
  "description": "Custom sunset battle backdrops for Route 1."
}
```

---

## 4. The Clean Artist Story (`main.lua`)

Copy this into `main.lua`. Register the hook immediately; acquire the export and register the image after `game.ready` so the API is available. Prefix scene IDs to avoid collisions.

```lua
local mod = ...
local sceneReady = false

mod.hooks:wrap("bettermenus.battle_backdrop", function(next, ctx)
  if sceneReady and ctx.mapId == "ROUTE_1" then return "my_artist_sunset_route" end
  return next(ctx)
end)

mod.events:on("game.ready", function()
  local handle = mod.find("gen1-better-menus")
  local bb = handle and handle.exports and handle.exports.betterBattle
  if not bb or not bb.backdrop then return end

  local ok, result = bb.backdrop.registerArtistScene("my_artist_sunset_route", {
    image = "assets/sunset_route_320.png",
    shadows = {
      color = { 0.45, 0.32, 0.18 },
      opacityScale = 0.85,
      offsetY = 0,
    },
  }, mod)
  if not ok then error("Backdrop registration: " .. tostring(result)) end
  sceneReady = true
end)
```

Pass your own `mod` as the third argument: battle backdrop paths are then resolved through your pack's assets and registration ownership belongs to your pack. Omitting it uses Gen1Better as owner.

> [!IMPORTANT]
> **Registration vs Display**: `registerArtistScene` only *registers* your art and shadow settings with the engine; it does *not* display it. The `bettermenus.battle_backdrop` hook owns when the scene appears.
>
> This separation is intentional: `bettermenus.battle_backdrop` runs when the battle is constructed and its result is cached. Ordinary drawing does not re-run it; an explicit `backdrop.refresh` does.

---

## 5. Scene ID Rules & Collision Protection

BetterBattle provides robust safeguards to keep multiple artist packs from stomping each other:
- **Return contract**: `registerArtistScene` returns `true, id` on success and `false, err` for the handled registration/shadow validation rejections below. Invalid IDs/configuration types and incorrect dimensions on loaded Images can raise assertions or Lua errors:
  - `"reserved"`: ID matches a Gen1Better built-in scene.
  - `"collision"`: ID is already registered by another mod.
  - `"shadow_subsystem_unavailable"`: Shadow configuration or ground offsets were requested, but the shadow subsystem is uninitialized or unavailable.
  - `"invalid_shadows"`: The `shadows` property was provided but is not a table.
  - `"invalid_color"`: Color is not a table, components are outside `[0.0, 1.0]`, or values are non-numeric / NaN / infinite.
  - `"invalid_opacity_scale"`: Opacity scale is negative, non-numeric, NaN, or infinite.
  - `"invalid_offset_y"` / `"invalid_player_offset_y"` / `"invalid_enemy_offset_y"`: Offset is non-numeric, NaN, or infinite.
  - `"invalid_enabled"`: Enabled is not a strict boolean (`true` or `false`).
- **Pre-Commit Boundary Guarantee**: All supported shadow-schema and subsystem-availability failures are resolved before the backdrop is registered, so invalid artist configuration cannot produce a partial scene registration.
- **Permissive Representation, Strict Meaning**: For all artist-facing numeric shadow fields (`opacityScale`, `offsetY`, `playerOffsetY`, `enemyOffsetY`, and color components), valid numeric strings (e.g. `"0.85"`, `"-4"`) are automatically coerced to real numbers. However, invalid meanings (`NaN`, `math.huge`, `-math.huge`, negative opacity, out-of-range colors) are rejected upfront. `enabled` strictly requires boolean `true` or `false`.
- **Custom Key Preservation**: Any custom extension metadata attached to your `shadows` table is preserved untouched for third-party hook compatibility.
- **Built-in IDs are reserved**: Attempting to register over built-in scenes (e.g. `"env_route_grass"`, `"boss_giovanni_gym"`) is rejected. If you want to replace what appears on Route 1, return your own custom scene ID from the `bettermenus.battle_backdrop` hook.
- **Mod ownership**: Registration compares the source mod identity. Re-registration by the same owner can update its scene; a different owner is rejected. Pass the same mod handle consistently.
- **Quiet Logging**: Collision and reservation warnings are logged exactly once per `{id, mod}` pair to keep console output clean.
- **Best Practice**: Prefix your scene IDs with your mod name or initials (e.g. `mypack_route_1`, `mypack_sunset`).

---

## 6. Encounter Trigger Recipes

These are hook-body recipes. Register the scene first and only return its ID once registration succeeds, as in the quickstart.

The `bettermenus.battle_backdrop` hook passes a context table (`ctx`) with details about the encounter. Return your scene ID to display your art, or call `next(ctx)` to keep the default background:

### By Map Name
```lua
mod.hooks:wrap("bettermenus.battle_backdrop", function(next, ctx)
  if ctx.mapId == "VIRIDIAN_FOREST" then
    return "mypack_forest"
  end
  return next(ctx)
end)
```

### By Gym Leader or Trainer Class
```lua
mod.hooks:wrap("bettermenus.battle_backdrop", function(next, ctx)
  if ctx.kind == "trainer" and ctx.trainerClass == "OPP_BROCK" then
    return "mypack_pewter_arena"
  end
  return next(ctx)
end)
```

### By Wild Pokémon Species
```lua
mod.hooks:wrap("bettermenus.battle_backdrop", function(next, ctx)
  if ctx.kind == "wild" and ctx.species == "MEW" then
    return "mypack_celestial_sanctuary"
  end
  return next(ctx)
end)
```

### For Surfing or Fishing
```lua
mod.hooks:wrap("bettermenus.battle_backdrop", function(next, ctx)
  if ctx.surfing or ctx.fishing then
    return "mypack_ocean_waves"
  end
  return next(ctx)
end)
```

---

## 7. Shadow Styling Recipes

In `bb.backdrop.registerArtistScene(id, { shadows = { ... } })`, customize how shadows look against your surface.
`color` accepts array format `{ r, g, b }` or named map format `{ r = ..., g = ..., b = ... }` with component values from `0.0` to `1.0`. Numeric strings (e.g. `"0.85"`, `"-2"`) are accepted across all numeric fields and normalized automatically:

### Sunset / Warm Earth
```lua
shadows = {
  color = { 0.45, 0.32, 0.18 },
  opacityScale = 0.85,
}
```

### Water Surface (Blue Tint + Softer)
```lua
shadows = {
  color = { 0.05, 0.15, 0.30 },
  opacityScale = 0.70,
  offsetY = 1.5,
}
```

### Dark Cave / Midnight
```lua
shadows = {
  color = { 0.10, 0.05, 0.15 },
  opacityScale = 0.60,
}
```

### Weightless Space / Void (No Ground Shadows)
```lua
shadows = {
  enabled = false,
}
```

---

## 8. Elevated Arena Ledges (High Cliffs & Podiums)

When your artwork features uneven ground—such as an elevated mountain ledge, a gym leader's podium, or a sunken water trench—you can shift the Pokémon vertically so they stand naturally on the terrain:

```lua
bb.backdrop.registerArtistScene("gym_misty_pool", {
  image = "assets/misty_pool_320.png",
  enemyOffsetY = -8,   -- Enemy stands on the high diving platform (-8px up)
  playerOffsetY = 4,   -- Player stands near the lower shoreline (+4px down)
  shadows = {
    color = { 0.05, 0.15, 0.30 },
    opacityScale = 0.70,
    offsetY = 1,       -- Shadow-only contact adjustment (does not move Pokémon)
  }
})
```

> [!TIP]
> **Unified Ground-Plane Movement**:
> - `playerOffsetY` / `enemyOffsetY`: Shifts the Pokémon battler sprite, its attached HUD status box, and its ground shadow together in lockstep.
> - `offsetY` inside `shadows`: Minor shadow-only contact anchor adjustment (for tuning the shadow contact point against complex feet art).
>
> These offsets are included by the built-in BetterBattle UI geometry. If a custom geometry provider owns positioning, it must incorporate `bb.backdrop.effectiveGroundOffsets(battle)` into its ground lines/shifts.

---

## 9. Mid-Battle Arena Transformations

If your mod includes multi-phase boss fights, scripted terrain changes (e.g. Earthquake breaking the floor), or dynamic weather transitions, you can change the active backdrop mid-battle:

```lua
-- Change active scene with a smooth crossfade and elevation lerp:
bb.backdrop.setScene(battle, "boss_phase2_ruins", {
  transition = "crossfade", -- "crossfade", "flash", or "cut"
  duration = 0.5,           -- seconds
  geometry = "lerp",        -- "immediate" (default), "lerp", or "after"
})

-- Or re-run the hook using captured encounter context (inspect ctx.battle for live state):
bb.backdrop.refresh(battle, { transition = "flash" })
```

### Transition Geometry Timing
- **Height changes** (cliffs, platforms, podiums, elevators): Use `transition = "crossfade"` with `geometry = "lerp"`. The Pokémon and shadows smoothly glide between heights in sync with the visual dissolve.
- **Hard scene jumps**: Use `transition = "cut"` or `"flash"`.
- **Same-height transitions**: Use the default `geometry = "immediate"`.

---

## 10. Advanced Integration & Next Steps
 
For additional public integration options:
- See [BetterBattle pixel-art backdrops](https://github.com/syybott/Gen1Better/wiki/Battle-Backdrops) for the 63 built-in scene IDs and automatic matching rules.
- See [Provider and mod compatibility](https://github.com/syybott/Gen1Better/wiki/Compatibility) for dynamic per-frame shadow hooks (`bettermenus.battle_shadow`), Fakemon registration, and renderer ownership.

> [!NOTE]
> **Public integration**: Use the documented registration helpers, hooks, and shadow configuration when building an artist pack. Check availability and handle each method's documented return.
