package wizard

import "core:math/linalg/glsl"
import "core:encoding/json"

import "vendor:sdl3"

Wizard :: struct {
    rank:     Rank,
    staff:    Staff,
    ring:     Ring,
    grimoire: Block_Element,
}

Rank :: enum {
    White = 1,
    Blue,
    Purple,
    Brown,
    Black,
    Red,
}

Staff :: struct {
    element: Block_Element,
}

Ring :: struct {
    element: Block_Element,
}

@private _layouts: [Rank]Arena_Layout

LAYOUT_WHITE  :: #load("./layouts/white.json")
LAYOUT_BLUE   :: #load("./layouts/blue.json")
LAYOUT_PURPLE :: #load("./layouts/purple.json")
LAYOUT_BROWN  :: #load("./layouts/brown.json")
LAYOUT_BLACK  :: #load("./layouts/black.json")
LAYOUT_RED    :: #load("./layouts/red.json")

get_arena_layout_for_wizard :: proc(wizard: Wizard, test := false) -> Arena_Layout {
    //
    // Load the layout for the wizard's rank
    //
    layout := &_layouts[wizard.rank]

    if layout.blocks == nil {
        switch wizard.rank {
            case .White:  json.unmarshal(LAYOUT_WHITE,  layout)
            case .Blue:   json.unmarshal(LAYOUT_BLUE,   layout)
            case .Purple: json.unmarshal(LAYOUT_PURPLE, layout)
            case .Brown:  json.unmarshal(LAYOUT_BROWN,  layout)
            case .Black:  json.unmarshal(LAYOUT_BLACK,  layout)
            case .Red:    json.unmarshal(LAYOUT_RED,    layout)
        }
    }

    result := layout^
    // TODO: Adjust the element blocks based on the wizard's grimoire

    return result
}

get_test_arena_layout_for_wizard :: proc() -> Arena_Layout {
    //
    // Load the layout for the wizard's rank
    //
    size:     uint
    contents: rawptr = sdl3.LoadFile("src/wizard/layouts/wizard/test.json", &size)

    defer sdl3.free(contents)

    data := (transmute([^]u8) contents)[:size]

    layout: Arena_Layout
    json.unmarshal(data, &layout)

    return layout
}
