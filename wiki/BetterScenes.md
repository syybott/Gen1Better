# BetterScenes: Cinematic Cutscenes

A character walks into a room, speaks, pauses for your reply, and reacts. Rain starts outside. The lighting changes. The moment leads into a battle—or leaves the player with a new piece of the story.

BetterScenes gives you a stage for those moments. Bring your backdrop, characters, and props; arrange them, write their dialogue, and choose what happens next. The same controls work for you, a modder, or an AI agent helping turn your direction into a scene.

## 1. Authoring and display

Start with a **320×180 story backdrop**. Your characters and props can use their own image sizes. Stage positions describe where an image's feet or bottom edge meet the scene, which makes placement easier to picture.

The stage keeps its 16:9 shape as it fits the window. At full 720p, 1080p, 1440p, and 4K viewport sizes, the backdrop scales by 4×, 6×, 8×, and 12×. Check other window sizes as part of reviewing your artwork.

The template uses `mod.assets` to find images inside your own mod folder. Keep that pattern when changing paths. The [API reference](https://github.com/syybott/Gen1Better/wiki/Compatibility#7-betterscenes-story-stage-exports) covers precise coordinates, scaling, and asset ownership.

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

The template creates a small scene: the backdrop appears, a character enters from the left, and a speech bubble waits for **A**. **B** skips to the end. The setup, timing, input, and return to the game are included.

Change the two image paths, the dialogue, and the sequence steps to make it yours. The image filenames below are examples for artwork you supply.

<details>
<summary>Open the complete main.lua template</summary>


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

</details>

Choose where your story begins: an interaction, an event in your mod, or another scene. Connect that trigger to `playIntro(game)` after the game is ready. This template provides the scene; your mod chooses when to start it.

If you are working with an agent, ask it to keep the controller, A/B handling, and completion cleanup while connecting the scene to your chosen trigger. The [consumer guide](https://github.com/syybott/Gen1Better/blob/main/agents/Gen1Better-API-Consumer.md) explains that wiring.

## 3. Scene presentation and underlays

Choose how the next moment arrives: a direct cut, a gentle crossfade, or a flash. Use a black underlay for a blackout, paper for a palette-colored surface, or transparent when the game should remain visible beneath the stage.

```lua
local ok, id = scenes.show("my_story_morning", {
  transition = "crossfade",
  duration = 0.5,
})
scenes.show(false, { underlay = "black" })
scenes.hide({ transition = "crossfade", duration = 0.35 })
```

Use **cut**, **crossfade**, or **flash** for scene transitions. The complete template includes the cleanup that removes its background and actors when the scene ends. Keep that finish function when adapting the example.

For registration results, default timing, and the precise behavior of hiding a scene, see the [scene presentation contract](https://github.com/syybott/Gen1Better/wiki/Compatibility#scene-presentation)

## 4. Theatrical actor staging

Start with **left**, **center**, or **right** to place a character. The right slot mirrors its image by default; adjust `mirror` to suit the direction your artwork faces. These feet positions are useful starting points:

| Slot | X | Y | Default mirror |
| --- | --- | --- | --- |
| left | 70 | 155 | false |
| center | 160 | 155 | false |
| right | 250 | 155 | true |

Give an actor your own name, such as `guide`, and provide `x` and `y` when you want a different position. Those coordinates place its feet or bottom-center. A mouth anchor tells a bubble where to point; its offsets are measured from that same origin.

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

Use **cut**, **fade**, or **slide** for an entrance or exit. `updateActor` lets you adjust an actor you have already placed. For a conversation, let the entrance finish before showing the bubble; if the speaker moves again, place the bubble again afterward.

### Actor shadows and floor contact

Shadows help an image sit naturally on the stage. Use `shadow = true` to start with the shared shadow system, `shadow = false` for a weightless character, or a table to direct the shadow yourself.

A Pokémon can use a shared preset with `species = "CHARIZARD"`. A human, tree, desk, or other image can have its own settings. Your scene can override the preset to suit a pose or your preferred style.

| Want to change… | Start with… |
| --- | --- |
| Footprint width or depth | `baseWidth` and `baseHeight` |
| Shadow strength | `opacityScale` |
| The lighting's color | `color = { red, green, blue }`, with each value from 0 to 1 |
| Where the shadow meets the image | `offsetX` and `offsetY` |
| A weightless moment | `shadow = false` |

The actor example above uses a modest contact shadow with `opacityScale = 0.8`. For hand-authored shapes, contact calibration, or separate scene/species overrides, follow the [full shadow contract](https://github.com/syybott/Gen1Better/wiki/Compatibility#unified-shadow-configuration-schema).

### Sprite scaling and variants

Start at scale 1 with the default **nearest** mode. If you want a character to appear smaller, a smaller image drawn for that size gives you direct control over its details.

You can supply several authored sizes as **variants**. With `scaleMode = "auto"`, BetterScenes tries an eligible variant, then its clean downscale path, then nearest rendering. This example provides mini and medium versions of Oak:

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

Put variant bands in ascending `maxScale` order and give each its actual `nativeScale` relative to the base image. `pixelSnap = true` keeps drawn positions on whole screen pixels.

The [scaling reference](https://github.com/syybott/Gen1Better/wiki/Compatibility#scale-defaults-and-cache) covers the other modes, fallback behavior, and cache controls. Review the look at your intended sizes; choose the rendering mode that suits the artwork.

## 5. Dialogue, subtitles, and emotes

Give a speaker a **speech**, **thought**, or **shout** bubble. Use a narrator bubble or subtitle to set the scene. Emotes add a quick reaction: surprise, a question, affection, frustration, or a pause.

```lua
scenes.showBubble("left", "Welcome!", { style = "speech" })
scenes.showBubble("right", "Where are we?", { style = "thought" })
scenes.showBubble("left", "STOP!", { style = "shout" })
scenes.showBubble("narrator", "Later that evening...")
scenes.setSubtitle("The journey continues.", { position = "bottom", bar = true })
scenes.showEmote("left", "exclamation", { duration = 1.5 })
```

Place the bubble after the actor has settled, and re-show it after a later move when needed. Put subtitles at the **top**, **bottom**, or **center**.

Emotes include **exclamation**, **question**, **heart**, **anger**, **sweat**, **dots**, and **music**. In a sequence, add an explicit wait after an emote if the reaction should hold before the next action.

The [dialogue contract](https://github.com/syybott/Gen1Better/wiki/Compatibility#actors-and-dialogue) defines anchors, timing, and supported options

## 6. Declarative sequences

A sequence is your scene written as a list of moments. Place the actor, show its words, wait for the player, add a reaction, then finish. Keep actor details in `config` and transition choices in `opts`, as in this example:

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

Use **waitInput** when the player should decide when to continue, and **wait** for a timed pause. Actor entrances and exits can use `wait = true` alongside their transition options.

Keep the complete template's finish callback, or provide your own final cleanup steps. **Skipping runs the remaining scene actions**, so decide what the player should see or trigger when skipping. Use `stopSequence` when you want to abort instead, following the cleanup policy you selected.

For all actions, aliases, return values, and cleanup rules, see the [sequence contract](https://github.com/syybott/Gen1Better/wiki/Compatibility#sequences)

## 7. Stage effects

Lighting, weather, and a small camera movement can change the feeling of a scene. Try a sunset tint for warmth, rain for a quiet conversation, or a short shake and flash for a sudden impact.

```lua
scenes.show(false, { underlay = "transparent" })
scenes.shakeScreen({ intensity = 2, duration = 0.4 })
scenes.setTint("sunset", { duration = 0.5 })
scenes.flashScreen("white", { duration = 0.3 })
scenes.setVignette("letterbox", { duration = 0.4 })
scenes.setWeather("rain", { count = 40, speed = 1 })
```

Tint presets include sunset, night, cave, underwater, poison, and sepia. Vignettes include letterbox, spotlight, and dither. Weather supports rain, snow, leaves, cherry_blossom, embers, and dust. See the [API reference](https://github.com/syybott/Gen1Better/wiki/Compatibility#7-betterscenes-story-stage-exports) for getters and clear/stop functions.

Keep a backdrop or plain underlay active while presenting effects. The first line of this example uses a transparent underlay so the effect can sit over the game. Your controller continues to update the stage while the effects play.

## 8. Battle handoff and resumption

A story can lead into an encounter, then continue with a different response to victory, defeat, or escape

Choose a **cut**, **flash**, **blinds**, **mosaic**, or **swirl** transition. BetterScenes prepares that visual handoff and calls your mod's encounter function. Your mod starts the battle, applies the music or atmosphere you want, and reports the result so the story can continue.

In this example, `startCombat(token, done)` stands for that encounter function in your own mod. A modder or agent should connect it to the public game APIs and call `done(outcome)` when the battle ends.

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

Keep the story controller updating until the timed handoff calls your encounter function. Return the actual token's ID with **win**, **lose**, **flee**, or **draw**. The callbacks let you choose the next piece of the story.

For the exact token fields, callback timing, and cancellation rules, see the [battle handoff contract](https://github.com/syybott/Gen1Better/wiki/Compatibility#battle-handoff)

## 9. Diagnostics and inspection

When a scene needs troubleshooting, these small queries help you or your agent identify the current backdrop, actors, and sequence step:

```lua
local diag = scenes.diagnostics()
local actorCount = 0
for _ in pairs(diag.actors or {}) do actorCount = actorCount + 1 end
print("Current scene:", scenes.current())
print("Actor count:", actorCount)
local sequence = scenes.getSequence()
print("Sequence step:", sequence and sequence.stepIndex)
```

Count the actor entries as shown in the example. The [inspection reference](https://github.com/syybott/Gen1Better/wiki/Compatibility#7-betterscenes-story-stage-exports) defines the returned fields.

For all 54 methods, their return contracts, and default/cache controls, see [Provider and Mod Compatibility](https://github.com/syybott/Gen1Better/wiki/Compatibility#7-betterscenes-story-stage-exports)
