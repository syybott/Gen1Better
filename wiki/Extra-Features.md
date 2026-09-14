# Extra Features: Start Menu, Favorites, Palettes, and UI Choices

Gen1BetterMenus keeps the original Gen 1 menu structure and adds optional widescreen interfaces and BetterPC, BetterParty, BetterBag, and BetterBattle. The extra controls are available from the in-game Start Menu.

## Open the BetterMenus options

1. Enter the game and press **START**.
2. Select **COLORS**.
3. Select **BetterMenus**.

The **BetterMenus** screen contains the menu-palette groups and the BetterMenus feature switches. Use **UP** and **DOWN** to select a row, **LEFT** and **RIGHT** to change a value, **A** to open a palette group, and **B** to return.

The **COLORS** screen also contains:

- **DEFAULT**: the upstream Gen1Recomp palette screen.
- **GROOVY**: the Groovy Palette & Frames palettes, when that mod is installed.
- **BetterMenus**: BetterMenus palettes and BetterMenus feature switches.

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

The engine's palette choice and BetterMenus' menu palette are separate settings.

To choose the game's palette:

1. Open **OPTION**.
2. Open **GRAPHICS**.
3. Open **COLORS**.
4. Choose the upstream palette category and color you want.

The upstream screen provides **FULL COLOR**, **SINGLE COLOR**, **GREYSCALE**, **MONOCHROME**, and **OG** categories. The **OG** category contains the familiar Game Boy, Red, Blue, Yellow, SGB, and related original-style modes supplied by Gen1Recomp.

That setting controls the game's normal palette selection. It is separate from the BetterMenus menu-palette choice below.

## Choose a BetterMenus menu palette

1. Open **START > COLORS > BetterMenus**.
2. Open one of the palette groups.
3. Move through the choices with **LEFT** and **RIGHT** (or **UP** and **DOWN**).
4. Press **A** or **START** to keep the selected palette. Press **B** to leave the group without keeping the temporary choice.

The available groups are:

- **Default**: `GAME BOY`, `BLACK AND WHITE`, `OG RED`, `ADVANCED`, and `SGB`.
- **BetterMenus**: `SOULSILVER`, `HEARTGOLD`, `FIRERED`, `LEAFGREEN`, `CRYSTAL`, and `EMERALD`.
- **Groovy**: the installed Groovy Palette & Frames entries. This group is shown only when that mod is available.

For additional Groovy palettes and frames, see the [Groovy Palette & Frames repository](https://github.com/MadeinTaly/gen1recomp-groovy-palette-frames).

### Keep the original game palette on the menus

If you want the classic Game Boy, Red, Blue, or Yellow palette to remain in control of the menus, leave BetterMenus' existing menu-palette override/unlock gate **disabled**. BetterMenus will then leave those menu colors to the upstream palette selected under **OPTIONS > GRAPHICS > COLORS**.

When the gate is enabled, selecting a BetterMenus or Groovy entry allows that menu palette to color BetterMenus-owned menus and panels. The gate may be shown as **UNLOCK MENU PALETTE** in the mod options.

The **Inverse** switch reverses the selected four-color menu ramp. It changes the light and dark order without changing the menu layout.

## Choose BetterPC, BetterParty, BetterBag, and BetterBattle

BetterMenus itself supplies the widescreen menu layer. The BetterPC, BetterParty, BetterBag, and BetterBattle options select their respective interfaces. Turn off the Better option for any screen where you want BetterMenus' Game Boy-style widescreen presentation:

| Setting | OFF keeps |
| --- | --- |
| **BetterPC** | BetterMenus' widescreen classic Bill's PC interface |
| **BetterParty** | BetterMenus' widescreen classic Party menu |
| **BetterBag** | BetterMenus' widescreen classic bag/list interface, including its larger visible item list |
| **BetterBattle** | the upstream WIDE battle presentation with BetterMenus palette coverage |

With BetterMenus enabled and these four options set to **OFF**, you get the Game Boy-style BetterMenus widescreen presentation with BetterPC, BetterParty, BetterBag, and BetterBattle disabled.

The BetterMenus options also include:

- **Menu Scale**: scales supported stock menus. BetterPC, BetterParty, BetterBag, and BetterMenus' own responsive screens keep their responsive size.
- **Marquee Text**: enables or disables scrolling for labels that do not fit in a menu row.
- **Pokédex Indicator**: chooses **OFF**, **DEFAULT**, or **RED** for the caught-Pokémon marker used by BetterBattle.
