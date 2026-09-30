# Extra Features: Start Menu, Favorites, Palettes, and UI Choices

Gen1Better keeps the original Gen 1 menu structure and adds optional widescreen interfaces, BetterPC, BetterParty, BetterBag, BetterBattle, and the BetterScenes cinematic staging system. The extra controls are available from the in-game Start Menu.

## Open the Gen1Better options

1. Enter the game and press **START**.
2. Select **OPTION**, then **EXTRAS**.
3. Select **Gen1Better**.

The Gen1Better settings include the menu palette, frames, and interface switches. Press **A** to focus its settings, use **UP/DOWN** to select a row and **LEFT/RIGHT** to change a value, and press **B** to return to the Extras list.

## Favorite and pin Start Menu entries

BetterMenus lets you pin frequently used Start Menu entries.

1. Open the Start Menu with **START**.
2. Highlight the entry you want to pin.
3. Press **SELECT**.

A heart appears beside a favorite entry, and favorite entries move to the top of the menu. Press **SELECT** again to unpin the highlighted entry.

Use the game's **SAVE** entry after changing favorites. The favorite list is part of the saved game data; unsaved changes can be lost when the game closes or the save is reloaded.

The **ITEM** entry has its own favorite list:

1. Open **START > ITEM**.
2. Highlight an item.
3. Press **START** to favorite or unfavorite it.

Favorite items move to the top and are marked with a heart. **SELECT** continues to provide the bag's item-sorting action.

## Choose the game palette

The engine's palette choice and Gen1Better's menu palette are separate settings.

To choose the game's palette:

1. Open **OPTION**.
2. Open **GRAPHICS**.
3. Open **COLORS**.
4. Choose the palette category and color you want while viewing the overworld. If Groovy Palette & Frames is installed, first choose **DEFAULT** or **GROOVY**.

The upstream screen provides **FULL COLOR**, **SINGLE COLOR**, **GREYSCALE**, **MONOCHROME**, and **OG** categories. The **OG** category contains the familiar Game Boy, Red, Blue, Yellow, SGB, and related original-style modes supplied by Gen1Recomp.

That setting controls the game's normal palette selection. It is separate from the Gen1Better menu-palette choice below.

## Choose a BetterMenus menu palette

1. Open **START > OPTION > EXTRAS > Gen1Better**.
2. Select **MENU PALETTE** and choose a palette. The choices include `SOULSILVER`, `HEARTGOLD`, `FIRERED`, `LEAFGREEN`, `CRYSTAL`, `EMERALD`, Game Boy themes, numbered FireRed frame palettes, and Groovy entries.

Choose **BetterFrames** in the same list to change the menu frame.

The menu palette applies to the widescreen menu border, dialogue frames, BetterPC, BetterParty, BetterBag, and BetterBattle's menu overlays.

### Keep the original game palette on the menus

If you want the classic Game Boy, Red, Blue, or Yellow palette to remain in control of the menus, leave Gen1Better's existing menu-palette override/unlock gate **disabled**. Gen1Better will then leave those menu colors to the upstream palette selected under **OPTIONS > GRAPHICS > COLORS**.

When the gate is enabled, selecting a BetterMenus or Groovy entry allows that menu palette to color Gen1Better-owned menus and panels. The gate may be shown as **UNLOCK MENU PALETTE** in the mod options.

The **Inverse** switch reverses the selected four-color menu ramp. It changes the light and dark order without changing the menu layout.

## Choose BetterPC, BetterParty, BetterBag, BetterBattles, and BetterBattle UI

Gen1Better itself supplies the widescreen menu layer. The BetterPC, BetterParty, BetterBag, BetterBattles, and BetterBattle UI options select their respective interfaces. Turn off the Better option for any screen where you want Gen1Better's Game Boy-style widescreen presentation:

| Setting | OFF keeps |
| --- | --- |
| **BetterPC** | Gen1Better's widescreen classic Bill's PC interface |
| **BetterParty** | Gen1Better's widescreen classic Party menu |
| **BetterBag** | Gen1Better's widescreen classic bag/list interface, including its larger visible item list |
| **BetterBattles** | Classic battle background without 320×180 pixel-art backdrops, sprite shadow engine, or scene transitions |
| **BetterBattle UI** | The upstream WIDE battle presentation (or installed custom battle UI mod) with Gen1Better palette coverage |

With Gen1Better enabled and these options set to **OFF**, you get the Game Boy-style Gen1Better widescreen presentation with BetterPC, BetterParty, BetterBag, BetterBattles, and BetterBattle UI disabled.

The BetterMenus options also include:

- **Menu Scale**: scales supported stock menus. BetterPC, BetterParty, BetterBag, and Gen1Better's own responsive screens keep their responsive size.
- **Marquee Text**: enables or disables scrolling for labels that do not fit in a menu row.
- **Pokédex Indicator**: chooses **OFF**, **DEFAULT**, or **RED** for the caught-Pokémon marker used by BetterBattle.
