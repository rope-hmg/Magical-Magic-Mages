package adventure

import "game:spell"

Adventure :: struct {
    current_stage:   int,
    max_stage_count: int,

}

Beast :: enum {
    Rat,

    Toad,
}

Stage :: struct {
    arena_layout_data: []u8,
    arena_layout:      spell.Arena_Layout,


    beast: Beast,

}

get_arena_layout_for_stage :: proc(stage: Stage) -> Arena_Layout {
    if info.arena_layout.blocks == nil {
        json.unmarshal(info.arena_layout_data, &info.arena_layout)
    }

    return info.arena_layout
}

get_test_arena_layout_for_stage :: proc() -> Arena_Layout {
    size:     uint
    contents: rawptr = sdl3.LoadFile("src/wizard/layouts/stages/test.json", &size)

    defer sdl3.free(contents)

    data := (transmute([^]u8) contents)[:size]

    layout: Arena_Layout
    json.unmarshal(data, &layout)

    return layout
}
