# Gen1BetterMenus

Widescreen menus, customizable menu colors, and optional BetterPC, BetterParty, BetterBag, and BetterBattle interfaces for Gen1Recomp.

Choose each interface independently. Turning off a Better interface option keeps the corresponding classic interface with BetterMenus' widescreen and palette support.

## Installation

1. Place the complete mod folder in your Gen1Recomp `mods` directory. The folder should contain `manifest.json`, `main.lua`, and the supplied assets directly inside it.
2. Enable **Gen1BetterMenus** in the game's mod manager.
3. Open **START → COLORS → BetterMenus** to choose your menu palette and interfaces.

Keep the supplied assets with the mod when updating. Disable the separate **Modern PC UI** mod if installed; it conflicts with BetterPC.

**BetterBattle requires Crystal sprites with correct transparency.** Their opaque body pixels prevent the battle background from showing through the Pokémon. No particular sprite mod is required; the requirement concerns the sprite assets themselves. BetterBattle does not repair incorrect sprite transparency.

## Choose your interfaces

### BetterPC

A responsive Pokémon storage screen with your party, box contents, and selected Pokémon's details. Move Pokémon between slots and boxes, transfer them between your party and storage, or release them through the action menu.

- **A:** open actions, or place a Pokémon you are moving.
- **START:** cycle the detail pages.
- **SELECT:** open the box selector. While moving a Pokémon, toggle the party/detail pane instead.
- **B:** cancel a move or leave the screen.

BetterPC is **ON** by default and opens at Bill's PC.

### BetterParty

A responsive party screen showing Pokémon details and moves alongside the party list. It retains the game's party actions and selection behavior, including choosing a Pokémon for an item or battle action.

Use **A** to select, **START** for details, and **B** to return. Follow the screen's directional prompts to browse the party and moves.

BetterParty is **ON** by default.

### BetterBag

A responsive bag with item descriptions and pockets for **All Items**, **Items**, **Medicine**, **Poké Balls**, **TMs/HMs**, and **Key Items**. Use **LEFT/RIGHT** to change pockets, **UP/DOWN** to browse, **A** to select, and **B** to return.

- Press **START** on an item to favorite or unfavorite it. Favorites are marked with a heart and move to the top.
- Press **SELECT** for the bag's sorting action.
- Expanded inventory supports **255 item slots** and stacks of **999**, with compatibility exceptions for mods that manage their own inventory. Larger existing limits are retained; Kanto Reforged keeps its own bag capacity and pocket behavior.

BetterBag is **ON** by default. Switching its interface off does not remove the expanded inventory limits.

### BetterBattle

A WIDE Extended battle interface with compact Pokémon status panels, command and move panels, HP and XP bars, a caught indicator, trainer portraits, and party indicators.

To enable it:

1. Set the game's **BATTLE LAYOUT** to **WIDE**.
2. Set **BATTLE HUD** to **EXTENDED**.
3. Open **START → COLORS → BetterMenus** and set **BetterBattle** to **ON**.
4. Use **Crystal sprites with correct transparency**, supplied through your preferred sprite provider.

BetterBattle requires WIDE + EXTENDED. An incompatible layout can turn it off; set the layout first, then enable BetterBattle. Disable BetterBattle before switching to the Standard HUD.

| BetterBattle | Behavior |
| --- | --- |
| **ON** | Use BetterBattle's layout when the battle settings and active provider support it. |
| **OFF** | Use the game's battle interface with BetterMenus palette coverage. |
| **MOD** | Allow a detected custom battle interface to provide the layout while BetterMenus supplies menu palette coverage. |

#### Automatic pixel-art backdrops

BetterBattle includes **63 full-color, 320×180 pixel-art scenes**. Backgrounds are selected automatically from the encounter's location and circumstances, including caves, routes, water, buildings, supported gyms, Giovanni encounters, and the Elite Four.

Fishing and surfing can select different scenes. Some alternate and custom scenes are reserved for custom-spawn mods. Gym encounters without completed artwork retain a plain background.

The artwork keeps its full colors while the battle interface uses its menu palette. It fits the viewport height, crops horizontally on narrower screens, and extends its edge columns on wider screens. The nickname prompt returns to the game's blank background.

There is no separate backdrop switch. Art appears when BetterBattle is active and no external battle renderer owns the scene. An active 3D provider takes priority; merely installing an inactive provider does not hide the art.

See [Battle Backdrops](wiki/Battle-Backdrops.md) for the scene list and location mappings.

## Colors and options

Open **START → COLORS → BetterMenus**. Use **UP/DOWN** to select a row, **LEFT/RIGHT** to change a value, **A** to open a palette group, and **B** to return.

The menu palette is separate from the game's overall palette. Choose **Default** for the Game Boy, Black and White, OG Red, Advanced, and SGB menu themes, or **BetterMenus** for SoulSilver, HeartGold, FireRed, LeafGreen, Crystal, and Emerald. A **Groovy** group appears when the Groovy Palette mod is available.

Palette browsing previews your choice. Press **A** or **START** to keep it; **B** cancels the preview. The **DEFAULT** entry on the preceding COLORS screen opens the game's own palette controls.

| Option | Default | What it changes |
| --- | --- | --- |
| **MENU PALETTE** | **SOULSILVER** | Colors used by BetterMenus menus and panels; selected through the palette groups or mod options. |
| **Inverse** | **OFF** | Reverses the light-to-dark order of the menu palette. |
| **BetterPC** | **ON** | Enables the responsive Pokémon storage interface. |
| **BetterParty** | **ON** | Enables the responsive party interface. |
| **BetterBag** | **ON** | Enables the pocket-based bag interface. |
| **Menu Scale** | **100%** | Choose 100%, 90%, 80%, or 70% for supported in-game menus and dialogue. BetterPC, BetterBag, and BetterParty retain their responsive sizing. |
| **BetterBattle** | **ON** | Select ON, OFF, or MOD. ON requires WIDE + EXTENDED. |
| **Marquee Text** | **ON** | Scrolls menu labels that do not fit. |
| **Pokédex Indicator** | **DEFAULT** | BetterBattle's caught marker: OFF hides it, DEFAULT follows the menu palette, and RED uses red. |

These are new-install defaults; existing saved choices take precedence.

## Start Menu favorites

Highlight a Start Menu entry and press **SELECT** to pin or unpin it. Favorites display a heart and move to the top of the menu.

Start Menu favorites and item favorites are saved with your game. Use **SAVE** after changing them if you want to keep the changes when reloading.

## Using other mods

- **3D and voxel battles:** an active external scene provider suppresses BetterBattle's 2D background. A compatible provider can allow BetterBattle's panels over its scene. Your BetterBattle setting still applies; providers do not force an OFF setting on.
- **Custom battle interfaces:** use **MOD** for a detected provider's own interface. Installing a mod alone does not guarantee that it supports this integration.
- **Quality of Life:** its separate XP bar and caught indicator are switched off while BetterBattle or WIDE Extended is active, preventing duplicate indicators.
- **Crystal Animated Sprites with Shiny Visuals:** optional, with a dedicated compatibility integration. BetterBattle requires correctly transparent Crystal sprite assets, not this specific mod.
- **Groovy Palette & Frames:** exposes additional palette choices when available.
- **Separate Modern PC UI:** disable it before using this mod; the two are declared incompatible.

Mod authors can find the provider hooks, custom battle scenes, and integration examples in [Provider and Mod Compatibility](wiki/Compatibility.md). Custom settings-screen support is covered in [Mod Options Screen Compatibility](wiki/Mod-Options-Screen-Compatibility.md).

## Troubleshooting

- **BetterBattle will not enable:** check WIDE + EXTENDED, then turn BetterBattle ON again.
- **No pixel-art background:** check BetterBattle's mode, whether another provider is rendering the battle, and whether the encounter has completed artwork. Missing background assets also fall back to a plain field.
- **Background visible through a Pokémon:** check that the required Crystal battle sprites are active. Other sprite packs may contain transparent body pixels that need correction by their author.
- **Menu colors differ from the overworld:** these are separate palette choices. Change the menu theme under COLORS → BetterMenus.
- **Menu Scale does not resize BetterPC, BetterParty, or BetterBag:** these interfaces size themselves to the available screen area.

When reporting a problem, include your Gen1Recomp and Gen1BetterMenus versions, game version, enabled mods, relevant options, and a screenshot showing the issue.

## Licenses

See the [code license](licenses/CODE_LICENSE.md), [art license](licenses/ART_LICENSE.md), and [third-party notices](licenses/THIRD_PARTY_NOTICES.md).
