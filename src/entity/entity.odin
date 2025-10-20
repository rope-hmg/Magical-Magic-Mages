package entity

import "core:math/linalg/glsl"

import "vendor:box2d"

import "game:wizard"

Entity :: struct {
    health:   int,
    damage:   int,
    arena:    wizard.Spell_Arena,
    strength: wizard.Elements,
}

Turn :: enum {
    Player,
    Enemy,
}

Entities :: struct {
    entities: [Turn]Entity,
    turn:      Turn,
}

next_turn :: #force_inline proc(turn: Turn) -> Turn {
    return Turn(int(turn) ~ 1)
}

advance_turn :: #force_inline proc(e: ^Entities) {
    e.turn = next_turn(e.turn)
}

 player :: #force_inline proc(e: ^Entities) -> ^Entity { return &e.entities[.Player] }
  enemy :: #force_inline proc(e: ^Entities) -> ^Entity { return &e.entities[.Enemy]  }
current :: #force_inline proc(e: ^Entities) -> ^Entity { return &e.entities[e.turn]  }
  other :: #force_inline proc(e: ^Entities) -> ^Entity { return &e.entities[next_turn(e.turn)] }
