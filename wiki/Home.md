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

A dedicated story stage and presentation overlay for narrative cutscenes outside
of combat. Built with the same 320×180 integer-scaled pixel-art discipline,
BetterScenes provides endpoint-aware transitions (`cut`, `crossfade`, `flash`),
underlays (`black`, `paper`, `transparent`), and a clean foundation for
cutscenes, character staging, and dialogue bubbles.

## More features

Gen1Better also includes menu palettes, Menu Scale, Start Menu and item
favorites, scrolling labels, and configurable Pokédex caught indicators.

See [Extra Features](Extra-Features) for the player guide and
[BetterBattle Pixel-Art Backdrops](Battle-Backdrops) for backdrop behavior,
scene mappings, and sprite requirements.

## For mod authors

See [Provider and Mod Compatibility](Compatibility) for public hooks,
exports (`betterBattle`, `betterScenes`), provider ownership, custom battle
scenes, and custom-menu scaling.

See [Mod Options Screen Compatibility](Mod-Options-Screen-Compatibility) for
the standard `isModOptions` screen marker.
