# Artist Backdrop Pack Quickstart

Your backdrop sets the mood before the first move: a quiet route at sunset, a cave lit by strange crystals, or an arena that belongs to a particular trainer

BetterBattle lets you bring that artwork into a separate mod. You choose the image, the encounter where it appears, and the shadows that tie the Pokémon to the ground.

You only need three safe doors:

1. **“Here is my 320×180 image”**
2. **“Here is when it should appear”**
3. **“Here is how shadows should look on it”**

Start with the template below. You can adapt it yourself or ask an AI agent to read Gen1Better's consumer instructions and help with the setup.

---

## 1. The Hard Wall: Strictly 320×180 PNGs

Export your background as a fully opaque **320×180 PNG**. Fill the whole canvas, including areas that look white; transparent holes reveal the space behind your artwork.

This is the shared battle backdrop size. At full 16:9 1080p and 4K viewport sizes, each painted pixel becomes a 6×6 or 12×12 block of screen pixels. Other window sizes can use a different scale, so check the sizes you want to support.

---

## 2. Run the Validator First

The artwork checker helps catch export mistakes before you package the scene. Install its dependencies once, then run it on your PNG:

```bash
python -m pip install Pillow NumPy
python tools/verify_backdrop.py assets/my_scene_320.png
```

Read the result as **PERFECT**, **PASS**, **WARN**, or **FAIL**. A warning points to something worth inspecting in the artwork; a failure reports an issue to correct before packaging. Backdrop exports must be fully opaque 320×180 PNGs. The checker reports detected export problems; its guide explains the current inspection limits.

For stricter checks, optional high-resolution comparisons, and an explanation of the measurements, see [Backdrop Artwork Checker guide](https://github.com/syybott/Gen1Better/wiki/Backdrop-Artwork-Checker)

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

Copy this into `main.lua`. The template waits until the game is ready, registers your image and shadow style, and chooses it for Route 1. Start by changing the image path and the shadow colors.

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

The `mod` at the end of registration tells BetterBattle that the image belongs to your pack. Keep it in your template.

Registering an image makes it available. The encounter hook decides when to use it. In this example, `ROUTE_1` is the location and `my_artist_sunset_route` is the name the template gives your scene.

---

## 5. Scene ID Rules & Collision Protection

Give each scene a name beginning with your pack's name, such as `mypack_sunset`. That makes it easy to recognize and helps separate it from another artist's work.

Keep Gen1Better's built-in scene names for its own artwork. To change what appears in a location, register your own scene and choose it through the encounter hook. The template checks registration before letting the hook select it.

If registration reports a problem, keep the reported reason: it may identify a name already owned by another pack or a shadow value that needs correcting. The [registration contract](https://github.com/syybott/Gen1Better/wiki/Compatibility#registering-new-custom-320180-scenes) lists exact results and validation rules.

---

## 6. Encounter Trigger Recipes

Choose the recipe that matches your idea, then adapt the encounter hook in the template. Register the named scene first, keeping the template's registration check.

Each recipe reads a detail about the encounter—its location, trainer, Pokémon, or water activity—and chooses your scene. `next(ctx)` keeps the other backdrop choices available when your recipe does not match.

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

Think of shadows as part of the artwork's lighting. Start with one of these recipes and adjust it to suit your scene.

Replace the `shadows` block in the quickstart with the recipe you want. `color` uses red, green, and blue values from 0 to 1. `opacityScale` is a strength multiplier: smaller values make the shadow fainter. `offsetY` makes a small shadow-only contact adjustment.

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
}, mod)
```

Use a negative ground offset to lift a battler and a positive one to lower it. The example lifts the opponent 8 pixels and lowers the player 4 pixels; `shadows.offsetY` adjusts only the shadow's contact.

These ground offsets work with the built-in BetterBattle UI geometry. A mod that supplies its own battle geometry must apply the same offsets; the [geometry contract](https://github.com/syybott/Gen1Better/wiki/Compatibility#5-battle-presentation-geometry) explains that integration.

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
- **Hard scene jumps**: Use `transition = "cut"` or `"flash"`
- **Same-height transitions**: Use the default `geometry = "immediate"`

---

## 10. Advanced Integration & Next Steps
 
For additional public integration options:

- See [BetterBattle pixel-art backdrops](https://github.com/syybott/Gen1Better/wiki/Battle-Backdrops) for the 63 built-in scene IDs and automatic matching rules
- See [Provider and mod compatibility](https://github.com/syybott/Gen1Better/wiki/Compatibility) for dynamic per-frame shadow hooks (`bettermenus.battle_shadow`), Fakemon registration, and renderer ownership

> [!NOTE]
> **Public integration**: Use the documented registration helpers, hooks, and shadow configuration when building an artist pack. Check availability and handle each method's documented return.
