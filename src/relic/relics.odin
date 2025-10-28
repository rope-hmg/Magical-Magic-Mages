package relic

Proc_Type :: enum {
    On_Block_Hit,
    On_Enemy_Block_Restored,
    On_Enemy_Hit,
    On_Enemy_Poisoned,
    On_Player_Block_Restored,
    On_Player_Rest,
    On_Player_Hit,
    On_Player_Poisoned,
}

Relic_Class :: struct {
    state:      Relic_State,
    proc_types: bit_set[Proc_Type],
    proc_count: int,
}

Relic_Instance :: struct {
    state:       Relic_State,
    proc_count:  int,
}

Relics :: struct {
    active:    bit_set[Relic],
    instances: [Relic]Relic_Instance,
}

add :: proc(relics: ^Relics, relic: Relic) {
    if relic not_in relics.active {
        relics.active      += { relic }
        instance           := &relics.instances[relic]
        instance.state      = RELICS[relic].state
        instance.proc_count = RELICS[relic].proc_count
    }
}

Relic :: enum {
    // Spell Relics
    // ============

    Split_Diminish,     // Splits the spell in half on every hit, but diminishes the size eventually destroying the spell

    // Character Relics
    // ================

    Protective_Aura,    // Grants the wearer a protective migical aura that blocks incoming damage. The aura is replenished after every rest

    // Block Relics
    // ============
    Harden_Blocks,      // Adds health to the players blocks
    Weaken_Blocks,      // Makes the enemies blocks only take a single hit
}

Relic_State :: union {
    // Spell Relics
    // ============
    Split_Diminish,

    // Character Relics
    // ================
    Protective_Aura,

    // Block Relics
    // ============
    Harden_Blocks,
}

Split_Diminish :: struct {
    split_count: int,
}

Protective_Aura :: struct {
    strength: int,
}

Harden_Blocks :: struct {
    extra_hits: int,
}

RELICS := [Relic]Relic_Class {
    .Split_Diminish = {
        state      = Split_Diminish { split_count = 3 },
        proc_types = { .On_Block_Hit },
        proc_count = 1,
    },

    .Protective_Aura = {
        state      = Protective_Aura { strength = 50 },
        proc_types = { .On_Player_Rest, .On_Player_Hit },
        proc_count = 1,
    },

    .Harden_Blocks = {
        state      = Harden_Blocks { extra_hits = 2 },
        proc_types = { .On_Player_Block_Restored },
        proc_count = 1,
    },

    .Weaken_Blocks = {
        state      = nil,
        proc_types = { .On_Enemy_Block_Restored },
        proc_count = 1,
    },
}
