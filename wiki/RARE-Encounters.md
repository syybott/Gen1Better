# RARE Encounters

**RARE** appears below the enemy HP bar in BetterBattle UI when the encountered Pokémon's species and level combination has a positive encounter chance of **5% or less**

## What the label tells you

The label describes how uncommon that particular species and level combination is in the encounter table used for this battle. The same species can qualify at one level or location and appear more frequently at another.

These percentages describe the choice of Pokémon once an encounter occurs. They do not describe your chance of starting a battle on each step.

## How the chance is calculated

For encounters drawn from a weighted encounter table, Gen1Better adds together all entries matching both the Pokémon's species and its level

If the same species and level appears more than once, those entries contribute to one combined chance

Fishing uses the selected rod's encounter pool. The supported standard fishing pools contain up to four equally likely entries, so their individual outcomes do not reach the 5% threshold.

## When a label may be absent

Trainer battles do not receive the RARE label

Scripted encounters and encounters changed by other mods may lack the information needed to calculate a reliable chance. Gen1Better leaves the label hidden when it cannot establish that chance.

## Other indicators below the HP bar

The enemy information row can also show:

- **Status condition:** the opposing Pokémon's current status
- **Shiny sparkle:** the opposing Pokémon is shiny
- **Stored gender symbols:** with Gender Mod enabled, the genders of that species represented in your PC boxes
- **Caught marker:** whether you have already caught that species

RARE describes encounter frequency. Shiny status, stored genders, and caught status are separate indicators.

See [Settings and Customization](https://github.com/syybott/Gen1Better/wiki/Extra-Features#choose-betterbattles-and-betterbattle-ui) for the battle presentation options
