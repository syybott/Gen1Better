# BetterScenes: Cinematic Cutscenes

BetterScenes is Gen1Better's 320×180 story stage outside combat. It provides backdrops, actors, shadows, dialogue, sequences, effects, and a callback-based battle handoff. The consuming mod supplies its assets, trigger, update controller, input forwarding, and encounter logic.

## 1. Authoring and display

Author story backdrops at **320×180**. The stage fits the viewport with `min(viewportWidth / 320, viewportHeight / 180)`. At full 16:9 sizes, 720p, 1080p, 1440p, and 2160p correspond to 4×, 6×, 8×, and 12×. Other window sizes can produce fractional scales.

Nearest filtering and pixel snapping preserve hard edges where possible. They do not guarantee uniform integer-sized pixels at every window size. Actors can have arbitrary source-image dimensions; their placement uses the 320×180 stage.

Use `mod.assets:image("assets/scene.png")` or `mod.assets:path("assets/scene.png")` for assets belonging to your mod. `registerScene(..., mod)` uses the mod for ownership and collision checks; it does **not** resolve a bare path relative to that mod. The same rule applies to actor paths and variant paths.

## 2. Quickstart: your first cutscene

Create a standalone mod with your own 320×180 backdrop and actor image:

```text
my-story/
├── manifest.json
├── main.lua
└── assets/
    ├── morning_320.png
    └── guide.png
```

```json
{
  "id": "my-story",
  "name": "My Story",
  "version": "1.0.0",
  "api": 2,
  "entry": "main.lua",
  "dependencies": ["gen1-better-menus"]
}
```

This entry script registers assets after `game.ready` and exports a trigger for your mod to call with its live game. It owns the stage exclusively for the duration of this demo.

```lua
local mod = ...

mod.events:on("game.ready", function()
  local handle = mod.find("gen1-better-menus")
  local scenes = handle and handle.exports and handle.exports.betterScenes
  if not scenes then return end

  local backdrop = mod.assets:image("assets/morning_320.png")
  local guide = mod.assets:image("assets/guide.png")
  local registered, reason = scenes.registerScene("my_story_morning", {
    image = backdrop,
    underlay = "black",
  }, mod)
  if not registered then error("Story scene registration: " .. tostring(reason)) end

  mod.exports.playIntro = function(game)
    if scenes.isActive() then return false, "stage-busy" end
    local controller = { game = game }
    local finished = false

    local function finish()
      finished = true
      scenes.clearActors({ transition = "cut" })
      scenes.hideBubble({ transition = "cut" })
      scenes.clearSubtitle({ transition = "cut" })
      scenes.clearEmote()
      scenes.hide({ transition = "cut" })
      if game.stack:top() == controller then game.stack:pop() end
    end

    function controller:update(dt)
      if finished then
        if game.stack:top() == self then game.stack:pop() end
        return
      end
      local sequence = scenes.getSequence()
      if game.input:wasPressed("b") then
        scenes.skipSequence()
      elseif sequence and sequence.waitingInput and game.input:wasPressed("a") then
        scenes.advanceSequence()
      end
      scenes.update(dt)
    end

    -- Gen1Better draws the active story stage; do not draw it a second time.
    function controller:draw() end

    game.stack:push(controller)
    local ok, result = scenes.playSequence({
      { action = "show", scene = "my_story_morning",
        opts = { transition = "crossfade", duration = 0.4 }, wait = true },
      { action = "actor", slot = "left",
        config = { image = guide, shadow = true },
        opts = { transition = "slide", duration = 0.4 }, wait = true },
      { action = "bubble", speaker = "left", text = "A new journey begins." },
      { action = "waitInput" },
    }, { cleanup = true, onComplete = finish, onAbort = finish })
    if not ok then finish() end
    return ok, result
  end
end)
```

After `game.ready`, invoke your exported `playIntro(game)` from your mod's chosen interaction or event. This example does not automatically run on startup.

Gen1Better supplies drawing when `isActive()` is true. It does not automatically call `update(dt)` or map buttons to advance/skip. Timeline waits, handoff timing, weather, and effects require updates. Some scene and actor transitions also use elapsed wall-clock time during drawing; this does not replace the update controller.

Only forward A to `advanceSequence()` when `waitingInput` is true if A should acknowledge dialogue. That method can also clear a timed wait and advance its step.

## 3. Scene presentation and underlays

```lua
local ok, id = scenes.show("my_story_morning", {
  transition = "crossfade",
  duration = 0.5,
})
scenes.show(false, { underlay = "black" })
scenes.hide({ transition = "crossfade", duration = 0.35 })
```

`show` and `hide` accept **cut**, **crossfade**, or **flash**. Their default transition is cut; a non-cut transition defaults to 0.35 seconds. `fade` is an actor/dialogue transition, not a scene transition.

Underlays are **black**, **paper**, or **transparent**. `current()` returns a scene ID, false for an active underlay, or nil without a current background.

`hide()` clears the background and underlay presentation. It does not clear actors, bubbles, subtitles, emotes, effects, or sequences. Those resources can keep the stage active.

Loaded images with measurable dimensions are checked at registration. Path-based checking depends on the path being readable; registration success alone does not prove that a file exists or will draw correctly. Handle returns and validate assets before distribution.

## 4. Theatrical actor staging

Built-in slots use these feet positions:

| Slot | X | Y | Default mirror |
| --- | --- | --- | --- |
| left | 70 | 155 | false |
| center | 160 | 155 | false |
| right | 250 | 155 | true |

Custom slots require both `x` and `y`. Actor coordinates use the feet/bottom-center origin. Anchors are offsets from this origin, scaled and mirrored with the actor. Default anchors are **top (0, −48)**, **head (0, −36)**, and **mouth (0, −26)**.

```lua
scenes.setActor("guide", {
  image = mod.assets:image("assets/guide.png"),
  x = 70, y = 155,
  scale = 1,
  anchors = { mouth = { x = 0, y = -26 } },
  shadow = { baseWidth = 12, baseHeight = 3.75, opacityScale = 0.8 },
}, { transition = "slide", duration = 0.4 })
scenes.updateActor("guide", { scale = 0.8 })
scenes.clearActor("guide", { transition = "fade", duration = 0.25 })
```

Actors accept **cut**, **fade**, or **slide** transitions. `updateActor` merges changes with an existing actor and delegates to `setActor`. Use its third argument for transition options.

`getActorAnchor(slot, name)` resolves configured actor positions, not interpolated enter/exit positions. Plan dialogue after movement has settled.

### Actor shadows and floor contact

Use `shadow = true` for the shared shadow engine, `shadow = false` to suppress it, or a configuration table for custom dimensions, tint, gain, offsets, shapes, and detector settings. `species = "CHARIZARD"` selects an optional Pokémon preset; human and arbitrary-image actors need no species.

For species-backed actors, a value resolves through **actor override → species scene context → species value → default**. The player, enemy, and scene contexts do not cross-inherit.

The shared defaults include `baseWidth = 12`, `baseHeight = 3.75`, width/height/opacity scales of 1, zero offsets, `grounding = "grounded"`, and `anchorMode = "contact"`. Automatic measurement can adjust the displayed footprint. `anchorMode` supports **contact** and **body**; explicit `manualAnchorX` and `manualContactY` provide source-space calibration. Only **flying** selects special flight behavior; hovering/floating are not distinct implemented modes.

Soft shadows use three ellipse layers, not a cosine falloff. Configure `innerRing` and `middleRing` with **widthScale**, **heightScale**, **offsetX**, and **offsetY**. Ring alpha is fixed by the renderer. Prefer `opacityScale` for gain; `opacity`/`alpha` are optional gain aliases, not a default 0.45 opacity.

Actor-instance source coordinates use the effective image unless `sourceSpace` is specified. Instance shapes default to `shapeSpace = "origin"`; shared species profiles use canonical 56×56 source coordinates. See the [complete shadow schema](https://github.com/syybott/Gen1Better/wiki/Compatibility#unified-shadow-configuration-schema) for shapes, detection sizing, automatic-body policy, and context overrides.

### Sprite scaling and variants

The default scale mode is **nearest** and default pixel snapping is **true**.

| Mode | Behavior |
| --- | --- |
| nearest | Direct nearest-neighbor transform. |
| auto | Select an eligible variant, otherwise clean downscale, otherwise nearest. |
| variant | Try authored variants, then clean/nearest fallback. |
| clean | Cache a nearest-filtered canvas at integer target dimensions when shrinking. |
| area | Cache a linearly sampled canvas when shrinking; can soften pixel edges. This is not a true area-average filter. |
| custom | Call `customDraw` or `scaleFn`; a truthy result claims drawing. Otherwise use `fallbackScaleMode`, default nearest. |

```lua
scenes.setActor("oak", {
  image = mod.assets:image("assets/oak.png"),
  x = 70, y = 155,
  scale = 0.5, scaleMode = "auto", pixelSnap = true,
  variants = {
    { maxScale = 0.55, image = mod.assets:image("assets/oak_mini.png"), nativeScale = 0.5 },
    { maxScale = 0.85, image = mod.assets:image("assets/oak_medium.png"), nativeScale = 0.75 },
  },
})
```

Use ascending `maxScale` bands with the correct `nativeScale` for each asset. Clean canvases and pixel snapping reduce repeated fractional resampling; they do not guarantee that every animation is free of pixel changes.

The scale cache defaults to 128 entries with FIFO eviction. `clearScaleCache()` returns true; `setScaleCacheLimit(n)` accepts a positive numeric limit, floors it, and returns `true, limit`. Invalid limits return `false, "invalid-limit"`.

## 5. Dialogue, subtitles, and emotes

```lua
scenes.showBubble("left", "Welcome!", { style = "speech" })
scenes.showBubble("right", "Where are we?", { style = "thought" })
scenes.showBubble("left", "STOP!", { style = "shout" })
scenes.showBubble("narrator", "Later that evening...")
scenes.setSubtitle("The journey continues.", { position = "bottom", bar = true })
scenes.showEmote("left", "exclamation", { duration = 1.5 })
```

Bubbles can target actor anchors or explicit coordinates. Their tails are refreshed by `getBubble()` using the actor's configured position; drawing does not itself refresh the tail against the actor's interpolated movement. Re-show or reposition a bubble after actor movement when needed.

Subtitle positions are top, bottom, or center. Subtitles accept bar and align, but no color option. For bubbles/subtitles, duration controls how long they remain visible; fade/pop timing is fixed at 0.2 seconds for bubbles and 0.25 seconds for subtitles. Subtitles accept bar and align, but no color option. For bubbles/subtitles, duration controls how long they remain visible; fade/pop timing is fixed at 0.2 seconds for bubbles and 0.25 seconds for subtitles. Bubbles support cut, fade, and pop; subtitles support cut and fade. Emotes include **exclamation**, **question**, **heart**, **anger**, **sweat**, **dots**, and **music**. A sequence emote step does not block on `wait = true`; add an explicit wait to hold the reaction.

## 6. Declarative sequences

A step uses `action` (or its first array entry). Prefer a nested `config` for actor data and `opts` for method options:

```lua
local steps = {
  { action = "actor", slot = "left",
    config = { image = mod.assets:image("assets/guide.png") },
    opts = { transition = "slide", duration = 0.4 }, wait = true },
  { action = "bubble", speaker = "left", text = "Look over there." },
  { action = "waitInput" },
  { action = "emote", target = "left", type = "exclamation", duration = 1 },
  { action = "wait", duration = 1 },
  { action = "clearActors", opts = { transition = "fade", duration = 0.3 }, wait = true },
  { action = "hide", opts = { transition = "crossfade", duration = 0.35 }, wait = true },
}
```

| Actions | Purpose |
| --- | --- |
| show, hide | Background presentation. |
| actor, setActor, updateActor, clearActor, clearActors | Actor staging. Actor transition options must be in `step.opts`. |
| bubble, showBubble, hideBubble | Dialogue. |
| subtitle, setSubtitle, clearSubtitle | Narration. |
| emote, showEmote, clearEmote | Reactions; show steps do not wait automatically. |
| shake, shakeScreen, stopShake | Camera shake. |
| tint, setTint, clearTint | Stage tint. |
| flash, flashScreen | Flash pulses. |
| vignette, setVignette, clearVignette | Vignette. |
| weather, setWeather, clearWeather | Weather. |
| battle | Prepare a handoff and block until `resumeFromBattle`. |
| wait, waitInput | Timed or input barrier. |
| call, fn | Call `fn(api, sequence)` or `callback(api, sequence)`. |

`stopFlash` is a callable API method, not a sequence action. Use `{ action = "call", fn = function(api) api.stopFlash() end }` when a sequence must stop it.

`playSequence` defaults to skippable **true** and cleanup **false**. Starting a new sequence stops the previous one. `cleanup = true` restores tracked resources on abort/stop; it does not automatically clean up on normal completion or skip. Include final cleanup steps or an `onComplete` callback. `onAbort` receives the API; a throwing call step can also report `"callback-error"` as its second argument.

`skipSequence` executes remaining non-wait, non-input, non-battle actions, then calls `onComplete`. Those actions can have side effects. It is not a universal “cancel without consequences” operation. `stopSequence(opts)` uses the cleanup flag established by `playSequence`; its own opts argument does not change cleanup policy.

## 7. Stage effects

```lua
scenes.show(false, { underlay = "transparent" })
scenes.shakeScreen({ intensity = 2, duration = 0.4 })
scenes.setTint("sunset", { duration = 0.5 })
scenes.flashScreen("white", { duration = 0.3 })
scenes.setVignette("letterbox", { duration = 0.4 })
scenes.setWeather("rain", { count = 40, speed = 1 })
```

Tint presets include sunset, night, cave, underwater, poison, and sepia. Vignettes include letterbox, spotlight, and dither. Weather supports rain, snow, leaves, cherry_blossom, embers, and dust. See the [API reference](https://github.com/syybott/Gen1Better/wiki/Compatibility#7-betterscenes-story-stage-exports) for getters and clear/stop functions.

FX or a handoff alone do not make `isActive()` true. Keep a background or plain underlay active, as above, for an effects-only presentation. `diagnostics().active` also considers FX and handoff state, so it can differ from `isActive()`.

## 8. Battle handoff and resumption

`prepareBattleHandoff` supplies a transition, token, and callbacks. It does not start an encounter or apply atmosphere/music to a battle. Your consuming mod provides that bridge.

Battle types are **trainer**, **wild**, and **boss**. Transitions are **cut**, **flash**, **blinds**, **mosaic**, and **swirl**; the default is swirl with a duration of 0.8 seconds (cut is immediate). `storySceneId` is captured from the current stage; a same-named option does not override it. `battleBackdropId` (or `backdropId`) selects the token's battle backdrop data.

In this adapter example, `startCombat(token, done)` is a function implemented by your mod. It starts the intended encounter through public game APIs and calls `done(outcome)` once the result is known. It is not a Gen1Better export or an assumed engine event.

```lua
local function handoffToCombat(scenes, startCombat)
  return scenes.prepareBattleHandoff({
    battleType = "wild", species = "MEW", level = 30,
    battleBackdropId = "custom_space",
    transition = "swirl", duration = 0.8,
    onHandoff = function(token)
      -- The adapter also applies token.music / token.atmosphere if wanted.
      startCombat(token, function(outcome)
        local ok, reason = scenes.resumeFromBattle({
          handoffId = token.id,
          outcome = outcome,
        })
        if not ok then error("Battle return: " .. tostring(reason)) end
      end)
    end,
    onWin = function(api, result) api.setSubtitle("Victory!") end,
    onLose = function(api, result) api.setSubtitle("A setback...") end,
    onFlee = function(api, result) api.setSubtitle("You escaped.") end,
  })
end
```

Keep calling `update(dt)` until the handoff callback fires for timed transitions. Your battle controller must take responsibility for battle updates and input. Resume with the actual token ID and **win**, **lose**, **flee**, or **draw**. The matching outcome callback and `onReturn(api, result)` run; draw has no dedicated outcome callback. A sequence waiting on battle then continues.

`cancelBattleHandoff` returns `false, "handoff-locked"` once handed off. Tokens contain transferable atmosphere data; that data has no automatic rendering or music effect in combat.

## 9. Diagnostics and inspection

```lua
local diag = scenes.diagnostics()
local actorCount = 0
for _ in pairs(diag.actors or {}) do actorCount = actorCount + 1 end
print("Current scene:", scenes.current())
print("Actor count:", actorCount)
local sequence = scenes.getSequence()
print("Sequence step:", sequence and sequence.stepIndex)
```

`diagnostics().actors` is a table keyed by slot, with no `actorCount` field. `getBubble()` reports its text, style, position, size, and tail, not a lines array. `getSequence()` reports stepIndex, totalSteps, waitingInput, waitingBattle, lastBattleOutcome, waitRemaining, currentAction, skippable, aborted, and lastError, plus active/id.

For all 54 methods, their return contracts, and default/cache controls, see [Provider and Mod Compatibility](https://github.com/syybott/Gen1Better/wiki/Compatibility#7-betterscenes-story-stage-exports).
