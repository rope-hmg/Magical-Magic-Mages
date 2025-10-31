package main

import "core:math/linalg/glsl"
import "core:fmt"

import "vendor:box2d"

import "game:platform"
import "game:wizard"
import "game:adventure"

Character_Proc_Type :: enum {
    On_Turn_Start,
    On_Turn_End,
    On_Block_Hit,
    On_Block_Restored,
    On_Shoot_Ball,
    On_Take_Damage,
    On_Take_Poison,
}

Character_Hook_Data :: struct {
    damage: ^int,
    block:  ^wizard.Spell_Block,
}

// Character_Hook :: proc(p: ^platform.Platform, g: ^Game, c: ^wizard.Character_Instance, d: Character_Hook_Data)
Character_Hook :: proc(p: ^platform.Platform, g: ^Game, d: Character_Hook_Data)

player_hook :: #force_inline proc(g: ^Game, type: Character_Proc_Type) -> Character_Hook {
    player := g.player.stats.character

    return PLAYER_HOOKS[player][type]
}

monster_hook :: #force_inline proc(g: ^Game, type: Character_Proc_Type) -> Character_Hook {
    monster := adventure.stage(&g.adventure).monster

    return MONSTER_HOOKS[monster][type]
}

proc_character :: proc(
    p:   ^platform.Platform,
    g:   ^Game,
    type: Character_Proc_Type,
    data: Character_Hook_Data,
) {
    hook: Character_Hook

    switch g.entities.turn {
        case .Player: hook =  player_hook(g, type)
        case .Enemy:  hook = monster_hook(g, type)
    }

    if hook != nil {
        hook(p, g, data)
    }
}

_default_on_shoot_ball :: proc(p: ^platform.Platform, g: ^Game, d: Character_Hook_Data) {
    aim_direction := glsl.normalize(platform.mouse_position(p.mouse) - g.ball_position)
    num_balls     := 2
    shoot_speed   := f32(20.0)

    SPREAD :: glsl.TAU / 8.0

    step  := SPREAD / f32(num_balls)
    angle := glsl.acos(glsl.dot(aim_direction, glsl.vec2 { 1, 0 })) - SPREAD

    for i in 0..<num_balls {
        rot := box2d.MakeRot(angle + (step * f32(i)))
        dir := box2d.RotateVector(rot, aim_direction)

        create_ball(
            g,
            g.ball_position,
            dir * shoot_speed,
        )
    }
}

PLAYER_HOOKS := [wizard.Character][Character_Proc_Type]Character_Hook {
    .Old_Man = #partial {
        .On_Shoot_Ball = _default_on_shoot_ball,
    },

    .Twins = #partial {
        .On_Shoot_Ball = _default_on_shoot_ball,
    },
}

MONSTER_HOOKS := [wizard.Monster][Character_Proc_Type]Character_Hook {
    .Electric_Spider = #partial {
        .On_Shoot_Ball = _default_on_shoot_ball,
    },

    .Skeleton = #partial {
        .On_Shoot_Ball = _default_on_shoot_ball,
    },

    .Poison_Toad = #partial {
        .On_Shoot_Ball = _default_on_shoot_ball,
    },

    .Lightning_Wolf = #partial {
        .On_Shoot_Ball = _default_on_shoot_ball,
    },

    .Goblin_Shaman = #partial {
        .On_Shoot_Ball = _default_on_shoot_ball,
    },

    .Troll = #partial {
        .On_Shoot_Ball = _default_on_shoot_ball,
    },

    .Fire_Dragon_Baby = #partial {
        .On_Shoot_Ball = _default_on_shoot_ball,
    },

    .Fire_Dragon = #partial {
        .On_Shoot_Ball = _default_on_shoot_ball,
    },

    .Ice_Dragon_Baby = #partial {
        .On_Shoot_Ball = _default_on_shoot_ball,
    },

    .Ice_Dragon = #partial {
        .On_Shoot_Ball = _default_on_shoot_ball,
    }
}
