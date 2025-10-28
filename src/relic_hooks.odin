package main

import "game:platform"
import "game:relic"
import "game:wizard"

Relic_Hook_Data :: struct {
    damage: ^int,
    block:  ^wizard.Spell_Block,
}

Relic_Hook :: proc(p: ^platform.Platform, g: ^Game, r: ^relic.Relic_Instance, d: Relic_Hook_Data)

proc_relics_by_type :: proc(p: ^platform.Platform, g: ^Game, proc_type: relic.Proc_Type, data: Relic_Hook_Data) {
    for &r, relic_id in g.relics.instances {
        class := &relic.RELICS[relic_id]

        if relic_id  in g.relics.active && // Is Carmack right? Or should this go outside the loop?
           proc_type in class.proc_types
        {
                       r.proc_count -= 1
            procced := r.proc_count == 0

            if procced {
                g.battle_stats.relic_proc_counts[relic_id] += 1

                r.proc_count = class.proc_count

                RELIC_HOOKS[relic_id][proc_type](p, g, &r, data)
            }
        }
    }
}

RELIC_HOOKS := [relic.Relic][relic.Proc_Type]Relic_Hook {
    // Spell Relics
    // ============

    .Split_Diminish = #partial {
        .On_Block_Hit = proc(p: ^platform.Platform, g: ^Game, r: ^relic.Relic_Instance, d: Relic_Hook_Data) {

        },
    },

    // Character Relics
    // ================

    .Protective_Aura = #partial {
        .On_Player_Rest = proc(p: ^platform.Platform, g: ^Game, r: ^relic.Relic_Instance, d: Relic_Hook_Data) {
            aura         := &r.state.(relic.Protective_Aura)
            aura.strength = relic.RELICS[.Protective_Aura].state.(relic.Protective_Aura).strength
        },

        .On_Player_Hit = proc(p: ^platform.Platform, g: ^Game, r: ^relic.Relic_Instance, d: Relic_Hook_Data) {
            aura := &r.state.(relic.Protective_Aura)

            passed_through := max(0, d.damage^ - aura.strength)
            aura.strength   = max(0, aura.strength - d.damage^)
            d.damage^       = passed_through
        },
    },

    // Block Relics
    // ============

    .Harden_Blocks = #partial {
        .On_Player_Block_Restored = proc(p: ^platform.Platform, g: ^Game, r: ^relic.Relic_Instance, d: Relic_Hook_Data) {
            d.block.health += r.state.(relic.Harden_Blocks).extra_hits
        },
    },

    .Weaken_Blocks = #partial {
        .On_Enemy_Block_Restored = proc(p: ^platform.Platform, g: ^Game, r: ^relic.Relic_Instance, d: Relic_Hook_Data) {
            d.block.health = 1
        },
    },
}
