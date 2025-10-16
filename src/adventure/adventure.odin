package adventure

import "core:encoding/json"
import "core:math/rand"

import "vendor:sdl3"

import "game:wizard"

Adventure :: struct {
    stage:  int,
    stages: []Stage,
}

Environment :: enum {
    Forest,
    Forest_Ruins,
    Cave,
    Ice_Cave,
    Lava_Cave,
}

Stage :: struct {
    arena_layout_data: []u8,
    arena_layout:      wizard.Arena_Layout,

    // animation: // Animation,
    enemy_health: int,
    environment:  Environment,
    elements:     wizard.Elements,
    next_stage:   []int,
}

get_arena_layout_for_stage :: proc(stage: ^Stage) -> wizard.Arena_Layout {
    if stage.arena_layout.blocks == nil {
        json.unmarshal(stage.arena_layout_data, &stage.arena_layout)
    }

    return stage.arena_layout
}

get_test_arena_layout_for_stage :: proc() -> wizard.Arena_Layout {
    size:     uint
    contents: rawptr = sdl3.LoadFile("src/adventure/layouts/test.json", &size)

    defer sdl3.free(contents)

    data := (transmute([^]u8) contents)[:size]

    layout: wizard.Arena_Layout
    json.unmarshal(data, &layout)

    return layout
}

stage :: #force_inline proc(adventure: ^Adventure) -> ^Stage {
    return &adventure.stages[adventure.stage]
}

// Returns false if there are no more stages in this adventure
advance_to_next_stage :: proc(adventure: ^Adventure) -> bool {
    next_stage   := stage(adventure).next_stage
    can_continue := true

    switch len(next_stage) {
        case 0: can_continue    = false
        case 1: adventure.stage = next_stage[0]
        case:   adventure.stage = rand.choice(next_stage)
    }

    return can_continue
}
