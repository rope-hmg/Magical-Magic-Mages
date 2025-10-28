package main

import "core:math/linalg/glsl"
import "core:fmt"

import "vendor:box2d"

import "game:platform"
import "game:wizard"

Character_Hooks :: struct {
    on_turn_start:  proc(p: ^platform.Platform, g: ^Game),
    on_turn_end:    proc(p: ^platform.Platform, g: ^Game),
    on_shoot_ball:  proc(p: ^platform.Platform, g: ^Game),
    on_block_hit:   proc(p: ^platform.Platform, g: ^Game, b: ^wizard.Spell_Block),
    on_take_damage: proc(p: ^platform.Platform, g: ^Game, d: ^int),
    on_take_poison: proc(p: ^platform.Platform, g: ^Game, d: ^int),
}

_nil_on_turn_start  :: proc(p: ^platform.Platform, g: ^Game) {}
_nil_on_turn_end    :: proc(p: ^platform.Platform, g: ^Game) {}
_nil_on_block_hit   :: proc(p: ^platform.Platform, g: ^Game, b: ^wizard.Spell_Block) {}
_nil_on_take_damage :: proc(p: ^platform.Platform, g: ^Game, d: ^int) {}
_nil_on_take_poison :: proc(p: ^platform.Platform, g: ^Game, d: ^int) {}

_default_on_shoot_ball :: proc(p: ^platform.Platform, g: ^Game) {
    variable := glsl.normalize(platform.mouse_position(p.mouse) - g.ball_position)
    num_balls := 2

    SPREAD :: glsl.TAU / 8.0

    // TODO: Make the numbers right Mason
    step  := SPREAD / f32(num_balls)
    angle := glsl.acos(glsl.dot(variable, glsl.vec2 { 1, 0 })) - SPREAD
    fmt.println(step)

    for i in 0..<num_balls {
        r := box2d.MakeRot(angle + (step * f32(i)))
        fuck := box2d.RotateVector(r, variable)

        fmt.println(angle, fuck)

        create_ball(
            g,
            g.ball_position,
            fuck,
        )
    }
}

PLAYER_HOOKS := [wizard.Character]Character_Hooks {
    .Old_Man = {
        on_turn_start  = _nil_on_turn_start,
        on_turn_end    = _nil_on_turn_end,
        on_shoot_ball  = _default_on_shoot_ball,
        on_block_hit   = _nil_on_block_hit,
        on_take_damage = _nil_on_take_damage,
        on_take_poison = _nil_on_take_poison,
    },

    .Twins = {
        on_turn_start  = _nil_on_turn_start,
        on_turn_end    = _nil_on_turn_end,
        on_shoot_ball  = _default_on_shoot_ball,
        on_block_hit   = _nil_on_block_hit,
        on_take_damage = _nil_on_take_damage,
        on_take_poison = _nil_on_take_poison,
    },
}

ENEMY_HOOKS := [wizard.Monster]Character_Hooks {
    .Electric_Spider = {
        on_turn_start  = _nil_on_turn_start,
        on_turn_end    = _nil_on_turn_end,
        on_shoot_ball  = _default_on_shoot_ball,
        on_block_hit   = _nil_on_block_hit,
        on_take_damage = _nil_on_take_damage,
        on_take_poison = _nil_on_take_poison,
    },

    .Skeleton = {
        on_turn_start  = _nil_on_turn_start,
        on_turn_end    = _nil_on_turn_end,
        on_shoot_ball  = _default_on_shoot_ball,
        on_block_hit   = _nil_on_block_hit,
        on_take_damage = _nil_on_take_damage,
        on_take_poison = _nil_on_take_poison,
    },

    .Poison_Toad = {
        on_turn_start  = _nil_on_turn_start,
        on_turn_end    = _nil_on_turn_end,
        on_shoot_ball  = _default_on_shoot_ball,
        on_block_hit   = _nil_on_block_hit,
        on_take_damage = _nil_on_take_damage,
        on_take_poison = _nil_on_take_poison,
    },

    .Lightning_Wolf = {
        on_turn_start  = _nil_on_turn_start,
        on_turn_end    = _nil_on_turn_end,
        on_shoot_ball  = _default_on_shoot_ball,
        on_block_hit   = _nil_on_block_hit,
        on_take_damage = _nil_on_take_damage,
        on_take_poison = _nil_on_take_poison,
    },

    .Goblin_Shaman = {
        on_turn_start  = _nil_on_turn_start,
        on_turn_end    = _nil_on_turn_end,
        on_shoot_ball  = _default_on_shoot_ball,
        on_block_hit   = _nil_on_block_hit,
        on_take_damage = _nil_on_take_damage,
        on_take_poison = _nil_on_take_poison,
    },

    .Troll = {
        on_turn_start  = _nil_on_turn_start,
        on_turn_end    = _nil_on_turn_end,
        on_shoot_ball  = _default_on_shoot_ball,
        on_block_hit   = _nil_on_block_hit,
        on_take_damage = _nil_on_take_damage,
        on_take_poison = _nil_on_take_poison,
    },

    .Fire_Dragon_Baby = {
        on_turn_start  = _nil_on_turn_start,
        on_turn_end    = _nil_on_turn_end,
        on_shoot_ball  = _default_on_shoot_ball,
        on_block_hit   = _nil_on_block_hit,
        on_take_damage = _nil_on_take_damage,
        on_take_poison = _nil_on_take_poison,
    },

    .Fire_Dragon = {
        on_turn_start  = _nil_on_turn_start,
        on_turn_end    = _nil_on_turn_end,
        on_shoot_ball  = _default_on_shoot_ball,
        on_block_hit   = _nil_on_block_hit,
        on_take_damage = _nil_on_take_damage,
        on_take_poison = _nil_on_take_poison,
    },

    .Ice_Dragon_Baby = {
        on_turn_start  = _nil_on_turn_start,
        on_turn_end    = _nil_on_turn_end,
        on_shoot_ball  = _default_on_shoot_ball,
        on_block_hit   = _nil_on_block_hit,
        on_take_damage = _nil_on_take_damage,
        on_take_poison = _nil_on_take_poison,
    },

    .Ice_Dragon = {
        on_turn_start  = _nil_on_turn_start,
        on_turn_end    = _nil_on_turn_end,
        on_shoot_ball  = _default_on_shoot_ball,
        on_block_hit   = _nil_on_block_hit,
        on_take_damage = _nil_on_take_damage,
        on_take_poison = _nil_on_take_poison,
    }
}
