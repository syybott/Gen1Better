# Artist Backdrop Pack Quickstart

BetterBattle turns Gen 1 widescreen battles into an **artist-pack surface**. As an artist or modder creating battle scenes, you do not need to understand provider ownership, render composition passes, or detector internals.

You only need three safe doors:
1. **“Here is my 320×180 image.”**
2. **“Here is when it should appear.”**
3. **“Here is how shadows should look on it.”**

---

## 1. The Hard Wall: Strictly 320×180 PNGs

All BetterBattle 2D backdrops **must be strictly 320×180 pixels**.

This is not a matter of style or taste; it is a mathematical hard wall. In 16:9 widescreen, 180 is an exact integer factor of every standard modern display height:

- **720p**: $180 \times 4 = 720$ ($320 \times 4 = 1280$) $\to$ **$4\times$ exact integer scale**
- **1080p**: $180 \times 6 = 1080$ ($320 \times 6 = 1920$) $\to$ **$6\times$ exact integer scale**
- **1440p**: $180 \times 8 = 1440$ ($320 \times 8 = 2560$) $\to$ **$8\times$ exact integer scale**
- **4K (2160p)**: $180 \times 12 = 2160$ ($320 \times 12 = 3840$) $\to$ **$12\times$ exact integer scale**

Because BetterBattle renders with nearest-neighbor texture sampling, every single pixel of your artwork scales into an exact, uniform $6\times 6$ square of screen pixels at 1080p and an exact $12\times 12$ square at 4K.

If your image is not $320 \times 180$, it cannot integer scale cleanly—it will shimmer, blur, distort pixel aspect ratios, or fail to load.

---

## 2. Run the Validator First

Before packaging your art, test it using the built-in validator script:

```bash
python tools/verify_backdrop.py assets/my_scene_320.png
```

The validator confirms:
- Dimensions are exactly $320 \times 180$.
- Aspect ratio is strictly 16:9 ($1.\bar{7}$).
- Upscaling to 1080p ($6\times$) and 4K ($12\times$) creates uniform, sharp texel blocks without edge interpolation artifacts.
- Flags any accidental transparency holes that would let the black clear canvas show through.

---

## 3. Mod Folder Layout

Place your mod folder inside Gen1Recomp's `mods/` directory:

```text
mods/
└── my-artist-pack/
    ├── mod.json
    ├── main.lua
    └── assets/
        └── sunset_route_320.png
```

### `mod.json`
```json
{
  "id": "my-artist-pack",
  "name": "My Sunset Route Backdrops",
  "version": "1.0.0",
  "author": "Your Name",
  "description": "Custom sunset battle backdrops for Route 1."
}
```

---

## 4. The Clean Artist Story (`main.lua`)

Copy and paste this into your `main.lua`:

```lua
local mod = ...

-- Resolve BetterBattle safely
local menus = mod.find("gen1-better-menus")
local bb = menus and menus.exports and menus.exports.betterBattle
if not bb then return end

-- Door 1 & 3: Register your image and optional shadow style
local ok, id = bb.backdrop.registerArtistScene("sunset_route", {
  image = "assets/sunset_route_320.png",
  shadows = {
    color = { 0.45, 0.32, 0.18 }, -- warm sunset earth tint
    opacityScale = 0.85,          -- subtle transparency
    offsetY = 0,
  },
}, mod)

-- Door 2: Decide when it appears
mod.hooks:wrap("bettermenus.battle_backdrop", function(next, ctx)
  if ctx.mapId == "ROUTE_1" then
    return "sunset_route"
  end
  return next(ctx)
end)
```

> [!IMPORTANT]
> **Registration vs Display**: `registerArtistScene` only *registers* your art and shadow settings with the engine; it does *not* display it. The `bettermenus.battle_backdrop` hook owns when the scene appears.
>
> This separation is intentional: `bettermenus.battle_backdrop` runs once when the battle is constructed, is cached for that battle, and never re-runs during drawing.

---

## 5. Scene ID Rules & Collision Protection

BetterBattle provides robust safeguards to keep multiple artist packs from stomping each other:
- **Return Contract**: `registerArtistScene` returns `true, id` on success, or `false, err` (`"reserved"` or `"collision"`) on failure.
- **Atomic Validation**: If your `shadows` configuration has an error, the registration fails before committing the image. There are no partial commits.
- **Built-in IDs are reserved**: Attempting to register over built-in scenes (e.g. `"env_route_grass"`, `"boss_giovanni_gym"`) is rejected. If you want to replace what appears on Route 1, return your own custom scene ID from the `bettermenus.battle_backdrop` hook.
- **Stable Mod Ownership**: BetterBattle checks your mod's stable identifier (`mod.id`, `mod.name`, or `mod.path`), ensuring that hot-reloading your mod will cleanly update your art without triggering a false collision error.
- **Quiet Logging**: Collision and reservation warnings are logged exactly once per `{id, mod}` pair to keep console output clean.
- **Best Practice**: Prefix your scene IDs with your mod name or initials (e.g. `mypack_route_1`, `mypack_sunset`).

---

## 6. Encounter Trigger Recipes

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

In `bb.backdrop.registerArtistScene(id, { shadows = { ... } })`, customize how shadows look against your surface:

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

## 8. Advanced Integration & Next Steps

When you need deeper engine control:
- See [BetterBattle pixel-art backdrops](Battle-Backdrops.md) for the 63 built-in scene IDs and automatic matching rules.
- See [Provider and mod compatibility](Compatibility.md) for dynamic per-frame shadow hooks (`bettermenus.battle_shadow`), Fakemon registration, and renderer ownership.
