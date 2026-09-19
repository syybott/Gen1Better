# Gen1Better

Gen1Better adds widescreen presentation, customizable menu colors, 2D battle backdrops, cinematic story staging, and the optional BetterPC, BetterParty, BetterBag, BetterBattle, and BetterScenes suites to Gen1Recomp.

Each interface can be enabled independently. Disabling one keeps its classic
interface with Gen1Better's widescreen and palette support.

## Getting started

1. Place the complete mod folder in the Gen1Recomp `mods` directory.
2. Enable **Gen1Better** in the game's mod manager.
3. Open **START > COLORS > BetterMenus** to choose your menu palette and
   interfaces.

Keep the supplied assets with the mod when updating.

## Interfaces

### BetterPC

A responsive Pokémon storage screen that displays your party, box contents,
and the selected Pokémon's details in one interface. It supports moving,
transferring, and releasing Pokémon through the existing storage system.

### BetterParty

A responsive party screen that displays Pokémon details and moves beside the
party list while retaining the game's party actions and selection behavior.

### BetterBag

A responsive pocket-based bag with item descriptions, favorites, sorting, and
expanded inventory limits. Mods that manage their own inventory can retain
their existing capacity and pocket behavior.

### BetterBattle

A WIDE Extended battle interface with compact status panels, command and move
panels, HP and XP bars, trainer portraits, party indicators, and 63 automatic
pixel-art battle backdrops.

BetterBattle requires the game's **BATTLE LAYOUT** to be **WIDE** and
**BATTLE HUD** to be **EXTENDED**. Battle sprites with correct transparency are
also required; the current supported visual configuration uses Crystal battle
sprites. Active external battle renderers take priority over BetterBattle's
2D backdrop.

### BetterScenes

A dedicated 16:9 story stage and cinematic presentation subsystem for narrative cutscenes outside of combat. Built with the same 320×180 integer-scaled pixel-art discipline, BetterScenes provides full theatrical control:
- 320×180 pixel-art backdrops with `cut`, `crossfade`, and `flash` transitions.
- Solid `black`, palette `paper`, and `transparent` underlays.
- Actor staging with feet coordinates, mirror/scale anchors, enter/exit animations, and soft ground contact shadows (shared species profiles or custom schema).
- Dynamic comic dialogue bubbles (speech, thought, shout) with live anchor tracking, letterbox subtitles, and floating emote puffs.
- Declarative multi-step timeline runner (`playSequence`) with player input barriers and skipping.
- 320×180 native camera shake, ambient color tints, flash pulses, restomod dither vignettes, and deterministic weather particles.
- Decoupled battle handoff (`prepareBattleHandoff`), pre-battle visual transitions, atmosphere inheritance into combat, and outcome resumption (`resumeFromBattle`).

## More features

Gen1Better also includes menu palettes, Menu Scale, Start Menu and item
favorites, scrolling labels, and configurable Pokédex caught indicators.

See [Extra Features](Extra-Features) for the player guide and
[BetterBattle Pixel-Art Backdrops](Battle-Backdrops) for backdrop behavior,
scene mappings, and sprite requirements.

## For artists & creators

Looking to create custom art, cutscenes, or encounters? Check the **[Artist & Creator Launch Pad](Artists)** for a quick "what do you want to build" guide:
- **[Make a Custom Battle Backdrop Pack](Artist-Backdrop-Packs)**: 3 Safe Doors, zero-code quickstart, and copy-paste templates.
- **[Make a Cinematic Story Cutscene](BetterScenes)**: Choreograph narrative scenes outside of battle with speech bubbles, character staging, and weather.
- **[Customize Floor Shadows (BetterShadows)](Battle-Backdrops#shadow-system-and-scene-interaction)**: Tune ground contact shadows, scene tints, or custom species profiles.
- **[Script Custom Battles & Arena Transitions](Battle-Backdrops#custom-spawn-hook)**: Trigger custom spawns, boss arenas, or mid-battle elevation shifts.

## For mod authors

See [Provider and Mod Compatibility](Compatibility) for public hooks,
exports (`betterBattle`, `betterScenes`), provider ownership, custom battle
scenes, and custom-menu scaling.

See [Mod Options Screen Compatibility](Mod-Options-Screen-Compatibility) for
the standard `isModOptions` screen marker.
