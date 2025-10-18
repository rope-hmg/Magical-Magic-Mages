package wizard

import "core:math/linalg/glsl"
import "core:encoding/json"

import "vendor:sdl3"

Wizard :: struct {
    rank:     Rank,
    elements: Elements,
    staff:    Staff,
    ring:     Ring,
    grimoire: Grimoire,

    action_points_per_camp: int,
}

Rank :: enum {
    White = 1,
    Blue,
    Purple,
    Brown,
    Black,
    Red,
}

rank_to_string :: proc(rank: Rank) -> string {
    result: string

    switch rank {
        case .White:  result = "White"
        case .Blue:   result = "Blue"
        case .Purple: result = "Purple"
        case .Brown:  result = "Brown"
        case .Black:  result = "Black"
        case .Red:    result = "Red"
    }

    return result
}

Staff :: struct {
    element: Block_Element,
}

Ring :: struct {
    element: Block_Element,
}

Grimoire :: struct {
    exp:  int,
    next: int,
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

get_elements :: proc(wizard: Wizard) -> Elements {
    result: Elements

    for count, element in wizard.elements {
        result[element] = count * int(wizard.rank)
    }

    return result
}