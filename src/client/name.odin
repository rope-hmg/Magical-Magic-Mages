package client

import "core:fmt"
import "core:math/rand"
import "core:runtime"
import "core:strings"

PARTS_A :: []string{
    "Mystical",
    "Mythical",
    "Arcane",
    "Mysterious",
    "Incredible",
    "Enigmatic",
    "Enchanted",
    "Magical",
    "Ancient",
    "Powerful",
    "Eternal",
    "Celestial",
    "Infernal",
}

PARTS_B :: []string{
    "Magic",
    "Wizardry",
    "Sorcery",
    "Enchantment",
    "Spell",
    "Incantation",
    "Hex",
    "Curse",
    "Charm",
}

PARTS_C :: []string{
    "Mage",
    "Wizard",
    "Sorcerer",
    "Warlock",
    "Enchanter",
}

// Caller is responisble for freeing the returned string
get_name :: proc() -> cstring {
    a := rand.choice(PARTS_A)
    b := rand.choice(PARTS_B)
    c := rand.choice(PARTS_C)

    builder := strings.builder_make(0, len(a) + len(b) + len(c) + 3)

    strings.write_string(&builder, a)
    strings.write_byte  (&builder, ' ')
    strings.write_string(&builder, b)
    strings.write_byte  (&builder, ' ')
    strings.write_string(&builder, c)
    strings.write_byte  (&builder, 0)

    name := strings.to_string(builder)

    return strings.unsafe_string_to_cstring(name)
}
