# BetterScenes: Cinematic Story Cutscenes & Narrative Staging

BetterScenes provides a dedicated 16:9 widescreen story stage (320×180 native integer-scaled pixels) decoupled from combat states in Gen1Recomp. It allows modders and story authors to create narrative cutscenes, character staging, comic dialogue bubbles, camera effects, atmospheric weather, and seamless transitions into battle.

---

## 1. The 320×180 Restomod Hard Wall

All BetterScenes backdrops, actor positions, and atmospheric effects operate within an exact **320×180 canvas coordinate space** before integer-scaling to modern widescreen displays:

- **720p**: $180 \times 4 = 720$ ($4\times$ integer scale)
- **1080p**: $180 \times 6 = 1080$ ($6\times$ integer scale)
- **1440p**: $180 \times 8 = 1440$ ($8\times$ integer scale)
- **4K (2160p)**: $180 \times 12 = 2160$ ($12\times$ integer scale)

Because every visual element is calculated in native 320×180 units with nearest-neighbor integer sampling, artwork retains crisp pixel edges without subpixel blurring, scaling distortion, or mismatched resolutions.

---

## 2. Quickstart: Your First Cutscene

A complete working narrative cutscene in Lua:

```lua
local mod = ...
local betterScenes = mod.find("gen1-better-menus").exports.betterScenes

-- Register custom 320x180 story backdrop:
betterScenes.registerScene("pallet_morning", {
  path = "assets/pallet_morning_320.png",
  underlay = "paper",
}, mod)

-- Choreograph a story sequence:
betterScenes.playSequence({
  -- Fade in the morning scene:
  { action = "show", scene = "pallet_morning", transition = "crossfade", duration = 0.5, wait = true },

  -- Slide Professor Oak onto the stage from the left:
  { action = "actor", slot = "left", path = "assets/oak.png", transition = "slide", duration = 0.4, wait = true },

  -- Oak speaks using an anchored comic bubble:
  { action = "bubble", speaker = "left", text = "Hello there! Glad you could make it." },
  { action = "waitInput" },
  { action = "hideBubble" },

  -- Surprise emote puff over Oak's head:
  { action = "emote", target = "left", type = "exclamation", duration = 1.0, wait = true },

  -- Cinematic letterbox narration at the bottom:
  { action = "subtitle", text = "A mysterious Pokémon cried out in the tall grass..." },
  { action = "waitInput" },
  { action = "clearSubtitle" },

  -- Smoothly clear stage and return screen to player:
  { action = "hide", transition = "crossfade", duration = 0.4, wait = true },
}, {
  skippable = true,
  cleanup = true,
})
```

---

## 3. The 6 Choreography Systems

### 1. Scene Presentation & Underlays

Display full-color 320×180 pixel-art story backdrops or pure solid underlays:

```lua
-- Present an authored image with a crossfade or flash transition:
betterScenes.show("pallet_morning", { transition = "crossfade", duration = 0.5 })

-- Present an active underlay without an image (blackout, psychic void, or palette paper):
betterScenes.show(false, { underlay = "black" })

-- Cleanly exit and return screen ownership to the game:
betterScenes.hide({ transition = "fade", duration = 0.35 })
```

Supported underlays:
- `"black"`: Solid black backing (night, deep caves, space, blackouts).
- `"paper"`: Reactive to the user's selected menu palette paper tone.
- `"transparent"`: Clear outer pass letting underlying world layers remain visible.

Supported transitions:
- `"cut"`: Immediate instant switch.
- `"crossfade"`: Smooth alpha dissolve between scenes or underlays.
- `"flash"`: Momentary high-impact combat whiteout pulse.

---

### 2. Theatrical Actor Staging

Actors are positioned in 320×180 stage space using a bottom-center / feet origin:
- **Feet-based origin $(x, y)$**: Staging an actor at $(80, 150)$ means their feet touch $y = 150$, keeping sprites grounded naturally regardless of height.
- **Preset slots**: Predefined positions for rapid choreography:
  - `"left"`: $(64, 150)$, faces right by default.
  - `"center"`: $(160, 150)$, faces right by default.
  - `"right"`: $(256, 150)$, automatically mirrored to face left.
- **Custom slots**: Define any custom position: `{ x = 120, y = 140, mirror = false, scale = 1.0 }`.
- **Relative anchors**: Define `mouth`, `head`, and `top` relative to the sprite bounds. Anchors automatically mirror and scale with the actor.
- **Transitions**: Enter and exit with `"cut"`, `"fade"`, or directional `"slide"`.

```lua
-- Stage a trainer on the left and a legendary Pokémon on the right:
betterScenes.setActor("left", {
  path = "assets/red.png",
  mirror = false,
  anchors = { mouth = { x = 16, y = 14 }, head = { x = 16, y = 4 } },
}, { transition = "fade", duration = 0.3 })

betterScenes.setActor("right", {
  path = "assets/mewtwo.png",
  mirror = true,
  scale = 1.0,
}, { transition = "slide", duration = 0.5 })

-- Clear an actor from stage:
betterScenes.clearActor("left", { transition = "fade", duration = 0.25 })
```

#### Actor Shadows & Floor Contact

BetterScenes uses the general-purpose Actor Shadow Engine (`schemaVersion = 2`, `profileVersion = 1`) to render floor-contact shadows beneath staged actors. An actor can use an arbitrary image and per-instance shadow configuration without having a species identity. The built-in 151 Pokémon profiles are optional presets.

BetterScenes and BetterBattle share footprint measurement, anchor selection,
profile resolution, authored and detected shape evaluation, dynamic callbacks,
source-space conversion, mirroring, scaling, and shadow rendering. BetterScenes
retains control of actor placement, the effective pose or size variant, transitions,
stage scaling, and draw order.

- **Optional Species Profiles**: Specify `species = "POKEMON_NAME"` (e.g. `"CHARIZARD"` or `"PIKACHU"`) to select shared species-level preset values. Species-level tuning is shared with BetterBattle, while `player`, `enemy`, and `scene` overrides remain presentation-context-specific and never cross-inherit.
- **Explicit Disabling**: Pass `shadow = false` to suppress ground shadows (e.g. for ghosts, levitating psychics, or airborne entities).
- **Custom Shadow Schema**: Pass a configuration table in `shadow = { ... }` to customize shadow dimensions, tint, opacity, or feathering:

For a species-backed actor, each value resolves in this order:

```text
actor instance override
-> species scene override
-> species-level value
-> global default
```

The `scene` table is optional and normally omitted. Use it only when a species
requires cutscene-specific calibration. A BetterScenes actor never inherits
`player` or `enemy` overrides.

| Property | Type | Description | Default |
| :--- | :--- | :--- | :--- |
| `enabled` | boolean | Enable or suppress floor shadow. | `true` (if `shadow` specified) |
| `baseWidth` | number | Baseline ellipse width in virtual pixels. | Measured or species baseline |
| `baseHeight` | number | Baseline ellipse height in virtual pixels. | Measured or species baseline |
| `widthScale` | number | Multiplier applied to base width. | `1.0` |
| `heightScale` | number | Multiplier applied to base height. | `1.0` |
| `offsetX` | number | Horizontal offset from actor feet. | `0` |
| `offsetY` | number | Vertical offset from actor feet contact. | `0` |
| `rotationDegrees` | number | Stance tilt angle in degrees. | `0` |
| `opacity` / `alpha` | number | Base shadow opacity (0.0 to 1.0). | `0.45` |
| `color` | table | Normalized RGB `{ r, g, b }` for environment tinting. | Black (`nil`) |
| `grounding` | string | Stance behavior: `"grounded"`, `"hovering"`, `"floating"`, `"flying"`. | `"grounded"` |
| `sourceSpace` | table | Optional coordinate space `{ width, height, originX, originY }` for source-authored instance data. | Effective image dimensions |
| `shapeSpace` | string | `"origin"` for actor-relative instance shapes or `"source"` for source-image coordinates. | `"origin"` for instance shapes |
| `wingShadows` | table | Array of wing regions `{ region = { left, right, top, bottom }, opacity = 0.05 }`. | `nil` |
| `shadowShapes` | table | Explicit custom shapes (`{ width, height, offsetX, offsetY, alpha, color, ... }`). | `nil` |
| `innerRing` | table | Core dark contact ring `{ scaleX, scaleY, offsetX, offsetY, alpha }`. | Automatic |
| `middleRing` | table | Mid-feathering ring `{ scaleX, scaleY, offsetX, offsetY, alpha }`. | Automatic |
| `soft` | boolean | Enables cosine multi-ring soft edge feathering. | `true` |

#### Staging Coordination & Physics
- **Floor Contact**: Shadows are anchored directly to the actor's feet coordinates `(x, y)` in 320×180 stage space.
- **Mirror Tracking**: When an actor is mirrored (`mirror = true`), the shadow's horizontal offsets and tilt angles invert automatically.
- **Scale Tracking**: When an actor scales (`scale = 1.5`), all shadow dimensions, inner rings, and limb offsets scale in exact proportion.
- **Alpha Dissolves**: During actor enter/exit fades (`transition = "fade"`), the shadow smoothly dissolves in unison with the sprite's opacity (`currentAlpha`).
- **Camera Trauma**: Stage camera shake (`shakeScreen`) moves the shadow in perfect lockstep with the character and stage floor.
- **Pre-Actor Render Pass**: Contact shadows are drawn immediately before actors in stage composition, guaranteeing that the character's feet naturally occlude the ground shadow.

```lua
-- Stage a grounded Pokémon inheriting calibrated species shadow:
betterScenes.setActor("left", {
  path = "assets/charizard.png",
  species = "CHARIZARD",
  shadow = true,
}, { transition = "slide", duration = 0.4 })

-- Stage a human trainer with custom-authored shadow:
betterScenes.setActor("center", {
  path = "assets/red.png",
  shadow = {
    baseWidth = 24,
    baseHeight = 6,
    offsetY = 1,
    opacity = 0.4,
  },
})

-- Stage an ethereal ghost with shadows suppressed:
betterScenes.setActor("right", {
  path = "assets/gengar.png",
  shadow = false,
}, { transition = "fade", duration = 0.5 })
```

#### Sprite Scaling, LOD Variants & Motion Stability

Arbitrary fractional downscaling of retro pixel art with nearest-neighbor filtering causes pixel lines to drop out, line weights to warp, and sprites to crawl/shimmer in motion. BetterScenes provides a robust, multi-path scaling subsystem giving artists complete control over visual fidelity:

##### The Two Rendering Paths
1. **Recommended Pixel-Art Path**:
   `Variant LOD > Clean Canvas > Nearest`
   - **Variant LOD (`scaleMode = "variant"` or `"auto"`)**: Hand-authored smaller sprites (e.g. 28×28 for 56×56 originals). Real pixel art hand-drawn for target resolutions will always beat algorithmic downscaling.
   - **Clean Canvas (`scaleMode = "clean"`)**: Pre-renders the sprite down to an integer target canvas once with nearest-neighbor sampling. Eliminates per-frame resampling jitter and pixel crawling during motion while preserving hard retro outlines.
   - **Nearest (`scaleMode = "nearest"`)**: Raw GPU nearest-neighbor transform. Best for 1:1 scale or integer upscaling.
2. **Optional Smoothing Path**:
   `Variant LOD > Area Canvas > Nearest`
   - **Area Canvas (`scaleMode = "area"`)**: Downsamples into an integer canvas using linear texture sampling. Yields smoother texel averaging for significant shrinking, but may soften retro pixel outlines. Area mode is an explicit opt-in and is never selected automatically.

##### Escape Hatch: Custom Draw Hook
- **Custom (`scaleMode = "custom"`)**: Invokes `actor.customDraw` or `actor.scaleFn` callback.
- **Strict Gating**: Custom callbacks are strictly called *only* when `effectiveScaleMode == "custom"`. Attaching a callback to an actor will never alter rendering in `"auto"` or other modes.
- If the callback returns `true`, BetterScenes assumes the hook drew the actor. If it returns `false` or `nil`, it falls back to `actor.fallbackScaleMode` (default `"nearest"`).

##### Supported `scaleMode` Values
| Mode | Behavior | Best Use Case |
| :--- | :--- | :--- |
| `"auto"` | Checks matching variant LOD $\to$ clean canvas $\to$ nearest fallback | Recommended default for smart actors |
| `"variant"` | Strictly resolves hand-authored LOD assets; falls back to clean/nearest if none match | Staging key characters with mini sprites |
| `"clean"` | Cached integer canvas downscale with nearest filtering (downscale only) | Quick shrink without per-frame shimmer |
| `"area"` | Cached integer canvas downscale with linear filtering (downscale only) | Optional smoother shrink with softened outlines |
| `"nearest"` | Direct GPU transform with nearest-neighbor sampling | Default retro behavior / 1:1 scale |
| `"custom"` | Invokes `actor.customDraw` / `actor.scaleFn` callback | Engine / modder escape hatch |

##### Actor Definition with LOD Bands
Define `variants` as threshold bands (`maxScale` ascending). When downscaling, BetterScenes chooses the best matching variant:

```lua
betterScenes.setActor("oak", {
  path = "assets/oak.png",      -- Base 56×56 sprite
  scale = 1.0,
  scaleMode = "auto",            -- Smart path: variant -> clean -> nearest
  pixelSnap = true,              -- Integer-snapped drawing prevents edge shimmer
  fallbackScaleMode = "nearest", -- Fallback if customDraw returns nil in custom mode

  -- Defined as LOD threshold bands:
  variants = {
    { maxScale = 0.55, path = "assets/oak_mini.png",   nativeScale = 0.5 },  -- 28×28 asset
    { maxScale = 0.85, path = "assets/oak_medium.png", nativeScale = 0.75 }, -- 42×42 asset
  },
})
```

##### In-Place Actor Updates & Sequence Actions
Actors can be updated in-place without re-specifying paths or images:

```lua
-- In Lua scripts:
betterScenes.updateActor("oak", { scale = 0.5 })                        -- Uses mini variant via auto
betterScenes.updateActor("oak", { scale = 0.65, scaleMode = "clean" })  -- Forces clean canvas

-- In declarative cutscene sequences:
{ action = "actor", slot = "oak", scale = 0.5 },
{ action = "updateActor", slot = "oak", scale = 0.65, scaleMode = "clean" },
```

##### Position Snapping & Shadow Synchronization
- **`pixelSnap = true`** (default `true`): Snaps final screen coordinates to whole pixels (`math.floor(screenX + 0.5)`). Prevents subpixel edge shimmering as actors move or walk across the stage.
- **Displayed Dimension Shadows**: Shadow sizing uses displayed dimensions (`resolved.image:getWidth() * math.abs(resolved.sx)`), ensuring shadow contact remains identical across variant, canvas, and nearest renders.
- **Downscale-Only Rule**: Canvas allocation only occurs when shrinking (`requestedScale < 1.0` and `tw <= iw and th <= ih and (tw < iw or th < ih)`). Never allocates upscaled canvases.
- **Cache Management**: The internal canvas cache is capped at 128 entries with automatic FIFO eviction. Use `betterScenes.clearScaleCache()` or `betterScenes.setScaleCacheLimit(max)` for manual control.

---

### 3. Comic Dialogue Bubbles, Subtitles & Emotes

#### Anchored Comic Bubbles
Dynamic dialogue balloons (`speech`, `thought`, `shout`) track the speaker's mouth anchor in real-time. The bubble body is clamped safely inside stage margins ($[4, 4, 316, 176]$) while the tail points accurately to the character's mouth:

```lua
-- Speech bubble tracking Oak's mouth:
betterScenes.showBubble("left", "It's dangerous to go alone!", { style = "speech" })

-- Thought cloud above a Pokémon:
betterScenes.showBubble("right", "...Where did they go?", { style = "thought" })

-- High-impact jagged shout balloon:
betterScenes.showBubble("left", "STOP RIGHT THERE!", { style = "shout" })

-- Narrator box centered without a tail:
betterScenes.showBubble("narrator", "Meanwhile, deep in the Viridian Forest...")
```

#### Cinematic Subtitles
Widescreen letterbox subtitles for narration and ambiance:

```lua
-- Bottom letterbox subtitle with backdrop bar:
betterScenes.setSubtitle("Deep inside the ruins, a strange energy pulses.", {
  position = "bottom",
  bar = true,
  color = { 1, 1, 1, 1 },
})

-- Clear subtitle:
betterScenes.clearSubtitle({ transition = "fade", duration = 0.3 })
```

#### Floating Reaction Emotes
Animated floating puffs that bounce dynamically above an actor or coordinate:

```lua
-- Surprise exclamation over Oak:
betterScenes.showEmote("left", "exclamation", { duration = 1.5 })

-- Confused question over player:
betterScenes.showEmote("center", "question")

-- Emote types: "exclamation", "question", "heart", "anger", "sweat", "dots", "music"
```

---

### 4. Declarative Story Sequence Runner

Choreograph complex cutscenes using an ordered array of timeline steps:

```lua
betterScenes.playSequence({
  { action = "show", scene = "gym_scene", transition = "crossfade", duration = 0.5, wait = true },
  { action = "actor", slot = "left", path = "assets/leader.png", transition = "fade", wait = true },
  { action = "bubble", speaker = "left", text = "So, you've finally arrived." },
  { action = "waitInput" },
  { action = "hideBubble" },
  { action = "emote", target = "left", type = "anger", duration = 1.0, wait = true },
  { action = "shake", intensity = 4, duration = 0.4, wait = true },
  { action = "bubble", speaker = "left", text = "Show me what you've learned!", style = "shout" },
  { action = "waitInput" },
  { action = "hideBubble" },
}, {
  skippable = true,
  cleanup = true,
  onComplete = function(api)
    -- Cutscene finished cleanly
  end,
})
```

#### Sequence Action Summary
| Action | Description | Blocking Option |
| :--- | :--- | :--- |
| `show` / `hide` | Present or clear story backdrops and underlays | `wait = true` |
| `actor` / `clearActor` | Stage or remove cast characters | `wait = true` |
| `bubble` / `hideBubble` | Display or hide anchored dialogue balloons | Instant |
| `subtitle` / `clearSubtitle` | Display or clear widescreen letterbox narration | Instant |
| `emote` / `clearEmote` | Display or clear animated reaction puffs | `wait = true` |
| `shake` / `stopShake` | Trigger or stop deterministic camera trauma | `wait = true` |
| `flash` / `stopFlash` | Momentary combat strobe pulse | `wait = true` |
| `tint` / `clearTint` | Apply or clear ambient color grading | `wait = true` |
| `vignette` / `clearVignette` | Apply or clear framing masks | `wait = true` |
| `weather` / `clearWeather` | Atmospheric retro particle simulation | Instant |
| `battle` | Transition into combat and halt sequence until battle ends | Blocking |
| `wait` | Timed pause `{ action = "wait", duration = 0.75 }` | Blocking |
| `waitInput` | Player button barrier (`A` / `Space`) `{ action = "waitInput" }` | Blocking |
| `call` | Execute custom callback `{ action = "call", fn = function(api, seq) ... end }` | Instant |

---

### 5. Stage FX & Camera Dynamics

Effects run in 320×180 space before scaling, preserving the crisp pixel-art restomod aesthetic:

```lua
-- Deterministic screen shake (UI decoupled so dialogue remains rock-solid):
betterScenes.shakeScreen({ intensity = 5, duration = 0.5, direction = "both", pixelSnap = true })

-- Full-stage ambient color tint (smooth fade):
betterScenes.setTint("sunset", { duration = 0.6 })
-- Presets: "sunset", "night", "cave", "underwater", "poison", "sepia", or custom { r, g, b, a }

-- Momentary combat strobe pulse:
betterScenes.flashScreen({ 1, 1, 1, 1 }, { duration = 0.3, mode = "out", scope = "stage" })

-- Cinematic framing vignette:
betterScenes.setVignette("letterbox", { height = 20, duration = 0.4 })
-- Styles: "letterbox", "spotlight" (focuses on coordinate/slot), "dither" (Bayer pattern border fade)

-- Atmospheric retro weather particles:
betterScenes.setWeather("rain", { count = 30, speed = 1.2 })
-- Types: "rain", "snow", "leaves", "cherry_blossom", "embers", "dust"
```

---

### 6. Decoupled Battle Handoff & Resumption

Transition seamlessly from a narrative cutscene directly into combat (`BetterBattle`), preserving scene atmosphere into the arena, and unblocking the cutscene when battle concludes:

```lua
betterScenes.prepareBattleHandoff({
  battleType = "trainer",
  trainerId = "giovanni",
  storySceneId = "cutscene_gym_interior",
  battleBackdropId = "boss_giovanni_gym",
  transition = "swirl",
  duration = 0.8,
  onHandoff = function(token)
    -- BetterBattle starts combat with the token's parameters
  end,
  onWin = function(api, result)
    -- Play victory dialogue after winning:
    api.showBubble("left", "Impressive. You have earned my respect.")
  end,
  onLose = function(api, result)
    -- Handle defeat dialogue or story branch:
    api.showBubble("left", "Return when you are truly ready.")
  end,
})

-- When battle ends, BetterBattle calls resumeFromBattle:
betterScenes.resumeFromBattle({
  handoffId = "bh_1",
  outcome = "win", -- "win", "lose", "flee", "draw"
})
```

Transitions supported: `"cut"`, `"flash"`, `"blinds"`, `"mosaic"`, `"swirl"`.

---

## 4. Diagnostics & Inspection

Inspect live stage state during development:

```lua
local diag = betterScenes.diagnostics()
print("Stage active:", diag.active)
print("Active scene:", diag.sceneId)
print("Actors count:", diag.actorCount)
print("Sequence step:", diag.sequence and diag.sequence.stepIndex)

-- Query actor shadow telemetry:
local actor = betterScenes.getActor("left")
if actor and actor.shadowState then
  print("Shadow mode:", actor.shadowState.mode)           -- "speciesProfile", "speciesAuto", "customShapes", etc.
  print("Profile ID:", actor.shadowState.profileId)       -- e.g. "CHARIZARD"
  print("Profile Version:", actor.shadowState.profileVersion)
  print("Active shapes:", #actor.shadowState.shapes)
end
```
