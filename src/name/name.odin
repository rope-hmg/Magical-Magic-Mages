package name

import "core:math/rand"
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
    "Mages",
    "Wizards",
    "Sorcerers",
    "Warlocks",
    "Enchanters",
}

// Caller is responisble for freeing the returned string
get_name :: proc() -> cstring {
    a := rand.choice(PARTS_A)
    b := rand.choice(PARTS_B)
    c := rand.choice(PARTS_C)

    name := strings.concatenate({ a, " ", b, " ", c, "\x00" })

    return strings.unsafe_string_to_cstring(name)
}