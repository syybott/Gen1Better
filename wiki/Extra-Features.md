# Extra Features and Options

## Open the Gen1Better options

Open **START → OPTION → EXTRAS → Gen1Better**. With BetterOptions enabled, focus the Gen1Better row and press **A** to enter its settings pane; press **B** to return to the mod list. The classic options route remains available when BetterOptions is off.

BetterOptions groups the game's settings into **SPEED**, **VIDEO**, **GRAPHICS**, **AUDIO**, **BATTLE OPTIONS**, **CONTROLS**, **EXTRAS**, and **MODS**

## All Gen1Better settings

| Option | Saved key | Default | What it changes |
| --- | --- | --- | --- |
| **BetterFrames** | `better_frames` | **OG DEFAULT** (`og:default`) | Frame artwork for menus, dialogue, location popups, and battle boxes |
| **MENU PALETTE** | `palette` | **SOULSILVER** (`soulsilver`) | Menu and panel colors, subject to the game's CLASSIC palette lock |
| **Inverse** | `inverse` | **OFF** | Reverses the menu palette's light-to-dark order when the palette is unlocked |
| **BetterPC** | `modern_pc_ui` | **ON** | Responsive Pokémon storage |
| **BetterParty** | `modern_party_ui` | **ON** | Responsive party screen |
| **BetterPokedex** | `modern_pokedex_ui` | **ON** | Responsive Pokédex |
| **BetterTrainerCard** | `better_trainer_card` | **ON** | Responsive trainer card |
| **BetterBag** | `modern_bag_ui` | **ON** | Pocket-based bag interface. Expanded inventory limits apply independently. |
| **BetterModManager** | `better_mod_manager` | **ON** | Responsive mod manager |
| **BetterOptions** | `better_options` | **ON** | Tabbed game options screen |
| **Menu Scale** | `menu_scale` | **100%** (`100`) | 100%, 90%, 80%, or 70% for eligible compact menus and dialogue. The seven responsive interfaces keep their own sizing. |
| **BetterBattles** | `better_battles` | **ON** | Gen1Better's 2D battle stage and backdrops. Requires WIDE + EXTENDED. |
| **BetterBattle UI** | `better_battle_ui` | **ON** | BetterBattle's status, command, and move panels. Requires WIDE + EXTENDED. |
| **BetterAnimations** | `better_animations` | **ON** | Enhanced move animations in the supported battle rendering path |
| **Marquee Text** | `marquee_text` | **ON** | Scrolls labels that do not fit |
| **Pokédex Indicator** | `pokedex_indicator` | **DEFAULT** (`default`) | BetterBattle's caught marker: OFF, DEFAULT (menu palette), or RED |

These are defaults for the current option schema. Saved choices take precedence. Battle layout checks can turn both battle toggles off, so set WIDE + EXTENDED before enabling them.

## Changes since 1.1.2

The exposed settings grew from seven to sixteen. Review your settings after updating:

- **Modern PC UI** is now labeled **BetterPC**; its saved key remains `modern_pc_ui` and its default changed from OFF to ON
- **Modern Bag UI** is now labeled **BetterBag**; its saved key remains `modern_bag_ui`
- The **Modern Battle UI** ON/OFF/MOD selector (`modern_battle_ui`) was replaced by **BetterBattles** and **BetterBattle UI**, each an ON/OFF toggle. MOD is no longer a selectable setting. Review both new toggles after upgrading; do not rely on the old selector to configure them.
- **BetterFrames**, **BetterParty**, **BetterPokedex**, **BetterTrainerCard**, **BetterModManager**, **BetterOptions**, **Menu Scale**, and **BetterAnimations** are additional settings
- **MENU PALETTE**, **Inverse**, **Marquee Text**, and **Pokédex Indicator** retain their saved keys. The menu palette now has 52 choices, including ten FireRed frame palettes.

## Favorites

Highlight a Start Menu entry and press **SELECT** to pin or unpin it. Favorites show a heart and move to the top. In BetterBag, **START** toggles an item's favorite status and **SELECT** invokes sorting.

Favorites are saved with your game. Use **SAVE** to retain changes when reloading.

## Choose the game's palette

Open **OPTION → GRAPHICS → COLORS** to preview the game's palette over the overworld. Browse with the directional controls, press **A** or **START** to keep the preview, and press **B** to cancel.

When Groovy Palette & Frames is installed, this game-palette browser offers **DEFAULT** and **GROOVY** categories. Gen1Better's menu themes are built in; they do not require that companion mod.

## Choose a Gen1Better menu palette

**MENU PALETTE** controls menus separately from the game's overworld palette. Its 52 choices are:

- **GAME BOY**, **BLACK AND WHITE**, **OG RED**, **ADVANCED**, **SGB**, **SOULSILVER**, **HEARTGOLD**, **FIRERED**, **FR 1–FR 10**, **LEAFGREEN**, **CRYSTAL**, and **EMERALD**
- **AMIGA WB**, **AMIGA DP**, **C64**, **SPECTRUM**, **CGA**, **APPLE2**, **POCKET**, **GB LIGHT**, **VIRTUAL BOY**, **AMBER**, **PHOSPHOR**, **PLASMA**, **RAINBOW**, **ACID**, **FUSCHIA**, **SUNSET**, **OCEAN**, **FOREST**, **LAVA**, **ICE**, **CANDY**, **VAPOR**, **NEON**, **TOXIC**, **SEPIA**, **NOIR**, **CHERRY**, **MIDNIGHT**, **GOLD**, **MINT**, and **GRAPE**

Names above match the displayed choices, including **FUSCHIA**. The **Inverse** toggle reverses an unlocked menu palette.

### CLASSIC palette lock

When the game uses its classic/OG palette without a custom palette or ramp, the menu palette row displays **CLASSIC**. Menus follow the game's colors, Inverse is ignored, and BetterFrames offers only its OG category.

Selecting MENU PALETTE asks whether to switch the game's palette to **ADVANCED**. **YES** changes the game palette and opens the menu palette picker; **NO** keeps CLASSIC. There is no separate UNLOCK setting.

## Choose BetterFrames

The supplied frame catalog contains 26 choices across three categories:

| Category | Choices | Colors |
| --- | --- | --- |
| OG | DEFAULT and OG 1–OG 6 | Game Boy frame artwork; DEFAULT keeps the game's current frame |
| HYBRID | HYBRID 1–HYBRID 9 | Follows the menu palette while retaining the Poké Ball colors in the Poké Ball design |
| FR | FR 1–FR 10 | FireRed artwork and frame colors |

The displayed numbers enumerate available designs; they are not the source asset's box number. Dialogue and location popups use matching artwork. CLASSIC restricts the picker to OG.

## Choose BetterBattles and BetterBattle UI

BetterBattle UI includes the [RARE encounter label](https://github.com/syybott/Gen1Better/wiki/RARE-Encounters) and gender indicators below the enemy HP bar that show which genders of the opposing species are stored in your PC boxes when Gender Mod is enabled

Set **BATTLE LAYOUT → WIDE** and **BATTLE HUD → EXTENDED** first. Then choose the two Gen1Better toggles independently:

| BetterBattles | BetterBattle UI | Result |
| --- | --- | --- |
| ON | ON | Gen1Better's 2D stage and BetterBattle panels |
| ON | OFF | Gen1Better's 2D stage with the game's battle interface |
| OFF | ON | BetterBattle panels over the available battle scene |
| OFF | OFF | The game's battle presentation |

An active external battle scene provider takes priority over the 2D stage. Providers can separately allow or suppress BetterBattle's panels. Installing an inactive provider does not by itself suppress the stage.

Both toggles require WIDE + EXTENDED. Incompatible layout changes turn both OFF. Turn **both** OFF before selecting the Standard HUD. An external provider's effective MOD mode is automatic; it is not a picker choice.

Quality of Life's separate XP bar and caught indicator settings are written OFF when BetterBattle UI is enabled or the game uses WIDE + EXTENDED. Turning those conditions off does not automatically restore the companion settings; re-enable them manually if wanted.

Use battle sprites with a correct transparency mask: the background must be transparent, while the Pokémon, including white body areas, remains opaque

## Menu Scale and animations

**Menu Scale** offers 100%, 90%, 80%, and 70%. Eligible compact menus and dialogue use this setting. BetterPC, BetterParty, BetterPokedex, BetterTrainerCard, BetterBag, BetterModManager, and BetterOptions retain their responsive sizing.

**BetterAnimations** chooses enhanced move animation rendering in the supported field renderer. Turning it off selects the original animation path.

**Marquee Text** scrolls labels that do not fit. **Pokédex Indicator** selects OFF, DEFAULT, or RED for BetterBattle's caught marker.

See [Provider and Mod Compatibility](https://github.com/syybott/Gen1Better/wiki/Compatibility) for integration rules and [Mod Options Screen Compatibility](https://github.com/syybott/Gen1Better/wiki/Mod-Options-Screen-Compatibility) for custom settings screens
