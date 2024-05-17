package client

import "core:math"

import SDL "vendor:sdl2"

GLYPH_TILE_W :: 8
GLYPH_TILE_H :: 16
ENTRY_COUNT  :: 4

ENTRY_STAGE := [ENTRY_COUNT]^Stage {&Stage_Level_1, &Stage_Level_2, &Stage_Level_3, nil}
ENTRY_TEXT  := [ENTRY_COUNT]string {"Play", "Options", "Credits", "Quit"}

Title_Data :: struct {
    title_text: Text_Item,
    options:    [ENTRY_COUNT]Text_Item,
    hovered:    i32,
    animation:  Text_Animation,
}

title_load :: proc(title_data: ^Title_Data, title: cstring, assets: Assets) {
    title_data.title_text = make_text_item(title, 0, 10, 4, assets.fancy)

    for i: i32 = 0; i < ENTRY_COUNT; i += 1 {
        title_data.options[i] = make_text_item(ENTRY_TEXT[i], 0, 100 + i * (GLYPH_TILE_H + 20), 2, assets.fancy)
    }

    title_data.animation = make_wave_animation()
}

title_unload :: proc(using title_data: ^Title_Data) {
    assert(title_data != nil)

    delete_animation(title_data.animation)
    delete_text_item(title_text)

    for i := 0; i < ENTRY_COUNT; i += 1 {
        delete_text_item(title_data.options[i])
    }
}

title_update_and_render :: proc(title_data: ^Title_Data, renderer: ^SDL.Renderer, input: Input) -> ^Stage {
    assert(title_data != nil)
    assert(renderer   != nil)

    SDL.SetRenderDrawColor(renderer, 255, 0, 0, 0)
    render_text_item(renderer, title_data.title_text, title_data.animation)

    selected: i32 = -1

    if just_pressed(input, .Menu_Up) {
        title_data.hovered = math.max(title_data.hovered - 1, 0)
    }

    if just_pressed(input, .Menu_Down) {
        title_data.hovered = math.min(title_data.hovered + 1, ENTRY_COUNT - 1)
    }

    if just_pressed(input, .Key_Select) {
        selected = title_data.hovered
    }

    for i: i32 = 0; i < ENTRY_COUNT; i += 1 {
        entry    := &title_data.options[i]
        position := input.cursor_position

        if SDL.PointInRect(&position, &entry.bounds) {
            title_data.hovered = i

            if just_pressed(input, .Mouse_Select) {
                selected = i
            }
        }
    }

    for i: i32 = 0; i < ENTRY_COUNT; i += 1 {
        entry     := &title_data.options[i]
        animation := IDENTITY

        if title_data.hovered == i {
            SDL.SetRenderDrawColor(renderer, 0, 255, 0, 0)
            animation = title_data.animation
        } else {
            SDL.SetRenderDrawColor(renderer, 255, 0, 0, 0)
        }

        render_text_item(renderer, entry^, animation)
    }

    next_stage: ^Stage

    if selected != -1 {
        next_stage = ENTRY_STAGE[selected]

        if next_stage == nil {
            // Quit somehow...
        }
    }

    return next_stage
}
