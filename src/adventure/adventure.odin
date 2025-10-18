package adventure

import "core:encoding/json"
import "core:math/rand"

import "vendor:sdl3"

import "game:wizard"
import "game:graphics"
import "game:graphics/ui"

Adventure :: struct {
    stage:  int,
    stages: []Stage,

}

Environment :: enum {
    Forest,
    Forest_Ruins,
    Deep_Forest,
    Foothills,
    Cave,
    Ice_Cave,
    Lava_Cave,
}

Stage :: struct {
    arena_layout_data: []u8,
    name:              string,
    arena_layout:      wizard.Arena_Layout,
    label:              ui.Label,

    // animation: // Animation,
    enemy_health: int,
    is_boss:      bool,
    environment:  Environment,
    elements:     wizard.Elements,
    next_stage:   int,
    choices:      []int,

    investigation_cost: int,
}

init :: proc(ctx: ^ui.Context, adventure: ^Adventure) {
    for &stage in adventure.stages {
        // Always select a choice even if one had previously been selected.
        // The adventure is initialised every time it is selected.
        if len(stage.choices) != 0 {
            stage.next_stage = rand.choice(stage.choices)
        }

        if stage.arena_layout.blocks == nil {
            json.unmarshal(stage.arena_layout_data, &stage.arena_layout)
        }

        if stage.label.text == nil {
            stage.label = ui.create_label(ctx, stage.name, graphics.rgb(200, 200, 200))
        }
    }
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

is_complete :: proc(adventure: ^Adventure) -> bool {
    return stage(adventure).next_stage == 0
}

// Returns false if there are no more stages in this adventure
advance_to_next_stage :: proc(adventure: ^Adventure) {
    adventure.stage = stage(adventure).next_stage
}

investigation_cost :: proc(adventure: ^Adventure) -> int {
    stage := stage(adventure)
    cost  := 1

    switch stage.environment {
        case .Forest:       cost = 1
        case .Forest_Ruins: cost = 1
        case .Deep_Forest:  cost = 1
        case .Foothills:    cost = 1
        case .Cave:         cost = 1
        case .Ice_Cave:     cost = 1
        case .Lava_Cave:    cost = 1
    }

    return cost
}