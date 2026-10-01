# Gen1Better

Widescreen presentation, customizable menu colors, 2D battle backdrops, cinematic story staging, and the BetterPC, BetterParty, BetterPokedex, BetterTrainerCard, BetterBag, BetterModManager, BetterOptions, BetterBattle, and BetterScenes suites for Gen1Recomp.

Choose each interface independently. Turning off a Better interface option keeps the corresponding classic interface with Gen1Better's widescreen and palette support.

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

### BetterPokedex and BetterTrainerCard

Responsive Pokédex and trainer-card interfaces, each enabled by its own default-ON setting.

### BetterModManager and BetterOptions

BetterModManager provides a responsive mod manager. BetterOptions provides tabbed settings for **SPEED**, **VIDEO**, **GRAPHICS**, **AUDIO**, **BATTLE OPTIONS**, **CONTROLS**, **EXTRAS**, and **MODS**. In EXTRAS, select Gen1Better and press **A** to enter its settings pane; **B** returns to the list. Both interfaces default to ON.

### BetterBattle

A WIDE Extended battle interface with compact Pokémon status panels, command and move panels, HP and XP bars, a caught indicator, trainer portraits, and party indicators.

To enable it:

1. Set the game's **BATTLE LAYOUT** to **WIDE**.
2. Set **BATTLE HUD** to **EXTENDED**.
3. Open **START → OPTION → EXTRAS → Gen1Better**.
4. Enable **BetterBattles** for the 2D stage and **BetterBattle UI** for the panels. They are independent ON/OFF toggles.
5. Use battle sprites with the transparency mask described below.

Both toggles require WIDE + EXTENDED. Incompatible layout changes turn both OFF; set the layout first, then enable the desired toggles. Turn **both** OFF before switching to the Standard HUD.

An active external scene provider takes priority over the 2D stage and can independently allow BetterBattle's panels. The old ON/OFF/MOD selector has been replaced; MOD is now an automatic provider mode rather than a selectable option.

#### Automatic pixel-art backdrops

BetterBattle includes **63 full-color, 320×180 pixel-art scenes**. Backgrounds are selected automatically from the encounter's location and circumstances, including caves, routes, water, buildings, supported gyms, Giovanni encounters, and the Elite Four.

Fishing and surfing can select different scenes. Some alternate and custom scenes are reserved for custom-spawn mods. Gym encounters without completed artwork retain a plain background.

The artwork keeps its full colors while the battle interface uses its menu palette. It fits the viewport height, crops horizontally on narrower screens, and extends its edge columns on wider screens. The nickname prompt returns to the game's blank background.

The **BetterBattles** toggle controls the 2D stage independently of **BetterBattle UI**. Art appears when BetterBattles is active and no external battle renderer owns the scene. An active 3D provider takes priority; merely installing an inactive provider does not hide the art.

See [Battle Backdrops](https://github.com/syybott/Gen1Better/wiki/Battle-Backdrops) for the scene list and location mappings.

## Sprites

BetterBattle requires battle sprites with a correctly defined transparency mask: the background must be transparent while the Pokémon itself, including white areas, remains opaque. Crystal Animated Sprites provides compatible assets; any sprite pack meeting this requirement can be used.

## BetterScenes

A 320×180 story stage for narrative cutscenes outside combat. Mod authors can register backdrops, stage actors, show dialogue bubbles and subtitles, run sequences, and add camera shake, tints, flashes, vignettes, and weather.

The stage fits the viewport while preserving its aspect ratio. Pixel snapping and selectable image scaling are available; arbitrary viewport sizes can use a fractional stage scale.

A consuming mod must drive **update**, forward advance/skip input, and arrange completion cleanup. Gen1Better draws the active stage. Actor anchors use feet-based coordinates; bubbles do not automatically follow every actor transition.

Battle handoffs provide transition timing, a token, and callbacks. The consuming mod starts the encounter, applies any music or atmosphere data, and returns the result for outcome branching.

See [BetterScenes](https://github.com/syybott/Gen1Better/wiki/BetterScenes) for setup and examples and [Provider and Mod Compatibility](https://github.com/syybott/Gen1Better/wiki/Compatibility#7-betterscenes-story-stage-exports) for the API reference.

## 🎨 For Artists & Creators: Launch Pad

Want to add your own artwork, cutscenes, or custom battles to Gen1Better? Choose what you want to do:

- **[Make a Custom Battle Backdrop Pack](https://github.com/syybott/Gen1Better/wiki/Artist-Backdrop-Packs)**: No engine changes required. Learn the 3 Safe Doors, grab copy-paste `main.lua` templates, and drop your 320×180 PNGs into a standalone mod folder.
- **[Make a Cinematic Story Cutscene (BetterScenes)](https://github.com/syybott/Gen1Better/wiki/BetterScenes)**: Direct narrative scenes outside of battle with dialogue bubbles, character staging, camera shakes, and weather.
- **[Style & Customize Floor Shadows (BetterShadows)](https://github.com/syybott/Gen1Better/wiki/Battle-Backdrops#shadow-system-and-scene-interaction)**: Tune feathered contact shadows for water, caves, space, or custom Pokémon species.
- **[Trigger Custom Battles & Dynamic Arena Transitions](https://github.com/syybott/Gen1Better/wiki/Battle-Backdrops#custom-spawn-hook)**: Script custom wild/boss encounter arenas or lerp elevations mid-battle.
- **[Full Developer & API Contract](https://github.com/syybott/Gen1Better/wiki/Compatibility)**: Complete Lua exports, provider hooks, and screen markers.

👉 **Browse the full [Artist & Creator Launch Pad](https://github.com/syybott/Gen1Better/wiki/Artists) on the Wiki.**

## Colors and options

Open **START → OPTION → GRAPHICS → COLORS** to choose the game's palette while viewing the overworld. When Groovy Palette & Frames is installed, choose **DEFAULT** or **GROOVY** first. Browse with the directional controls, press **A** or **START** to keep a preview, and press **B** to cancel it.

The menu palette and frames are separate Gen1Better settings under **START → OPTION → EXTRAS → Gen1Better**. Choose a **MENU PALETTE** and **BetterFrames** there. The menu palette includes Game Boy, Black and White, OG Red, Advanced, SGB, SoulSilver, HeartGold, FireRed, LeafGreen, Crystal, Emerald, ten palettes numbered to match the FireRed frames, and Groovy choices. BetterFrames includes **OG**, **Hybrid**, and **FR** designs. OG **DEFAULT** keeps the current Game Boy frame. Hybrid follows the selected menu palette while preserving the Poké Ball colors in its Poké Ball design; FR uses the FireRed colors. Dialogue and location popups use matching artwork automatically.

| Option | Saved key | Default | What it changes |
| --- | --- | --- | --- |
| **BetterFrames** | `better_frames` | **OG DEFAULT** (`og:default`) | Frame artwork for menus, dialogue, location popups, and battle boxes. |
| **MENU PALETTE** | `palette` | **SOULSILVER** (`soulsilver`) | Menu and panel colors, subject to the game's CLASSIC palette lock. |
| **Inverse** | `inverse` | **OFF** | Reverses the menu palette's light-to-dark order when the palette is unlocked. |
| **BetterPC** | `modern_pc_ui` | **ON** | Responsive Pokémon storage. |
| **BetterParty** | `modern_party_ui` | **ON** | Responsive party screen. |
| **BetterPokedex** | `modern_pokedex_ui` | **ON** | Responsive Pokédex. |
| **BetterTrainerCard** | `better_trainer_card` | **ON** | Responsive trainer card. |
| **BetterBag** | `modern_bag_ui` | **ON** | Pocket-based bag interface. Expanded inventory limits apply independently. |
| **BetterModManager** | `better_mod_manager` | **ON** | Responsive mod manager. |
| **BetterOptions** | `better_options` | **ON** | Tabbed game options screen. |
| **Menu Scale** | `menu_scale` | **100%** (`100`) | 100%, 90%, 80%, or 70% for eligible compact menus and dialogue. The seven responsive interfaces keep their own sizing. |
| **BetterBattles** | `better_battles` | **ON** | Gen1Better's 2D battle stage and backdrops. Requires WIDE + EXTENDED. |
| **BetterBattle UI** | `better_battle_ui` | **ON** | BetterBattle's status, command, and move panels. Requires WIDE + EXTENDED. |
| **BetterAnimations** | `better_animations` | **ON** | Enhanced move animations in the supported battle rendering path. |
| **Marquee Text** | `marquee_text` | **ON** | Scrolls labels that do not fit. |
| **Pokédex Indicator** | `pokedex_indicator` | **DEFAULT** (`default`) | BetterBattle's caught marker: OFF, DEFAULT (menu palette), or RED. |

These are defaults for the current option schema; saved choices take precedence. CLASSIC game palettes lock menu colors and restrict BetterFrames to OG until the palette-switch prompt is accepted. All 52 menu themes are built in; Groovy Palette & Frames adds choices to the game's palette browser.

The old `modern_battle_ui` selector has been replaced by two toggles. Review both after upgrading. See [all settings and changes since 1.1.2](https://github.com/syybott/Gen1Better/wiki/Extra-Features) for palette names, frame choices, and option behavior.

## Start Menu favorites

Highlight a Start Menu entry and press **SELECT** to pin or unpin it. Favorites display a heart and move to the top of the menu.

Start Menu favorites and item favorites are saved with your game. Use **SAVE** after changing them if you want to keep the changes when reloading.

## Using other mods

- **3D and voxel battles:** an active external scene provider suppresses BetterBattle's 2D background. A compatible provider can allow BetterBattle's panels over its scene. Your BetterBattle setting still applies; providers do not force an OFF setting on.
- **Custom battle interfaces:** turn **BetterBattle UI** OFF to use another interface, or let an integrated provider select its automatic interface mode. Installing a mod alone does not guarantee that it supports this integration.
- **Quality of Life:** its separate XP bar and caught indicator settings are written OFF when BetterBattle UI or WIDE + EXTENDED is active. They are not automatically restored afterward.
- **Crystal Animated Sprites with Shiny Visuals:** optional, with a dedicated compatibility integration. BetterBattle requires a correct sprite transparency mask; compatible packs can supply it.
- **Groovy Palette & Frames:** adds choices to the game's palette browser. Gen1Better's menu themes are built in.
- **Separate Modern PC UI:** disable it before using this mod; the two are declared incompatible.

Mod authors and artists can find the [Artist & Creator Launch Pad](https://github.com/syybott/Gen1Better/wiki/Artists), provider hooks, custom battle scenes, and integration examples in [Provider and Mod Compatibility](https://github.com/syybott/Gen1Better/wiki/Compatibility). Custom settings-screen support is covered in [Mod Options Screen Compatibility](https://github.com/syybott/Gen1Better/wiki/Mod-Options-Screen-Compatibility).

## Troubleshooting

- **BetterBattle will not enable:** check WIDE + EXTENDED, then enable the desired BetterBattles and BetterBattle UI toggles again.
- **No pixel-art background:** check BetterBattles, whether another provider is rendering the battle, and whether the encounter has completed artwork. Missing background assets also fall back to a plain field.
- **Background visible through a Pokémon:** check the active sprite pack has a correct body/background transparency mask. Other sprite packs may contain transparent body pixels that need correction by their author.
- **Menu colors differ from the overworld:** these are separate palette choices. Change the menu theme under **OPTION → EXTRAS → Gen1Better**.
- **Menu Scale does not resize the seven responsive interfaces:** these interfaces size themselves to the available screen area.

When reporting a problem, include your Gen1Recomp and Gen1Better versions, game version, enabled mods, relevant options, and a screenshot showing the issue.

## Licenses

See the [code license](licenses/CODE_LICENSE.md), [art license](licenses/ART_LICENSE.md), and [third-party notices](licenses/THIRD_PARTY_NOTICES.md).
