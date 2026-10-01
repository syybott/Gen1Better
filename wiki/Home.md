# Gen1Better

Gen1Better adds widescreen presentation, customizable menu colors, 2D battle backdrops, cinematic story staging, and the optional BetterPC, BetterParty, BetterPokedex, BetterTrainerCard, BetterBag, BetterModManager, BetterOptions, BetterBattle, and BetterScenes suites to Gen1Recomp.

Each interface can be enabled independently. Disabling one keeps its classic
interface with Gen1Better's widescreen and palette support.

## Getting started

1. Place the complete mod folder in the Gen1Recomp `mods` directory.
2. Enable **Gen1Better** in the game's mod manager.
3. Open **START > OPTION > EXTRAS > Gen1Better** to choose your menu palette
   and interfaces.

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

### BetterPokedex and BetterTrainerCard

Responsive Pokédex and trainer-card interfaces, each controlled by its own default-ON setting.

### BetterModManager and BetterOptions

A responsive mod manager and tabbed game options. BetterOptions groups SPEED, VIDEO, GRAPHICS, AUDIO, BATTLE OPTIONS, CONTROLS, EXTRAS, and MODS. Select Gen1Better in EXTRAS and press A to enter its settings pane; B returns to the list.

### BetterBattle

A WIDE Extended battle interface with compact status panels, command and move
panels, HP and XP bars, trainer portraits, party indicators, and 63 automatic
pixel-art battle backdrops.

Set **BATTLE LAYOUT → WIDE** and **BATTLE HUD → EXTENDED**, then choose **BetterBattles** for the 2D stage and **BetterBattle UI** for the panels. Both default to ON and can be selected independently. Incompatible layouts turn both OFF; turn both OFF before switching to the Standard HUD.

Battle sprites need a correct transparency mask: transparent background and opaque Pokémon body, including white areas. Active external renderers take priority over the 2D backdrop.

### BetterScenes

A 320×180 story stage for backdrops, feet-positioned actors and shadows, bubbles, subtitles, emotes, declarative sequences, camera effects, and weather. It fits the viewport with integer scale factors at standard full 16:9 sizes; arbitrary window sizes may use fractional scales.

The consuming mod must drive update, forward advance/skip input, scope its assets, and arrange cleanup. Gen1Better draws an active stage. Handoff tokens and callbacks support outcome branching; the consuming mod starts combat and applies any music or atmosphere data.

## More features

Gen1Better also includes menu palettes, Menu Scale, Start Menu and item
favorites, scrolling labels, and configurable Pokédex caught indicators.

See [Extra Features](https://github.com/syybott/Gen1Better/wiki/Extra-Features) for the player guide and
[BetterBattle Pixel-Art Backdrops](https://github.com/syybott/Gen1Better/wiki/Battle-Backdrops) for backdrop behavior,
scene mappings, and sprite requirements.

## For artists & creators

Looking to create custom art, cutscenes, or encounters? Check the **[Artist & Creator Launch Pad](https://github.com/syybott/Gen1Better/wiki/Artists)** for a quick "what do you want to build" guide:
- **[Make a Custom Battle Backdrop Pack](https://github.com/syybott/Gen1Better/wiki/Artist-Backdrop-Packs)**: image registration, encounter hooks, shadow styling, and a complete standalone-mod template.
- **[Make a Cinematic Story Cutscene](https://github.com/syybott/Gen1Better/wiki/BetterScenes)**: Choreograph narrative scenes outside of battle with speech bubbles, character staging, and weather.
- **[Customize Floor Shadows (BetterShadows)](https://github.com/syybott/Gen1Better/wiki/Battle-Backdrops#shadow-system-and-scene-interaction)**: Tune ground contact shadows, scene tints, or custom species profiles.
- **[Script Custom Battles & Arena Transitions](https://github.com/syybott/Gen1Better/wiki/Battle-Backdrops#custom-spawn-hook)**: Trigger custom spawns, boss arenas, or mid-battle elevation shifts.

## For mod authors

See [Provider and Mod Compatibility](https://github.com/syybott/Gen1Better/wiki/Compatibility) for public hooks,
exports (`betterBattle`, `betterScenes`), provider ownership, custom battle
scenes, and custom-menu scaling.

See [Mod Options Screen Compatibility](https://github.com/syybott/Gen1Better/wiki/Mod-Options-Screen-Compatibility) for
the standard `isModOptions` screen marker.
