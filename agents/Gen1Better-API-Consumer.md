# Gen1Better Agent Guide for API Consumers

This guide is for AI agents helping artists and mod developers build mods and tools that consume Gen1Better.

Use it when creating or modifying a consuming mod, scene, battle presentation, actor, shadow configuration, provider, or authoring tool. Consumers may use **Gen1Better public APIs** and **Gen1Recomp public APIs**, but they **do not modify, extend, or patch either platform**. All code and assets must live strictly within the consuming mod or tool.

## What Gen1Better is

Gen1Better is a higher-level **16:9 widescreen (`320×180` native canvas)** presentation and authoring layer built on top of Gen1Recomp.

- **Gen1Recomp** provides the recompiled game, mod runtime, and public `mod.*` APIs.
- **Gen1Better** (`gen1-better-menus`) provides reusable public APIs, hooks, and configuration surfaces for richer battles, scenes, actors, shadows, transitions, sequences, and custom presentation.
- **Your consuming mod or tool** uses Gen1Better's public presentation APIs alongside Gen1Recomp's public APIs without modifying either platform.

Gen1Better's presentation target is strictly **16:9 widescreen at `320×180` native resolution** (chosen because `180` scales by exact integer factors to 720p `4×`, 1080p `6×`, 1440p `8×`, and 4K `12×` with nearest-neighbor pixel clarity). Do not author Gen1Better scenes, backdrops, or stage coordinates for the original Game Boy `160×144` (10:9) viewport.

Gen1Better and Gen1Recomp have distinct responsibilities. Use Gen1Better for presentation, staging, backdrops, HUD integration, and shadows; use Gen1Recomp public APIs for game rules, world/battle queries, events, and mod lifecycle hooks.

## Acquiring Gen1Better's exports

Declare `"gen1-better-menus"` in your mod's manifest dependencies (and check the handle version when relying on a specific exported API shape), then acquire its public exports through Gen1Recomp's inter-mod lookup:

```lua
local handle = mod.find("gen1-better-menus")
local exports = handle and handle.exports
```

From `exports`, access the public subsystems:

- `exports.betterBattle` (including `exports.betterBattle.backdrop`, `exports.betterBattle.shadowSettings`, and `exports.betterBattle.shadowEngine`)
- `exports.betterScenes`

Do not reach into global tables, internal file paths, or engine internals to locate Gen1Better.

## Start with the public Gen1Better surface

For every request, first identify the Gen1Better capability that expresses the desired result.

Use this order:

1. Gen1Better public API.
2. Gen1Better provider or hook (`mod.hooks:wrap`).
3. Gen1Better schema, configuration, or preset.
4. Documented callbacks or extension fields in the owning Gen1Better subsystem.
5. Gen1Recomp public APIs (`mod.hooks`, `mod.events`, `mod.world`, `mod.battle`, `mod.assets`) when the behavior belongs to game logic, runtime events, or state outside presentation.

Translate implementation-shaped requests into public presentation concepts before writing code.

For example:

- “Move the enemy upward in this layout” means “register a battle geometry provider, configure scene ground offsets (`playerOffsetY` / `enemyOffsetY`), or wrap `bettermenus.battle_geometry` with `mod.hooks:wrap`.”
- “Put this character on the left side of the scene” means “configure a `BetterScenes` actor slot or transform.”
- “Make the sprite feel grounded” means “configure a `BetterShadows` profile, scene shadow config, or context/instance override.”
- “Switch from a scene into a battle” means “use the `BetterScenes` battle handoff API (`prepareBattleHandoff` / `resumeFromBattle`).”

Do not copy internal renderer offsets, monkey-patch draw functions, or reproduce internal battle-positioning formulas in a consuming mod. Stay on the documented public APIs of Gen1Better and Gen1Recomp.

## Choose the owning subsystem

### BetterScenes

Use BetterScenes (`exports.betterScenes`) for 16:9 widescreen (`320×180` stage canvas) narrative or staged presentation, including:

- scene composition;
- actors and arbitrary actor images;
- actor position, scale, mirroring, and origin settings;
- camera and stage presentation;
- transitions and environmental effects;
- scripted sequences;
- story presentation;
- handoff into and return from battle.

Prefer scene and actor configuration over custom drawing code. Keep scene-specific choices in the scene/actor configuration so they remain declarative and maintainable.

### BetterBattle

Use BetterBattle (`exports.betterBattle`) for 16:9 widescreen (`320×180` native canvas) battle presentation, including:

- battle backdrops and mid-battle arena transitions (`betterBattle.backdrop`);
- battle HUD integration;
- battle-specific presentation and transitions;
- battle actor geometry and ground-plane offsets;
- battle presentation and geometry providers;
- alternate battle layouts.

Battle UI and battle geometry are separate capabilities. Do not assume that changing the HUD automatically changes actor placement, ground planes, scale, clipping, or coordinate space. Use the documented battle geometry or backdrop offset APIs for the behavior you want.

### BetterShadows

Use BetterShadows (`betterBattle.shadowSettings`, `betterBattle.shadowEngine`, and `bettermenus.battle_shadow`) for reusable shadow behavior, including:

- automatic image/contact detection;
- calibrated profiles when a profile exists;
- manual anchor and contact adjustments;
- custom or authored shadow shapes;
- compound rings;
- dynamic or wing behavior;
- scale, rotation, mirroring, offsets, opacity, color tint, and enable/disable settings;
- scene, context, profile, and instance overrides.

Do not implement a separate shadow algorithm in a consuming mod when the requested behavior belongs to BetterShadows. Configure BetterShadows through its public APIs, profiles, overrides, and hooks instead.

## BetterShadows works for arbitrary objects

BetterShadows is general-purpose. It is not limited to Pokémon battle sprites.

It can be used for Pokémon, trainers, birds, trees, desks, props, Fakemon, custom sprites, and other actor images. A Pokémon profile is one convenient preset path, not a requirement for using the shadow system.

An arbitrary-object workflow looks like this:

```text
actor image
→ automatic detection
→ optional manual adjustment or custom shape
→ actor/source transform
→ scene or battle placement
→ rendered shadow
```

An object does not need to be presented as a Pokémon or assigned a species merely to receive a shadow.

When a calibrated profile is useful, the workflow is:

```text
profile or species
→ calibrated preset
→ context-specific override, if any
→ actor/instance override, if any
→ actor/source transform
→ scene or battle placement
→ rendered shadow
```

The original-151 calibrated profiles are shared presets available when applicable. They are defaults that save work, not mandatory final art direction. A custom sprite, unusual pose, or artist preference in your mod may override them.

## Keep these concepts separate

Do not use one field or concept to mean several different things.

### Context

Context selects which presentation-specific override table applies. Supported contexts are:

- `player`;
- `enemy`;
- `scene`.

A scene actor uses the `scene` context even if it is mirrored. A mirrored actor does not become a `player` actor merely because its image is flipped.

Context resolution follows this hierarchy:

```text
matching context override
→ shared profile/species value
→ default value
```

Contexts are siblings and never inherit from one another. A `scene` actor will never inherit `player` or `enemy` overrides.

### Source transform

Mirroring, scale, rotation, and image dimensions describe how the source image is presented. They are distinct from context selection.

When a sprite is horizontally mirrored, X-dependent geometry mirrors automatically while Y/contact geometry and scalar properties remain unchanged according to the API contract. Rely on the provided transform behavior; do not manually negate values a second time.

### Coordinate space

Gen1Better's widescreen stage and backdrop canvas is `320×180` (16:9). Use the API's explicit coordinate-space fields (`coordinateSpace = "field"` or `"native"`) and documentation. Do not infer coordinate meaning from incidental values such as a zero offset, a `stock` flag, a `nativeBlit` flag, or the identity of another mod.

When your mod supplies geometry via a provider or hook, always declare the required `coordinateSpace`, `playerGround`, and `enemyGround` fields explicitly.

### Stage and battle placement

BetterShadows controls shadow shape, grounding, and contact offsets (`shadows.offsetY`). BetterBattle and BetterScenes control where the actor and its ground plane sit on screen (such as arena ledge offsets `playerOffsetY` / `enemyOffsetY` in `registerArtistScene`, or actor `(x, y)` feet origins in `BetterScenes`).

Use ground-plane or actor placement settings when the sprite, HUD panel, and shadow should move together; use shadow-specific offsets when only the shadow contact point should move.

## Use profiles as defaults, not restrictions

If a standard Pokémon profile matches your artwork, use it and override only what your scene or battle requires.

If the artwork is custom or the profile does not fit:

- use automatic detection;
- add manual anchor/contact adjustments;
- provide authored or custom shapes (`addShape`);
- adjust scale, rotation, mirroring, offsets, opacity, or enablement;
- use a `scene`, `player`, `enemy`, or actor-instance override where the change is local.

Do not overwrite shared species-level profile data merely to solve a single scene or single actor presentation choice. Put every override at the narrowest level (instance, scene, or context) that accurately describes its scope.

## Providers and hooks

When Gen1Better exposes a provider or hook (`bettermenus.battle_backdrop`, `bettermenus.betterbattle_provider`, `bettermenus.battle_shadow`, `bettermenus.battle_geometry`, `bettermenus.ui_scale`), register a provider or wrap the hook via `mod.hooks:wrap(...)` in your mod rather than trying to replace subsystem internals.

A well-behaved provider or hook handler in a consuming mod:

- declares what capability it provides;
- returns the documented semantic data shape (or calls `next(ctx)` to delegate);
- supplies explicit coordinate-space and mandatory geometry fields when providing geometry;
- respects priority ordering and unregisters cleanly when no longer needed;
- avoids depending on unrelated UI state;
- queries public resolution/diagnostic APIs (`getBattleGeometry`, `effectiveGroundOffsets`, `diagnostics`) rather than inspecting private tables of other mods.

Preserve explicit `false` values where the contract gives `false` distinct meaning (for example, returning `false` from `bettermenus.battle_backdrop` to request a plain battle background, or `false` from `bettermenus.battle_shadow` to suppress a shadow shape). Do not treat `false` as equivalent to `nil`.

## Artist-facing configuration and validation

Use the documented registration and validation functions (`registerArtistScene`, `registerScene`, `validateSceneConfig`, `setScene`, `refresh`).

- **16:9 (`320×180`) artwork requirement**: All 2D battle backdrops and full-stage scene images must be `320×180` pixels (16:9 aspect ratio). Non-`320×180` backdrop images are rejected at registration.
- **Representation and types**: Follow the public contract for field types. `registerArtistScene` and `validateSceneConfig` accept numeric strings (such as `"0.85"` or `"-4"`) for numeric fields and normalize them automatically, while boolean fields like `shadows.enabled` strictly require a real boolean (`true` or `false`).
- **Custom metadata**: You may include custom extension keys inside a scene's `shadows` table; `validateSceneConfig` preserves unrecognized keys so your own hooks or tools can read them back via `shadowSettings.sceneConfig(sceneId)`.
- **Atomic error handling**: Registration and transition functions return `(true, result)` on success or `(false, err)` on validation/collision/reservation failure. Always check the returned tuple and surface or handle errors cleanly rather than assuming registration succeeded.

## Working within the public API boundary

Consuming mods and tools must never modify Gen1Better (`gen1-better-menus`) or Gen1Recomp platform files.

If a requested feature is not covered by a single Gen1Better preset or helper:

1. **Combine Gen1Better building blocks**: Compose scene configs, per-context shadow overrides, `bettermenus.*` hooks (`mod.hooks:wrap`), geometry providers, sequence `call` steps, or opt-in custom actor scaling (`scaleMode = "custom"` with `customDraw`).
2. **Combine with Gen1Recomp public APIs**: Use Gen1Recomp's `mod.hooks`, `mod.events`, `mod.world`, `mod.battle`, `mod.assets`, and other documented public APIs alongside Gen1Better.
3. **Report true boundaries clearly**: If a requested behavior genuinely cannot be achieved through the combination of Gen1Better public APIs and Gen1Recomp public APIs, explain the limitation clearly to the user and offer the closest supported alternative. Never edit platform source files or monkey-patch internal local state to force an unsupported behavior.

## Guidance for AI agents

Before writing code in a consuming mod, answer:

- What presentation or gameplay result is the user asking for?
- Which Gen1Better subsystem (`BetterScenes`, `BetterBattle`, `BetterShadows`) or Gen1Recomp public API owns that result?
- Which public API functions, providers, hooks (`mod.hooks:wrap`), events (`mod.events:on`), or presets express it?
- Which values belong in shared species/scene registrations and which belong in local context or instance overrides?
- Are context (`player` / `enemy` / `scene`), source transform, coordinate space, and stage placement kept separate?
- Are all edits strictly confined to the user's consuming mod or tool?

Read the relevant Gen1Better wiki documentation and public API contracts rather than reverse-engineering internal files. Keep artist-facing explanations in artist-facing terms (actors, stages, backdrops, ledges, profiles, shadows, transforms, providers, and overrides).

## Short decision guide

```text
Need to access Gen1Better from your mod?
    → local handle = mod.find("gen1-better-menus"); local exports = handle and handle.exports

Need a staged actor, dialogue bubble, or cutscene sequence?
    → BetterScenes (exports.betterScenes)

Need battle backdrops, arena ledges, HUD queries, or battle layout?
    → BetterBattle (exports.betterBattle)

Need reusable actor or battle shadow behavior?
    → BetterShadows (betterBattle.shadowSettings / battle_shadow hook)

Need to customize selection, ownership, shadow shapes, or geometry dynamically?
    → Gen1Better provider, mod.hooks:wrap(...), or mod.events:on(...)

Need to change a single actor, side, or scene?
    → use a context (player/enemy/scene) or actor instance override

Need game logic, world/battle state, or assets outside presentation?
    → use Gen1Recomp public APIs (mod.hooks, mod.events, mod.world, mod.battle, mod.assets)

Need something neither Gen1Better nor Gen1Recomp public APIs expose?
    → compose documented hooks/callbacks or report the boundary (never modify Gen1Better or Gen1Recomp)
```

The goal is simple: consuming mods and tools should build rich visual and narrative experiences through the public APIs of Gen1Better and Gen1Recomp while keeping both underlying platforms untouched.
