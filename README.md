# Info and Such

Run the game with:
```bash
clear; make-ld
```

Run the level designer with:
```bash
clear; make-ld
```

# TODO

* Make the red less red. It's far too red.
* Implement the diamond, and pentagon collision shapes.
* Tweak the bouncyness of things
* Make smaller sprites for when the blocks are broken/disabled

# GAME WORLD

* Town
* Swamp  Adventure
* Desert Adventure
* Ice    Adventure

Shops, etc

# BLOCKS

Blue   = Ice
Purple = Poison
Red    = Fire
Yellow = Lightning
Green  = Restoration

* Ice:         When hit, freezes some number of opponent blocks. Frozen blocks have to be hit multiple times to break
* Poison:      When hit, adds poison dots to the opponent. Opponent takes `poison_damage` every turn they have a dot, dot is decreased by 1 every turn.
* Fire:        When hit, either thaws caster's blocks, or burns blocks opponent's blocks. Burning blocks break after two turns. Hitting burning blocks does damage to the caster, but extinguishes the flame
* Lightning:   When hit, zaps and breaks blocks in straight lines around itself (should it avoid self damaging affects applied to blocks?)
* Restoration: When hit, restores some amount of the caster's health

Ice Staff:
* Increase number of frozen blocks
* Increase strength of ice (frozen blocks take more hits to break)

Ice Ring:
* Cool blocks. Some number of blocks are cooled which makes them harder to set on fire, but not harder to break like frozen blocks
* Cool dude.   Reduces damage taken from breaking flaming blocks

Poison Staff:
* Deadly Poison. Dot becomes a multiplier (e.g. Enemy takes `poison_damage * dot` every turn, dot is still reduced by 1 every turn)
* Lingering Dot. Once added, the dot will never decrease below 1
* Strong Poison. Multiple dots per block

Poison Ring:
* Poison Master. Hitting poison blocks cures a dot on the caster if they have any, combines with Strong Poison to cure multiple dots

Fire Staff:
* Increase number of burned/thawed blocks
* Decrease the number of turns for flames to destroy opponent blocks
* Increase burning damage done to the opponent when hitting flaming blocks

Fire Ring:
* Start turn with the damage from burned opponent blocks

Lightning Staff:
* Increase chain length by one
* Electrify blocks. Similar to burning blocks, damages the caster when hitting electrified blocks, and shoots one lightning chain breaking a block without adding damage to the spell

Lightning Ring:
* ???

Restoration Staff:
* Increase amount of health healed
* Restore some number of grey blocks (combine into single restoration block?)

Restoration Ring:
* Adds defence points which take damage first before the caster does




