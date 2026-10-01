# 🎨 Artist & Creator Launch Pad

**The public API is currently untested.** I built these tools to help me create JRPG-style storytelling expansions, scenes, and complex battles, and chose to share them with anyone who wants to build similar projects. I plan to test the API. I'm sorry if you run into anything broken while using it.

Welcome! Gen1Better gives your artwork a place in Gen1Recomp: a painted battle arena, a character with something to say, a storm rolling over a story scene, or a boss fight whose surroundings change as it unfolds.

Bring your images and an idea of what should happen. BetterBattle, BetterScenes, and BetterShadows provide controls for placing, presenting, and connecting those ideas. You can use the templates yourself or work with an AI agent that follows the same public APIs.

## 🧭 What would you like to make?

### Put my artwork behind a battle

Start with a 320×180 background. Choose where it appears and how the shadows should look against it.

The backdrop guide has three safe doors: **here is my image**, **here is when it appears**, and **here is how shadows look**. Its complete template includes the mod setup and registration.

👉 [Make an Artist Backdrop Pack](https://github.com/syybott/Gen1Better/wiki/Artist-Backdrop-Packs)

### Tell a story with my characters

Set the scene, bring in a character or prop, give someone a speech bubble, and decide what happens next. Add a reaction, change the lighting, or let rain set the mood.

The cutscene guide starts with a small conversation you can adapt. Its template handles the updates, button input, and cleanup that make the scene run.

👉 [Create a BetterScenes Cutscene](https://github.com/syybott/Gen1Better/wiki/BetterScenes)

### Help an actor feel grounded

A shadow can make a Pokémon, trainer, tree, desk, or other object feel part of the scene. Make it smaller, softer, warmer, or remove it for a weightless moment.

Shared Pokémon profiles are useful starting points. Your own images can use their own shadow settings, and your art direction can override a preset.

👉 [Style Battle Shadows](https://github.com/syybott/Gen1Better/wiki/Battle-Backdrops#shadow-system-and-scene-interaction)

👉 [Style Story Actor Shadows](https://github.com/syybott/Gen1Better/wiki/BetterScenes#actor-shadows-and-floor-contact)

### Give a battle its own atmosphere

Choose a special arena for an encounter, lift a battler onto a platform, or change the backdrop as a fight enters its next phase. A story scene can also hand control to your mod's encounter logic and continue after the result.

👉 [Choose an Arena for a Custom Battle](https://github.com/syybott/Gen1Better/wiki/Battle-Backdrops#custom-spawn-hook)

👉 [Change the Arena Mid-Battle](https://github.com/syybott/Gen1Better/wiki/Battle-Backdrops#dynamic-scene-changes--transitions)

👉 [Connect a Story Scene to a Battle](https://github.com/syybott/Gen1Better/wiki/BetterScenes#8-battle-handoff-and-resumption)

## Working with an AI agent

Describe the result in your own words. For example:

> Use my sunset painting on Route 1. Give the floor shadows a warm brown tint and soften them. Package it as a separate Gen1Recomp mod.

Or:

> Have my character enter from the left, speak, and react with an exclamation mark. Let me advance the conversation with A, then return to the game.

Give the agent your artwork and point it to Gen1Better's `agents.md` entry point and `agents/Gen1Better-API-Consumer.md` guide. Those instructions help it turn your creative direction into the right scene settings, API calls, and complete mod setup.

Your artwork, dialogue, mood, and staging remain your creative choices. The agent should explain what to change using the same terms as these guides.

## A few shared ideas

| Idea | What you control |
| --- | --- |
| Backdrop | Where the scene or battle takes place |
| Actor | A character, Pokémon, prop, or other image you place on a story stage |
| Shadow | How that image meets the ground |
| Sequence | The order of entrances, dialogue, reactions, effects, and waits |
| Transition | How one scene or moment leads into another |
| Battle handoff | When your story asks the mod to start combat and how it continues after the result |

## 📐 Preparing your artwork

Author battle and story backdrops at **320×180**. Battle backdrops use fully opaque PNGs. Actor and prop images can have their own dimensions and transparent backgrounds.

The stage is 16:9. At full 720p, 1080p, 1440p, and 4K viewport sizes, the artwork scales by 4×, 6×, 8×, and 12×. Check how your work looks at the window sizes you want to support.

Before packaging a battle backdrop, run the supplied artwork checker:

```bash
python tools/verify_backdrop.py assets/my_art_320.png
```

It can catch incorrect dimensions, transparency, and possible pixel-art issues. The [Backdrop Artwork Checker guide](https://github.com/syybott/Gen1Better/wiki/Backdrop-Artwork-Checker) explains the grades and measurements.

## When you need the exact contract

The artist guides help you choose and build. The [API and Compatibility Reference](https://github.com/syybott/Gen1Better/wiki/Compatibility) defines the exact fields, defaults, return values, ownership rules, and integration responsibilities for modders and agents.
